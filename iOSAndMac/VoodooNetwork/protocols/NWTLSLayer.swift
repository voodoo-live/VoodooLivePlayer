//
//  NWTLSLayer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/3.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

func _TLSWriteFunc(conn:SSLConnectionRef, data:UnsafeRawPointer, dataLen:UnsafeMutablePointer<Int>) -> OSStatus {
    let tlsLayer = Unmanaged<NWTLSLayer>.fromOpaque(conn).takeUnretainedValue()
    return tlsLayer.TLSWrite(conn: conn, data: data, dataLen: dataLen)
}

func _TLSReadFunc(conn:SSLConnectionRef, buffer:UnsafeMutableRawPointer, bufferLen:UnsafeMutablePointer<Int>) -> OSStatus {
    let tlsLayer = Unmanaged<NWTLSLayer>.fromOpaque(conn).takeUnretainedValue()
    return tlsLayer.TLSRead(conn: conn, buffer: buffer, bufferLen: bufferLen)
}

class NWTLSLayer : NWProtocolLayer {
    enum State : Int {
        case none
        case handshake
        case ready
        case failed
    }
    
    var state: State = .none
    
    var hostName:String?
    
    var context: SSLContext!
    
    init?() {
        context = SSLCreateContext(kCFAllocatorDefault, .clientSide, .streamType)
        
        if SSLSetIOFuncs(self.context, _TLSReadFunc(conn:buffer:bufferLen:), _TLSWriteFunc(conn:data:dataLen:)) != noErr {
            print("[ERROR] SSLSetIOFuncs failed")
            return nil
        }
        
        let selfPointer = Unmanaged<NWTLSLayer>.passUnretained(self).toOpaque()
        let osstatus = SSLSetConnection(self.context!, selfPointer)
        if osstatus != noErr {
            print("[ERROR] SSLSetConnection failed:", osstatus)
            self.error = .tls(osstatus)
            return nil
        }
        
    }
    
    deinit {
        print("TLS LAYER DEINIT")
    }
    
    func internalHandShake() {
        let osstatus = SSLHandshake(self.context)
        if osstatus == errSSLWouldBlock {
            return
        } else if osstatus == noErr {
            state = .ready
            print("TLS READY")
            markReady()
            if writeLen > 0 {
                handleWrite(writeLen)
            }
            handleRead(0)
            return
        }
        
        state = .failed
        self.error = .tls(osstatus)
        nextLayer?.markFailed(self.error)
    }
    
    func internalMarkReady() {
        state = .handshake
        internalHandShake()
    }
    
    func internalMarkFailed(_ error: NWError) {
        self.error = error
        state = .failed
        nextLayer?.markFailed(error)
    }

    var writeLen: Int = 0
    
    func internalHandleWrite(_ len: Int) {
        self.writeLen = len
    }
    
    func internalHandleRead(_ len: Int) {
        internalHandShake()
    }
    
    func internalHandleEOF(_ error: Int32) {
        state = .failed
        self.error = .posix(error)
        nextLayer?.handleEOF(error)
    }
    
    /// NWProtocolLayer
    let name: String = "tls"
    
    weak var prevLayer: NWProtocolLayer?
    
    weak var nextLayer: NWProtocolLayer?
    
    var error: NWError = .none
    
    func open(endpoint: NWEndpoint, in queue: DispatchQueue, using: NWParameters) -> Bool {
        self.hostName = endpoint.hostName
        if self.hostName != nil {
            if let hostNamePtr = self.hostName!.cString(using: .utf8) {
                let osstatus = SSLSetPeerDomainName(self.context, hostNamePtr, hostNamePtr.count)
                if osstatus != noErr {
                    print("[ERROR] SSLSetPeerDomainName failed:", osstatus)
                    self.error = .tls(osstatus)
                }
            }
        }
        return prevLayer?.open(endpoint: endpoint, in: queue, using: using) ?? false
    }
    
    func close() {
        SSLClose(self.context)
        prevLayer?.close()
    }
    
    func read(buffer: UnsafeMutableRawBufferPointer?) -> Int {
        var processed: Int = 0
        let osstatus = SSLRead(self.context!, buffer!.baseAddress!, buffer!.count, &processed)
        if osstatus != noErr {
            print("[ERROR] SSLRead return failed:", osstatus)
            if osstatus == errSSLWouldBlock {
                self.error = .wouldBlock
            } else {
                self.error = .tls(osstatus)
            }
            return -1
        }
        return processed
    }
    
