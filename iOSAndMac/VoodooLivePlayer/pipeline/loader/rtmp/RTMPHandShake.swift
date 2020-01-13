//
//  RTMPHandShake.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/9.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class RTMPHandShake {
    func nowTimeStamp() -> UInt32 {
        return UInt32(Date.timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate)
    }
    
    var completedBlock: ((Error?) -> Void)?
    let underlyingConnection: RTMPUnderlyingConnection
    init(underlyingConnection: RTMPUnderlyingConnection, completedBlock: @escaping (Error?) -> Void) {
        self.underlyingConnection = underlyingConnection
        self.completedBlock = completedBlock
    }
    
    enum State {
        case start
        case version_sent
        case ack_sent
        case done
    }
    
    private(set) var state: State = .start
    
    
    
    func clientVersionWriteCompleted(context: AnyObject?, error: Error?) {
        if state == .done { return }
        if let error = error {
            self.completedBlock?(error)
            return
        }
        self.state = .version_sent
        let serverVersionSize = 1536+1
        self.underlyingConnection.readData(minSize: serverVersionSize, maxSize: serverVersionSize, context: nil, completedBlock: serverVersionReadCompleted(data:context:error:))
    }
    
    func clientAckWriteCompleted(context: AnyObject?, error: Error?) {
        if state == .done { return }
        if let error = error {
            self.completedBlock?(error)
            return
        }
        self.state = .ack_sent
        let serverAckSize = 1536
        self.underlyingConnection.readData(minSize: serverAckSize, maxSize: serverAckSize, context: nil, completedBlock: serverAckReadCompleted(data:context:error:))
    }
    
    func serverVersionReadCompleted(data: Data?, context: AnyObject?, error: Error?) {
        if state == .done { return }
        if let error = error {
            self.completedBlock?(error)
            return
        }
        var clientAckData = data!.subdata(in: 1..<1537)
        var timestamp = nowTimeStamp().byteSwapped
        clientAckData.replaceSubrange(4..<8, with: &timestamp, count: 4)
        self.underlyingConnection.writeData(clientAckData, context: nil, completedBlock: clientAckWriteCompleted(context:error:))
    }
    
    func serverAckReadCompleted(data:Data?, context: AnyObject?, error: Error?) {
        if state == .done { return }
        if let error = error {
            self.completedBlock?(error)
            return
        }
        self.completedBlock?(nil)
    }
    
    func start() {
        state = .start
        let clientVersionDataStream = RTMPStream(capacity: 1537)
        clientVersionDataStream.writeUInt8(3)
        clientVersionDataStream.writeUInt32(nowTimeStamp())
        clientVersionDataStream.writeUInt32(0)
        clientVersionDataStream.randomFill(size: 1528)
        self.underlyingConnection.writeData(clientVersionDataStream.data, context: nil, completedBlock: clientVersionWriteCompleted(context:error:))
    }
    
    func stop() {
        if state != .done {
            state = .done
            self.completedBlock = nil
        }
    }
}

