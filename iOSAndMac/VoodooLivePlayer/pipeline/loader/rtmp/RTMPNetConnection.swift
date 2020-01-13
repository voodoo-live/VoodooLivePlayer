//
//  RTMPNetStream.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/8.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

protocol RTMPNetConnectionDelegate : class {
    func handleMessage(_ message: RTMPMessage)
    func handleError(_ error: RTMPError)
    func handleStateChanged(newState: RTMPNetConnection.State)
}

protocol RTMPUnderlyingConnection : class {
    func readData(minSize: Int, maxSize: Int, context: AnyObject?, completedBlock: @escaping (Data?, AnyObject?, Error?) -> Void)
    func writeData(_ data: Data, context: AnyObject?, completedBlock: @escaping (AnyObject?, Error?) -> Void)
    func writeData(_ data: Data)
}


class RTMPNetConnection {
    let address: RTMPAddress
    init(address: RTMPAddress) {
        self.address = address
    }

    enum State : Int {
        case start
        case handshake
        case connecting
        case ready
        case closed
    }
    
    var error : RTMPError = .none
    var state : State = .start {
        didSet {
            delegate?.handleStateChanged(newState: state)
        }
    }

    var delegate: RTMPNetConnectionDelegate?
    var underlyingConnection: RTMPUnderlyingConnection!
    
    var handShake: RTMPHandShake!

    func handShakeResult(_ error: Error?) {
        if state != .handshake { return }
        handShake = nil
        if let error = error {
            raiseError(error as? RTMPError ?? .warpedError(error))
        } else {
            readCompleted(nil, nil, nil)
            connect()
        }
    }
    
    func open(underlyingConnection: RTMPUnderlyingConnection, withHandShake: Bool = false) -> Bool {
        guard state == .start else {
            print("[RTMP] ERROR: WRONG OPEN STATE: \(state)")
            return false
        }
        
        self.underlyingConnection = underlyingConnection
        
        if withHandShake {
            self.state = .handshake
            self.handShake = RTMPHandShake(underlyingConnection: underlyingConnection, completedBlock: handShakeResult(_:))
            self.handShake.start()
        } else {
            readCompleted(nil, nil, nil)
            self.connect()
        }
        
        return true
    }
    
    func close() {
        if state == .handshake {
            self.handShake.stop()
            self.handShake = nil
        }
        state = .closed
    }
    
    func raiseError(_ error: RTMPError) {
        self.error = error
        self.state = .closed
        self.delegate?.handleError(error)
    }
    /**
     need call from override class
     */
    func sendMessage(message:RTMPMessage, inChunkStream: UInt32 = 3) {
        let outputStream = RTMPStream(capacity: chunkSize+18)
        packMessage(message, inChunkStream: 3, to: outputStream)
        underlyingConnection.writeData(outputStream.data)
    }
    
    func sendMessages(messages:[RTMPMessage]) {
        let outputStream = RTMPStream(capacity: (chunkSize+18) * messages.count)
        for message in messages {
            packMessage(message, inChunkStream: 3, to: outputStream)
        }
        underlyingConnection.writeData(outputStream.data)
    }
    
    lazy var chunkParser: RTMPChunkParser = {
        return RTMPChunkParser(connection: self)
    }()
    
    func handleData(_ data: Data) {
        if let messages = chunkParser.parse(rawData: data) {
            for message in messages {
                delegate?.handleMessage(message)
            }
        }
        
        if chunkParser.state == .failed {
            state = .closed
        }
    }
    
    func readCompleted(_ data: Data?, _: AnyObject?, _ error: Error?) {
        if let error = error {
            raiseError(error as? RTMPError ?? .warpedError(error))
            return
        }
        
        if let data = data {
            handleData(data)
            
            if state == .closed {
                return
            }
        }
        
        underlyingConnection.readData(minSize: 1, maxSize: 4096, context: nil, completedBlock: readCompleted(_:_:_:))
    }
    

    
    var chunkStreams:[RTMPChunkStream] = []
    func getChunkStream(chunkStreamID:UInt32) -> RTMPChunkStream {
        for chunkStream in chunkStreams {
            if chunkStream.ID == chunkStreamID {
                return chunkStream
            }
        }
        let stream = RTMPChunkStream(netConnection: self, ID: chunkStreamID)
        chunkStreams.insert(stream, at: 0)
        return stream
    }
    
