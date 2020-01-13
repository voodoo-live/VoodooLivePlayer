//
//  LiveRTMPLoader.swift
//  live_player
//
//  Created by voodoo on 2019/12/9.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VoodooNetwork




class LiveRTMPLoader : LiveLoaderProtocol, RTMPNetConnectionDelegate, RTMPUnderlyingConnection {
    var delegate: LiveLoaderDelegate?
    var delegateQueue: DispatchQueue?
    
    

    /// RTMPUnderlyingConnection
    func readData(minSize: Int, maxSize: Int, context: AnyObject?, completedBlock: @escaping (Data?, AnyObject?, Error?) -> Void) {
        //self.connection.queuedSerializer.read(minimumLength: minSize, maximumLength: maxSize, context: context, completedBlock: completedBlock)
        
        self.connection.receive(minimumIncompleteLength: minSize, maximumLength: maxSize) { (data, contentContext, isCompleted, error) in
            completedBlock(data, context, error)
        }
        
        
    }
    
    func writeData(_ data: Data, context: AnyObject?, completedBlock: @escaping (AnyObject?, Error?) -> Void) {
        //self.connection.queuedSerializer.write(data: data, context: context, completedBlock: completedBlock)
        self.connection.send(content: data, completion: .contentProcessed({ (error) in
            completedBlock(context, error)
        }))
    }
    
    func writeData(_ data: Data) {
        self.connection.send(content: data, completion: .idempotent)
    }
    
    /// RTMPNetConnectionDelegate
    func handleMessage(_ message: RTMPMessage) {
        //print("RTMP MESSAGE: \(message.type)")
        
        
        if message.type == 0x08 {
            if gotfirstAudioPacket {
                //dataType = da
                delegate?.handle(loaderData: message.data, withType: .audioPacket)
            } else {
                gotfirstAudioPacket = true
                delegate?.handle(loaderData: message.data, withType: .audioParameters)
            }
        } else if message.type == 0x09 {
            if gotFirstVideoPacket {
                delegate?.handle(loaderData: message.data, withType: .videoPacket)
            } else {
                gotFirstVideoPacket = true
                delegate?.handle(loaderData: message.data, withType: .videoParameters)
            }
        } else {
            return
        }
    }
    
    func handleError(_ error: RTMPError) {
        self.connection.cancel()
    }
    
    func handleStateChanged(newState: RTMPNetConnection.State) {
        print("RTMP NET CONNECT NEW STATE: \(newState)")
        if newState == .ready {
            print("BEGIN PLAY")
            rtmpNetConnection.play()
        }
    }
    
    /// loader state
    var gotFirstVideoPacket = false
    var gotfirstAudioPacket = false
    
    let address: RTMPAddress
    let rtmpNetConnection: RTMPNetConnection

    var connection: NWConnection!
    let connectionQueue = DispatchQueue(label: "Voodoo.RTMPLoader.connectionQueue")
    
    init(address: RTMPAddress) {
        self.address = address
        self.rtmpNetConnection = RTMPNetConnection(address: self.address)
        self.rtmpNetConnection.delegate = self
    }
    
    func start() -> Bool {
        if let connection = NWConnection(host: NWEndpoint.Host(self.address.hostName), port: NWEndpoint.Port(rawValue: self.address.port)!, using: self.address.scheme == .rtmps ? .tls : .tcp) {
            self.connection = connection
            self.connection.stateUpdateHandler = connectionStateChanged(newState:)
            self.connection.start(queue: connectionQueue)
            
            return true
        } else {
            return false
        }
    }
    
    func stop() {
        if connection != nil {
            connection.cancel()
        }
    }
    
    func connectionStateChanged(newState: NWAsyncObjectState) {
        switch newState {
        case .ready:
            print("CONNECTION READY")
            let _ = rtmpNetConnection.open(underlyingConnection: self, withHandShake: true)
        case .cancelled:
            rtmpNetConnection.close()
            self.connection = nil
            print("CONNECTION CANCELLED")
        default:
            break
        }
    }
    
    var isRunning: Bool {
        get {
            return self.connection != nil && self.connection.state != .cancelled
        }
    }

}
