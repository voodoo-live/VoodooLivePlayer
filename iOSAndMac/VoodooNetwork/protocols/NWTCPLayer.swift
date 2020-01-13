//
//  NWTCPLayer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/3.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class NWTCPLayer : NWPollable, NWProtocolLayer {
    
    var innerSocket: NWSocket!
    var sockAddr: NWSockAddr!

    var hostState:NWAsyncObjectState = .setup
    var queue:DispatchQueue!
    var endpoint: NWEndpoint!
    var parameters:NWParameters!
    var sockAddrs:[NWSockAddr]!
    var sockAddrIndex:Int = 0
    
    var poller: NWPoller!
    
    
    enum TCPLayerState : Int {
        case none
        case connecting
        case connected
        case peer_closed
        case local_closed
        case failed
    }
    
    var state: TCPLayerState = .none
    
    init() {
        self.poller = NWPoller.shared
    }
    
    deinit {
        print("NWTCPLayer deinit")
        self.poller = nil
    }
    
    func internalResolve(endpoint:NWEndpoint) -> [NWSockAddr]? {
        let result = NWResolver.resolveEndpoint(endpoint)
        switch result {
        case .failed(let error):
            self.error = error
            return nil
        case .success(let ep):
            return ep
        }
    }
    
    func internalConnect(sockAddr:NWSockAddr) -> Bool {
        if innerSocket == nil ||
            innerSocket!.family != sockAddr.family {
            innerSocket = NWSocket(family: sockAddr.family, type: SOCK_STREAM, proto: IPPROTO_TCP)
            if innerSocket == nil {
                self.error = .posix(errno)
                return false
            }
            if !innerSocket.setBlock(false) {
                self.error = innerSocket.error
                innerSocket = nil
                return false
            }
        }
        if let sockaddr_ptr = sockAddr.asV4Ptr() {
            let addrString = String(format:"%08X", UInt32(sockaddr_ptr.pointee.sin_addr.s_addr))
            let port = sockaddr_ptr.pointee.sin_port.byteSwapped
            print("CONNECT ADDR: \(addrString) PORT: \(port)")
        }
        
        let connectRet = self.parameters.allowFastOpen ? innerSocket!.connectx(addr: sockAddr.asPtr()) : innerSocket!.connect(addr: sockAddr.asPtr())
        if connectRet < 0 && innerSocket!.error != NWError.inProgress {
            self.error = innerSocket!.error
            return false
        }
        return true
    }
    
    func nextSockAddr() -> NWSockAddr? {
        if self.sockAddrs == nil { return nil }
        self.sockAddrIndex += 1
        if self.sockAddrIndex >= self.sockAddrs.count {
            return nil
        }
        return self.sockAddrs![self.sockAddrIndex]
    }
    
    func internalOpen(endpoint:NWEndpoint) -> Bool {
        if let sockAddrs = internalResolve(endpoint: endpoint) {
            self.sockAddrs = sockAddrs
            self.sockAddrIndex = -1
            var connectSuccess = false
            while let sockAddr = nextSockAddr() {
                if !internalConnect(sockAddr: sockAddr) {
                    continue
                }
                connectSuccess = true
                //isConnecting = true
                self.state = .connecting
                self.poller.registerEvents(self)
                break
            }
            return connectSuccess
        } else {
            return false
        }
    }

    var ident: UInt { get { innerSocket == nil ? 0 : UInt(innerSocket.fd) } }
    
    func handleWrite(_ len: Int) {
        self.queue.async {
            if self.state == .connecting {
                let sockAddr = NWSockAddr()
                if self.innerSocket.getpeername(addr: sockAddr.asMutablePtr()) < 0 {
                    self.state = .failed
                    self.markFailed(self.innerSocket.error)
                    return
                } else {
                    self.state = .connected
                    self.markReady()
                }
            }
            self.nextLayer?.handleWrite(len)
        }
    }
    
    func handleRead(_ len: Int) {
        self.queue.async {
            self.nextLayer?.handleRead(len)
        }
    }
    
    func handleEOF(_ error: Int32) {
        self.poller.unregisterEvents(self)
        self.queue.async {
            print("TCP LAYER HANDLE EOF")
            self.state = .peer_closed
            self.nextLayer?.handleEOF(error)
        }
    }
    let name: String = "tcp"
    private(set) var error: NWError = .none
    weak var prevLayer: NWProtocolLayer?
    weak var nextLayer: NWProtocolLayer?
    
    func open(endpoint: NWEndpoint, in queue:DispatchQueue, using: NWParameters) -> Bool {
        self.queue = queue
        self.endpoint = endpoint
        self.parameters = using
        ping()
        return internalOpen(endpoint: endpoint)
    }
    
    func close() {
        if self.state == .connected {
            if innerSocket.shutdown(how: SHUT_RDWR) < 0 {
                print("[ERROR] shutdown failed:", innerSocket.error)
                self.error = innerSocket.error
            }
            self.state = .local_closed
        }
        innerSocket = nil
    }
    
    func read(buffer: UnsafeMutableRawBufferPointer?) -> Int {
        let ret = innerSocket.recv(buffer: buffer)
        if ret < 0 {
            self.error = innerSocket.error
        }
        return ret
    }
    
    func write(data: UnsafeRawBufferPointer?) -> Int {
        let ret = innerSocket.send(data: data)
        if ret < 0 {
            self.error = innerSocket.error
        }
        return ret
    }
    
    func pong(state: NWAsyncObjectState) {
        //prevLayer?.pong()
        self.hostState = state
        print("PONG ARRIVED:", state)
    }
    
    func dismissed(layer: NWProtocolLayer) {
        nextLayer?.dismissed(layer: layer)
    }
    
    func ping() {
        nextLayer?.ping()
    }
    
    func markReady() {
        nextLayer?.markReady()
    }
    
    func markFailed(_ error: NWError) {
        self.state = .failed
        nextLayer?.markFailed(error)
    }
    

}