    func write(data: UnsafeRawBufferPointer?) -> Int {
        var processed:Int = 0
        let osstatus = SSLWrite(self.context!, data!.baseAddress!, data!.count, &processed)
        if osstatus != noErr {
            print("[ERROR] SSLWrite return failed:", osstatus)
            if osstatus == errSSLWouldBlock {
                self.error = .wouldBlock
            } else {
                self.error = .tls(osstatus)
            }
            return -1
        }
        return processed
    }
    
    func pong(state: NWAsyncObjectState) {
        prevLayer?.pong(state: state)
    }
    
    func dismissed(layer: NWProtocolLayer) {
        nextLayer?.dismissed(layer: layer)
    }
    
    func ping() {
        nextLayer?.ping()
    }
    
    func markReady() {
        if state != .ready {
            internalMarkReady()
            return
        }
        nextLayer?.markReady()
    }
    
    func markFailed(_ error: NWError) {
        if state != .ready {
            return
        }
        nextLayer?.markFailed(error)
    }
    
    func handleWrite(_ len: Int) {
        if state != .ready {
            internalHandleWrite(len)
            return
        }
        nextLayer?.handleWrite(len)
    }
    
    func handleRead(_ len: Int) {
        if state != .ready {
            internalHandleRead(len)
            return
        }
        nextLayer?.handleRead(len)
    }
    
    func handleEOF(_ error: Int32) {
        if state != .ready {
            internalHandleEOF(error)
            return
        }
        nextLayer?.handleEOF(error)
    }
 
    
    func TLSWrite(conn:SSLConnectionRef, data:UnsafeRawPointer, dataLen:UnsafeMutablePointer<Int>) -> OSStatus {
        let dataSize = dataLen.pointee
        let dataPtr = UnsafeRawBufferPointer(start: data, count: dataSize)
        let sendRet = prevLayer?.write(data: dataPtr) ?? -1
        if sendRet < 0 {
            print("TLSWrite - ", errno)
            dataLen.initialize(to: 0)
            if errno == EAGAIN || errno == EINTR || errno == ENOBUFS {
                return errSSLWouldBlock
            }
            if errno == ECONNRESET {
                return errSSLTransportReset
            }
            
            return errSSLClosedAbort
        } else {
            dataLen.initialize(to: sendRet)
            if sendRet < dataSize {
                print("TLSWrite - errSSLWouldBlock: (\(sendRet)/\(dataSize))")
                return errSSLWouldBlock
            }
            
            print("TLSWrite - \(sendRet)")
        }
        
        return noErr
    }
    
    func TLSRead(conn:SSLConnectionRef, buffer:UnsafeMutableRawPointer, bufferLen:UnsafeMutablePointer<Int>) -> OSStatus {
        let bufferSize = bufferLen.pointee
        let readBuffer = UnsafeMutableRawBufferPointer(start: buffer, count: bufferSize)
        let recvRet = prevLayer?.read(buffer: readBuffer) ?? -1
        if recvRet < 0 {
            print("TLSRead - ", errno)
            bufferLen.initialize(to: 0)
            switch errno {
            case ETIMEDOUT:
                print("TLSRead - errSSLNetworkTimeout")
                return OSStatus(errSSLNetworkTimeout)
            case ENOENT:
                print("TLSRead - errSSLClosedGraceful(ENOENT)")
                return OSStatus(errSSLClosedGraceful)
            case EAGAIN, EINTR:
                print("TLSRead - errSSLWouldBlock: (0)")
                return OSStatus(errSSLWouldBlock)
            case ECONNRESET:
                print("TLSRead - errSSLTransportReset")
                return OSStatus(errSSLTransportReset)
            default:
                print("TLSRead - errSSLClosedAbort")
                return OSStatus(errSSLClosedAbort)
            }
            /**
             errSSLNetworkTimeout
             */
        } else if recvRet == 0 {
            bufferLen.initialize(to: 0)
            print("TLSRead - errSSLClosedGraceful")
            return errSSLClosedGraceful
        } else {
            bufferLen.initialize(to: recvRet)
            if recvRet < bufferSize {
                print("TLSRead - errSSLWouldBlock: (\(recvRet)/\(bufferSize))")
                return errSSLWouldBlock
            }
            print("TLSRead - \(recvRet)")

        }
        return noErr
    }
    
}