    var chunkSize = 128
    var windowSize = 5000000
    enum LimitType : Int {
        case hard
        case soft
        case dynamic
    }
    
    private(set) var limitType: LimitType = .dynamic
    
    enum UserControlEvent : UInt16 {
        case StreamBegin = 0
        case StreamEOF = 1
        case StreamDry = 2
        case SetBufferLength = 3
        case StreamIsRecorded = 4
        case PingRequest = 6
        case PingResponse = 7
    }
    
    func filterMessage(message: RTMPMessage) -> Bool {
        switch message.type {
        case 1:
            /**
             set chunk size
             */
            let newChunkSize = message.data.withUnsafeBytes { (ptr) -> Int in
                return Int(ptr.load(as: UInt32.self).byteSwapped)
            }
            
            if newChunkSize != chunkSize {
                print("SET CHUNK SIZE FROM \(chunkSize) TO \(newChunkSize)")
                chunkSize = newChunkSize
            }
        case 4: /// User Control Message
            /**
             EventType: UInt16
             Params: ...
             */
            let messageStream = RTMPStream(data: message.data)
            if let eventTypeRawValue = messageStream.readUInt16(),
                let eventType = UserControlEvent(rawValue: eventTypeRawValue) {
                switch eventType {
                case .StreamBegin where messageStream.bytesAvalible >= 4:
                    if let streamID = messageStream.readUInt32() {
                        /**
                         
                         */
                        print("STREAM \(streamID) BEGINS")
                    }
                case .PingRequest where messageStream.bytesAvalible >= 4:
                    if let pingParam = messageStream.readUInt32() {
                        print("PING \(pingParam)")
                        var responeData = message.data
                        var pingResponseID = UserControlEvent.PingResponse.rawValue
                        responeData.replaceSubrange(0..<2, with: &pingResponseID, count: 2)
                        let pingResponseMsg = RTMPMessage(streamID: message.streamID, type: message.type, timestamp: 0, data: responeData, chunkID: message.chunkID)
                        sendMessage(message: pingResponseMsg)
                    }
                default:
                    break
                }
            }
            
            
        case 5:
            let newWindowSize = message.data.withUnsafeBytes { (ptr) -> Int in
                return Int(ptr.load(as: UInt32.self).byteSwapped)
            }
            if newWindowSize != self.windowSize {
                print("SET WINDOW SIZE FROM \(windowSize) TO \(newWindowSize)")
                self.windowSize = newWindowSize
            }
        case 6:
            /**
             set peer Bandwidth
             */
            let newWindowSize = message.data.withUnsafeBytes { (ptr) -> Int in
                return Int(ptr.load(as: UInt32.self).byteSwapped)
            }
            
            if newWindowSize != self.windowSize {
                print("SET WINDOW SIZE FROM \(windowSize) TO \(newWindowSize)")
                self.windowSize = newWindowSize
            }
            
            if let newLimitType = LimitType(rawValue: Int(message.data[4])), newLimitType != self.limitType {
                print("SET LIMIT TYPE FROM \(limitType) TO \(newLimitType)")
                self.limitType = newLimitType
            }
        case 20:
            let stream = RTMPStream(data: message.data)
            if let commandValue = AMF.unpackValue(from: stream),
                commandValue.type == .string {
                let command = (commandValue as! AMF.StringValue).value
                var params:[AMF.Value] = []
                if command == "_result" || command == "_error" {
                    let transitionID = AMF.unpackValue(from: stream)
                    if let transitionID = transitionID {
                        if transitionID.type == .number {
                            let params = AMF.RootValue(from: stream)
                            let command = (commandValue as! AMF.StringValue).value
                            let transitionID = Int((transitionID as! AMF.NumberValue).value)
                            return handleTransitionCommand(command, transitionID: transitionID, params: params?.values)
                        }
                        params = [transitionID]
                    }
                }
                params += AMF.RootValue(from: stream)?.values ?? []
                return handleCommand(command, params: params.count == 0 ? nil : params)
            }
            return false
        default:
            return false
        }
        return true
    }

