//
//  NWSOCKSLayer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/3.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation


class NWSOCKSLayer : NWProtocolLayer {
    private(set) var error: NWError = .none
    
    enum OpenPhase : Int {
        case proxy
        case direct
    }
    
    var openPhase: OpenPhase = .proxy
    
    enum ProxyState : Int {
        case none
        case auth_method
        case auth
        case connect
        case ready
        case failed
    }
    
    func raiseError(_ error: Error) {
        raiseError((error as? NWError) ?? .proxy(.warped(error)))
    }
    
    func raiseError(_ error: NWError) {
        print("SOCKS ERROR:", error)
        self.error = error
        self.state = .failed
    }

    var state: ProxyState = .none {
        didSet {
            if state == oldValue {
                print("REPEAT SOCKS PROXY STATE:", state)
                return
            }
            
            switch state {
            case .failed:
                self.dispatchQueue.async {
                    if !self.reopenOriginal() {
                        self.markFailed(self.error)
                    }
                    self.dismissed(layer: self)
                }
            case .ready:
                openPhase = .direct
                self.dispatchQueue.async {
                    self.markReady()
                    self.handleWrite(0)
                    if self.read(buffer: nil) == 0 {
                        self.handleRead(0)
                    }
                    self.dismissed(layer: self)
                }
            default:
                break
            }
        }
    }
    
    var originalEndpoint: NWEndpoint!
    var dispatchQueue: DispatchQueue!
    var usingParameters: NWParameters!
    
    init() {}
    deinit {
        print("SOCKS LAYER DEINIT")
    }
    
    func proxyOpen() -> Bool {
        if let addr = NWNetworkConfiguration.shared.proxyConfiguration?.socksAddr,
            let port = NWNetworkConfiguration.shared.proxyConfiguration?.socksPort,
            let endpointPort = NWEndpoint.Port(rawValue: port) {
            print("PROXY ENDPOINT:", addr, port)
            return prevLayer?.open(endpoint: .hostPort(NWEndpoint.Host(addr), endpointPort), in: dispatchQueue, using: usingParameters) ?? false
        }
        return false
    }
    
    
    var receiveBuffer: [UInt8]!
    var receivedLength: Int = 0
    var receiveMaxLength: Int = 0
    
    func proxyMarkReady() {
        beginAuthMethod()
    }
    
    func proxyMarkFailed(_ error:NWError) {
        self.error = error
        state = .failed
    }
    
    func proxyHandleRead(_ len: Int) {
        self.serializer?.handleRead(len)
    }

    func proxyHandleWrite(_ len: Int) {
        self.serializer?.handleWrite(len)
    }
    
    func proxyHandleEOF(_ error: Int32) {
        self.serializer?.handleEOF(error)
    }
    
    var serializer: NWSimpleRWSerializer?
    
    func beginAuthMethod() {
        state = .auth_method
        let authMethodCmd = Data([0x05, 0x03, 0x00, 0x01, 0x02])
        _ = serializer?.write(data: authMethodCmd, context: nil, completedBlock: { (_, _, error) in
            if let error = error {
                self.raiseError(error)
                return
            }
            _ = self.serializer?.read(minSize: 2, maxSize: 2, context: nil, completedBlock: self.authMethodCompleted(data:context:error:))
        })
    }
    
    func authMethodCompleted(data: Data?, context: AnyObject?, error: Error?) {
        if let error = error {
            raiseError(error)
            return
        }
        
        if let data = data, data.count == 2 {
            if data[0] != 0x05 {
                raiseError(.proxy(.wrong_version))
                return
            }
            
            if data[1] == 0xff {
                raiseError(.proxy(.auth_method_not_accept))
                return
            }
            
            if data[1] == 0x00 {
                state = .connect
                beginConnect()
            } else {
                state = .auth
                beginAuth()
            }
        } else {
            raiseError(.proxy(.read_error))
        }
    }
    
    func beginConnect() {
        if case let .hostPort(host, port) = self.originalEndpoint {
            let portValue:UInt16 = port.rawValue
            var connectMsg:[UInt8]
            switch host {
            case let .ipv4(v4Addr):
                connectMsg = .init(repeating: 0, count: 10)
                connectMsg.replaceSubrange(0..<4, with: [0x05, 0x01, 0x00, 0x01])
                connectMsg.replaceSubrange(4..<8, with: v4Addr.rawValue)
            case let .ipv6(v6Addr):
                connectMsg = .init(repeating: 0, count: 22)
                connectMsg.replaceSubrange(0..<4, with: [0x05, 0x01, 0x00, 0x04])
                connectMsg.replaceSubrange(4..<20, with: v6Addr.rawValue)
            case let .name(hostName, _):
                if let nameData = hostName.data(using: .utf8) {
                    connectMsg = [UInt8](repeating: 0, count: nameData.count + 7)
                    connectMsg.replaceSubrange(0..<4, with: [0x05, 0x01, 0x00, 0x03])
                    connectMsg[4] = UInt8(nameData.count)
                    connectMsg.replaceSubrange(5..<5+nameData.count, with: nameData)
                } else {
                    print("[ERROR] PROXY HOST NAME CAN'T CONVERT TO UTF8:", hostName)
                    raiseError(.proxy(.unknown(-3)))
                    return
                }
            }
            connectMsg[connectMsg.count-2] = UInt8((portValue>>8)&0xff)
            connectMsg[connectMsg.count-1] = UInt8(portValue & 0xff)
            
            _ = serializer?.write(data: Data(connectMsg), context: nil, completedBlock: { (_, _, error) in
                if let error = error {
                    self.raiseError(error)
                    return
                }
                _ = self.serializer?.read(minSize: 5, maxSize: 5, context: nil, completedBlock: { (data, _, error) in
                     //self.connectCompleted(data:context:error:)
                    if let error = error {
                        self.raiseError(error)
                        return
                    }
                    
                    if let data = data, data.count == 5 {
                        if data[0] != 0x05 {
                            self.raiseError(.proxy(.wrong_version))
                            return
                        }
                        if data[1] != 0x00 {
                            self.error = .proxy(.connect_failed(Int32(data[1])))
                            print("[ERROR] PROXY CONNECT FAILED:", self.error)
                            return
                        }
                        var readSize: Int
                        if data[3] == 0x01 {
                            readSize = 10                         /// 4 + 4 + 2
                        } else if data[3] == 0x03 {
                            readSize = Int(data[4]) + 7    /// 4 + 1 + nameLen + 2
                        } else if data[3] == 0x04 {
                            readSize = 22                          /// 4 + 16 + 2
                        } else {
                            self.error = .proxy(.connect_failed(-1))
                            return
                        }
                        readSize -= 5
                        _ = self.serializer?.read(minSize: readSize, maxSize: readSize, context: nil, completedBlock: self.connectCompleted(data:context:error:))
                    } else {
                        self.raiseError(.proxy(.unknown(-6)))
                    }
                })
            })
        } else {
            self.raiseError(.proxy(.unknown(-7)))
        }

    }
    
