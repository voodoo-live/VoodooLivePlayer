//
//  RTMPMessageStream.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/8.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class RTMPMessageStream {
    unowned let chunkStream: RTMPChunkStream
    let ID: UInt32
    let IDData: [UInt8]
    init(chunkStream: RTMPChunkStream, ID: UInt32) {
        self.chunkStream = chunkStream
        self.ID = ID
        IDData = withUnsafeBytes(of: self.ID, { (ptr) -> [UInt8] in
            return ptr.reversed()
        })
    }

    
    enum UnpackMessageState {
        case waitMessage
        case readMessage
    }
    
    var unpackMessageState: UnpackMessageState = .waitMessage
    var unpackMessageType: UInt8 = 0
    var unpackMessageLength: Int = 0
    var unpackMessageTimestamp: UInt32 = 0
    var unpackMessageTimestampDelta: UInt32 = 0
    var unpackMessagePayload = Data()
    
    func calcNextPayloadSize() -> Int {
        if unpackMessageState == .waitMessage {
            return unpackMessageLength
        } else {
            return (unpackMessageLength - unpackMessagePayload.count)
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
    
    func parseChunk(chunkType: UInt8, header: Data, payload: Data) -> RTMPMessage? {
        /**
         chunkType 0,1 for new message
         chunkType 2 for register time delta
         chunkType 3 for take all last message's header
         */
        switch chunkType {
        case 0:
            if unpackMessageState == .readMessage {
                print("ERROR CHUNK TYPE 0")
                return nil
            }
            /**
             update timestamp
             */
            self.unpackMessageTimestamp = parseTimestamp(header: header)
            self.unpackMessageLength = Int(RTMPStream.unpackUInt24(header.subdata(in: 3..<6)))
            self.unpackMessageType = header[6]
            self.unpackMessageTimestampDelta = 0
        case 1:
            if unpackMessageState == .readMessage {
                print("ERROR CHUNK TYPE 1")
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
            print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) CREATED")
            self.unpackMessageState = .readMessage
            self.unpackMessagePayload.reserveCapacity(self.unpackMessageLength)
        }
        
        unpackMessagePayload.append(payload)
        if unpackMessagePayload.count >= self.unpackMessageLength {
            print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) COMPLETED")
            let msg = RTMPMessage(streamID: self.ID, type: self.unpackMessageType, timestamp: self.unpackMessageTimestamp, data: self.unpackMessagePayload)
            self.unpackMessageState = .waitMessage
            self.unpackMessagePayload.count = 0
            return msg
        } else {
            print("STREAM \(self.ID) MESSAGE \(self.unpackMessageType) LENGTH \(self.unpackMessageLength) APPEND \(payload.count)")
            return nil
        }
    }
    
    
    func abortMessage() {
        unpackMessageState = .waitMessage
        unpackMessagePayload.count = 0
    }
    
    /**
     last pack message record
     */
    var packMessageType: UInt8 = 0
    var packMessageLength: Int = -1
    var packMessageTimestamp: UInt32 = 0
    var packMessageTimestampDelta: UInt32 = 0
    
    func packMessage(_ message: RTMPMessage, to: RTMPStream) {
        var chunkType: UInt8 = 0
        var chunkMessageTimestamp: UInt32 = 0

        if message.data.count == packMessageLength &&
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
                packMessageTimestampDelta = timestampDelta
                /**
                 timestampDelta
                 */
                chunkMessageTimestamp = timestampDelta
                
            }
        } else {
            if packMessageLength == -1 {
                chunkType = 0
                chunkMessageTimestamp = message.timestamp
            } else {
                chunkType = 1
                chunkMessageTimestamp = message.timestamp - packMessageTimestamp
            }
            packMessageLength = message.data.count
            packMessageType = message.type
            packMessageTimestamp = message.timestamp
            packMessageTimestampDelta = 0
        }
        
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
        
        let chunkSize = self.chunkStream.netConnection.chunkSize
        var chunkBasicHeader = self.chunkStream.basicHeaderTemplate
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
            to.write(bytes: self.IDData)
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