    /**
     command format:
        client -> server: [command: String] [transitionID: Number] [version: Object]
        server -> client: [result: String(_result)] [transitionID: Number] [version: Object] [data: Value]
     */
    
    struct CommandTransition {
        var command: String
        var id: Int
        var completedBlock: ((Bool,[AMF.Value]?) -> Void)?
    }
    
    var commandTransitions:[CommandTransition] = []
    var commandTransitionIDCounter = 0
    
    func sendCommand(_ command: String, params:[Any?]?, chunkID: UInt32 = 0, streamID: UInt32 = 0, completedBlock:@escaping (Bool,[AMF.Value]?) -> Void) {
        commandTransitionIDCounter += 1
        commandTransitions.append(RTMPNetConnection.CommandTransition(command: command, id: commandTransitionIDCounter, completedBlock: completedBlock))
        let commandData = [command, commandTransitionIDCounter] + (params ?? [])
        let msg = RTMPMessage(streamID: streamID, type: 0x14, timestamp: 0, data: AMF.RootValue(commandData).packData()!)
        sendMessage(message: msg, inChunkStream: chunkID)
    }
    
    func sendCommand(_ command: String, params:[Any?]?, chunkID: UInt32 = 0, streamID: UInt32 = 0) {
        commandTransitionIDCounter += 1
        commandTransitions.append(RTMPNetConnection.CommandTransition(command: command, id: commandTransitionIDCounter, completedBlock: nil))
        let commandData = [command, commandTransitionIDCounter] + (params ?? [])
        let msg = RTMPMessage(streamID: streamID, type: 0x14, timestamp: 0, data: AMF.RootValue(commandData).packData()!)
        sendMessage(message: msg, inChunkStream: chunkID)
    }
    
    func handleCommand(_ command: String, params: [AMF.Value]?) -> Bool {
        print(">>>> unhandled command: \(command)")
        return true
    }
    
    func handleTransitionCommand(_ command: String, transitionID: Int, params:[AMF.Value]?) -> Bool {
        var commandTransition: CommandTransition? = nil
        for i in 0..<commandTransitions.count {
            if commandTransitions[i].id == transitionID {
                commandTransition = commandTransitions[i]
                commandTransitions.remove(at: i)
                break
            }
        }
        if let commandTransition = commandTransition {
            if let completedBlock = commandTransition.completedBlock {
                completedBlock(command == "_result", params)
            }
            return true
        }
        
        return false
    }
    
    func connect() {
        state = .connecting
        
        sendCommand("connect", params:[[
            "app": self.address.appName,
            "flashVer": "LNX 9,0,124,2",
            "tcUrl": self.address.tcURL,
            "fpad": false,
            "capabilities": 15,
            "audioCodecs": 4071,
            "videoCodecs": 252,
            "videoFunction": 1
        ]]) { (result, params) in
            if result {
                self.state = .ready
            } else {
                self.state = .closed
            }
        }
    }
    static let MediaChunkID: UInt32 = 8
    var playStreamID: UInt32 = 0
    
    func play() {
        /**
         play
         */
        sendCommand("createStream", params: [nil]) { (result, params) in
            if result, let params=params, params.count > 1, params[1].type == .number {
                print("CREATE STREAM RESULT \(params[1])")
                self.playStreamID = UInt32((params[1] as? AMF.NumberValue)!.intValue)
                //let streamID = (params[1] as? AMF.NumberValue)!.intValue
                self.sendCommand("getStreamLength", params: [nil, self.address.streamName], chunkID: Self.MediaChunkID)
                self.sendCommand("play", params: [nil, self.address.streamName, -2000]) { (result, params) in
                    
                }
            } else {
                print("CREATE STREAM FAILED")
                self.state = .closed
            }
        }
    }
    
    func packMessage(_ message: RTMPMessage, inChunkStream: UInt32, to: RTMPStream) {
        let chunkStream = getChunkStream(chunkStreamID: inChunkStream)
        return chunkStream.packMessage(message, to: to)
    }
}