    func connectCompleted(data: Data?, context: AnyObject?, error: Error?) {
        if let error = error {
            raiseError(error)
            return
        }
        self.state = .ready
    }
    
    func beginAuth() {
        if let username = NWNetworkConfiguration.shared.proxyConfiguration?.socksUsername,
            let usernameData = username.data(using: .utf8),
            let password = NWNetworkConfiguration.shared.proxyConfiguration?.socksPassword,
            let passwordData = password.data(using: .utf8) {
            var authCmd = Data(repeating: 0, count: (usernameData.count + passwordData.count + 3))
            authCmd[0] = 0x01
            authCmd[1] = UInt8(usernameData.count)
            authCmd.replaceSubrange(2..<usernameData.count+2, with: usernameData)
            authCmd[usernameData.count+2] = UInt8(passwordData.count)
            authCmd.replaceSubrange(usernameData.count+3..<authCmd.count, with: passwordData)
            
            _ = self.serializer?.write(data: authCmd, context: nil, completedBlock: { (_, _, error) in
                if let error = error {
                    self.raiseError(error)
                    return
                }
                
                _ = self.serializer?.read(minSize: 2, maxSize: 2, context: nil, completedBlock: self.authCompleted(data:context:error:))
            })
        } else {
            raiseError(.proxy(.unknown(-7)))
        }
    }
        
    func authCompleted(data: Data?, context: AnyObject?, error: Error?) {
        if let error = error {
            raiseError(error)
            return
        }
        
        if let data = data, data.count == 2 {
            if data[0] != 0x01 {
                raiseError(.proxy(.wrong_version))
                return
            }
            
            if data[1] != 0x00 {
                raiseError(.proxy(.auth_failed))
                return
            }
            beginConnect()
        } else {
            raiseError(.proxy(.unknown(-8)))
        }
    }
        

    
    
    func reopenOriginal() -> Bool {
        prevLayer?.close()
        self.openPhase = .direct
        if (prevLayer?.open(endpoint: originalEndpoint, in: dispatchQueue, using: usingParameters) ?? false) {
            return true
        } else {
            self.error = prevLayer?.error ?? .posix(ENOENT)
            return false
        }
    }
    

    let name: String = "SOCKS"

    weak var prevLayer: NWProtocolLayer?
    
    weak var nextLayer: NWProtocolLayer?
    
    
    func open(endpoint: NWEndpoint, in queue:DispatchQueue, using: NWParameters) -> Bool {
        self.originalEndpoint = endpoint
        self.dispatchQueue = queue
        self.usingParameters = using
        self.serializer = NWSimpleRWSerializer(layer: self, queue: queue)
        
        if proxyOpen() {
            openPhase = .proxy
            return true
        } else {
            openPhase = .direct
            return prevLayer?.open(endpoint: endpoint, in: queue, using: using) ?? false
        }
    }
    
    func close() {
        prevLayer?.close()
    }
    
    func read(buffer: UnsafeMutableRawBufferPointer?) -> Int {
        let ret = prevLayer?.read(buffer: buffer) ?? -1
        if ret < 0 {
            self.error = prevLayer?.error ?? .none
        }
        return ret
    }
    
    func write(data: UnsafeRawBufferPointer?) -> Int {
        let ret = prevLayer?.write(data: data) ?? -1
        if ret < 0 {
            self.error = prevLayer?.error ?? .none
        }
        return ret
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
        if openPhase != .direct {
            proxyMarkReady()
            return
        }
        nextLayer?.markReady()
    }
    
    func markFailed(_ error: NWError) {
        if openPhase != .direct {
            proxyMarkFailed(error)
            return
        }
        nextLayer?.markFailed(error)
    }
    
    func handleWrite(_ len: Int) {
        if openPhase != .direct {
            proxyHandleWrite(len)
            return
        }
        nextLayer?.handleWrite(len)
    }
    
    func handleRead(_ len: Int) {
        if openPhase != .direct {
            proxyHandleRead(len)
            return
        }
        nextLayer?.handleRead(len)
    }
    
    func handleEOF(_ error: Int32) {
        if openPhase != .direct {
            proxyHandleEOF(error)
            return
        }
        nextLayer?.handleEOF(error)
    }
}
