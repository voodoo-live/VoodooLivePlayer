//
//  RTMPChunkStream.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/8.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class RTMPChunkStream {
    unowned let netConnection: RTMPNetConnection
    let ID: UInt32
    let basicHeaderTemplate: [UInt8]
    init(netConnection: RTMPNetConnection, ID: UInt32) {
        self.netConnection = netConnection
        var ID = ID
        if ID > 64 + 65535 {
            ID = 2
        }
        
        if ID > 64 + 255 {
            let leftID = ID - 64
            basicHeaderTemplate = [1, UInt8(leftID & 0xff), UInt8((leftID >> 8) & 0xff)]
        } else if ID > 64 {
            let leftID = ID - 64
            basicHeaderTemplate = [0, UInt8(leftID)]
        } else {
            basicHeaderTemplate = [UInt8(ID)]
        }
        self.ID = ID
    }
    
    var chunkSize = 128
    
    /*
    var lastStreamID: UInt32?
    
    var messageStreams:[RTMPMessageStream] = []
    
    func getMessageStream(messageStreamID:UInt32) -> RTMPMessageStream {
        for messageStream in messageStreams {
            if messageStream.ID == messageStreamID {
                return messageStream
            }
        }
        let stream = RTMPMessageStream(chunkStream: self, ID: messageStreamID)
        messageStreams.insert(stream, at: 0)
        return stream
    }*/
    /*
    func calcNextPayloadSize(streamID: UInt32?) -> Int {
        if let messageStreamID = streamID ?? lastStreamID {
            let messageStream = getMessageStream(messageStreamID: messageStreamID)
            return messageStream.calcNextPayloadSize()
        } else {
            return -1
        }
    }
    */
    /**
     
    func parseChunk(streamID: UInt32, chunkType: UInt8, header: Data, payload: Data) -> RTMPMessage? {
        lastStreamID = streamID
        let messageStream = getMessageStream(messageStreamID: streamID)
        return messageStream.parseChunk(chunkType: chunkType, header: header, payload: payload)
    }
    */

    
    enum UnpackMessageState {
        case waitMessage
        case readMessage
    }
    
    var unpackMessageState: UnpackMessageState = .waitMessage
    var unpackMessageID: UInt32! = nil
    var unpackMessageType: UInt8 = 0
    var unpackMessageLength: Int = 0
    var unpackMessageTimestamp: UInt32 = 0
    var unpackMessageTimestampDelta: UInt32 = 0
    var unpackMessagePayload: Data! = nil
    
    func calcNextPayloadSize(streamID: UInt32?) -> Int {
        if unpackMessageState == .waitMessage {
            return min(unpackMessageLength, chunkSize)
        } else {
            return min(unpackMessageLength - unpackMessagePayload.count, chunkSize)
        }
    }
    
    private func parseTimestamp(header:Data) -> UInt32 {
        var timestamp = RTMPStream.unpackUInt24(header)
        if timestamp == 0xffffff {
            timestamp = header.subdata(in: header.count-4..<header.count).withUnsafeBytes({ (ptr) -> UInt32 in
                return ptr.load(as: UInt32.self).byteSwapped
            })
        }
        return timestamp
    }
    
    func parseMessageChunk(_ chunkType: UInt8, header: Data, payload: Data) -> RTMPMessage? {
        /**
         chunkType 0,1 for new message
         chunkType 2 for register time delta
         chunkType 3 for take all last message's header
         */
        
        /**
         first chunk must type 0
         */
        if unpackMessageID == nil &&
            chunkType != 0 {
            print("[ERROR] parseMessageChunk, chunkStream first chunk must type 0")
            return nil
        }
        
        switch chunkType {
        case 0:
            if unpackMessageState == .readMessage {
                print("[ERROR] WRONG UNPACK STATE WHEN CHUNK TYPE 0")
                return nil
            }
            /**
             update timestamp
             */
            self.unpackMessageID = header.subdata(in: 7..<11).withUnsafeBytes({ (ptr) -> UInt32 in
                return ptr.load(as: UInt32.self).byteSwapped
            })
            self.unpackMessageTimestamp = parseTimestamp(header: header)
            self.unpackMessageLength = Int(RTMPStream.unpackUInt24(header.subdata(in: 3..<6)))
            self.unpackMessageType = header[6]
            self.unpackMessageTimestampDelta = 0
        case 1:
            if unpackMessageState == .readMessage {
                print("[ERROR] WRONG UNPACK STATE WHEN CHUNK TYPE 1")
                return nil
            }
            /**
             update timestamp with delta
             */
            self.unpackMessageTimestamp += parseTimestamp(header: header)
            self.unpackMessageLength = Int(RTMPStream.unpackUInt24(header.subdata(in: 3..<6)))
            self.unpackMessageType = header[6]
            self.unpackMessageTimestampDelta = 0
        case 2:
            self.unpackMessageTimestampDelta = parseTimestamp(header: header)
            self.unpackMessageTimestamp += self.unpackMessageTimestampDelta
        case 3:
            self.unpackMessageTimestamp += self.unpackMessageTimestampDelta
        default:
            return nil
        }
        if self.unpackMessageState == .waitMessage {
            //print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) CREATED")
            self.unpackMessageState = .readMessage
            self.unpackMessagePayload = Data(capacity: self.unpackMessageLength)
        }
        
        unpackMessagePayload.append(payload)
        if unpackMessagePayload.count >= self.unpackMessageLength {
            
            //print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) COMPLETED")
            if self.unpackMessageType == 0x01 && unpackMessagePayload.count == 4 {
                self.chunkSize = unpackMessagePayload.withUnsafeBytes({ (ptr) -> Int in
                    return Int(ptr.load(as: UInt32.self).byteSwapped)
                })
                //print("SET CHUNK \(self.ID) CHUNKSIZE \(self.chunkSize)")
                self.unpackMessageState = .waitMessage
                self.unpackMessagePayload = nil
                return nil
            } else {
                let msg = RTMPMessage(streamID: self.unpackMessageID!, type: self.unpackMessageType, timestamp: self.unpackMessageTimestamp, data: self.unpackMessagePayload, chunkID: self.ID)
                self.unpackMessageState = .waitMessage
                self.unpackMessagePayload = nil
                return msg
            }
        } else {
            //print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) APPEND \(payload.count)")
            return nil
        }
    }
    
    
    /*
    func packMessage(_ message: RTMPMessage, to: RTMPStream) {
        let messageStream = getMessageStream(messageStreamID: message.streamID)
        return messageStream.packMessage(message, to: to)
    }
    */
    
    /**
     last pack message record
     */
    var packMessageStreamID: UInt32? = nil
    var packMessageType: UInt8 = 0
    var packMessageLength: Int = -1
    var packMessageTimestamp: UInt32 = 0
    var packMessageTimestampDelta: UInt32 = 0
    
    func packMessage(_ message: RTMPMessage, to: RTMPStream) {
        var chunkType: UInt8 = 0
        var chunkMessageTimestamp: UInt32 = 0
        
        if packMessageStreamID != message.streamID {
            /// type 0
            chunkType = 0
            chunkMessageTimestamp = message.timestamp
        } else if message.data.count == packMessageLength &&
            message.type == packMessageType {
            /**
             type 2
             type 3
             */
            let timestampDelta = message.timestamp - packMessageTimestamp
            if timestampDelta == packMessageTimestampDelta {
                /**
                 type 3
                 */
                chunkType = 3
            } else {
                /**
                 type 2
                 */
                chunkType = 2
                //packMessageTimestampDelta = timestampDelta
                /**
                 timestampDelta
                 */
                chunkMessageTimestamp = timestampDelta
                
            }
        } else {
            chunkType = 1
            chunkMessageTimestamp = message.timestamp - packMessageTimestamp
            packMessageLength = message.data.count
            packMessageType = message.type
            packMessageTimestamp = message.timestamp
            packMessageTimestampDelta = 0
        }
        
        if chunkType == 0 ||
            chunkType == 1 {
            /**
             chunkType 0 means new streamid
             */
            if chunkType == 0 {
                packMessageStreamID = message.streamID
            }
            packMessageLength = message.data.count
            packMessageType = message.type
            packMessageTimestampDelta = 0
        } else if chunkType == 2 {
            packMessageTimestampDelta = chunkMessageTimestamp
        }
        packMessageTimestamp = message.timestamp
        
        
        var chunkTimestamp: [UInt8]
        var chunkExtTimestamp: [UInt8]
        if chunkType == 3 {
            chunkTimestamp = []
            chunkExtTimestamp = []
        } else if chunkMessageTimestamp > 0x7fffff {
            chunkTimestamp = [0xff, 0xff, 0xff]
            chunkExtTimestamp = withUnsafeBytes(of: chunkMessageTimestamp, { (ptr) -> [UInt8] in
                return ptr.reversed()
            })
        } else {
            chunkTimestamp = [UInt8(chunkMessageTimestamp & 0xff), UInt8((chunkMessageTimestamp>>8)&0xff), UInt8((chunkMessageTimestamp>>16)&0xff)]
            chunkExtTimestamp = []
        }
        
        let chunkSize = self.chunkSize
        var chunkBasicHeader = self.basicHeaderTemplate
        let chunkCount = (packMessageLength + chunkSize - 1) / chunkSize
        /**
         basic header
         */
        chunkBasicHeader[0] |= ((chunkType & 0x3) << 6)
        to.write(bytes: chunkBasicHeader)
        /**
         message header
         */
        switch chunkType {
        case 0:
            /// timestamp
            to.write(bytes: chunkTimestamp)
            /// length
            let lengthData = RTMPStream.packInt24(Int32(packMessageLength))
            to.write(bytes: lengthData)
            /// type
            to.write(message.type)
            /// streamid
            to.writeUInt32(message.streamID)
            //to.write(bytes: self.IDData)
        case 1:
            /// timestamp
            to.write(bytes: chunkTimestamp)
            /// length
            let lengthData = RTMPStream.packInt24(Int32(packMessageLength))
            to.write(bytes: lengthData)
            /// type
            to.write(message.type)
        case 2:
            /// timestamp
            to.write(bytes: chunkTimestamp)
        default:
            break
        }
        
        /**
         ext timestamp
         */
        if !chunkExtTimestamp.isEmpty {
            //chunkData.append(contentsOf: chunkExtTimestamp)
            to.write(bytes: chunkExtTimestamp)
        }
        
        /**
         payload
         */
        
        if chunkCount > 0 {
            chunkBasicHeader[0] |= 0xc0
            var pos = 0
            while packMessageLength - pos > chunkSize {
                to.write(data: message.data.subdata(in: pos..<pos+chunkSize))
                //chunkData.append(contentsOf: chunkBasicHeader)
                to.write(bytes: chunkBasicHeader)
                /**
                 left chunk is all type 3
                 */
                //chunkData[chunkData.count-chunkBasicHeader.count] |= 0xc0
                pos += chunkSize
            }
            to.write(data: message.data.subdata(in: pos..<message.data.count))
        }
        
        //return chunkData
    }

    
}
