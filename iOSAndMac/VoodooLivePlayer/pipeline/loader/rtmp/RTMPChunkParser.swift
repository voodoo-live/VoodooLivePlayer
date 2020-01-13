//
//  RTMPChunkParser.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/9.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation


class RTMPChunkParser {
    
    static let ChunkTypeMessageHeaderSize = [11, 7, 3, 0]
    static let ChunkStreamIDSpecialSize = [1, 2]
    unowned let connection: RTMPNetConnection
    init(connection:RTMPNetConnection) {
        self.connection = connection
    }
    
    enum State : Int {
        case start
        case readTimestamp
        case readHeader
        case readPayload
        case failed
    }
    
    var state : State = .start
    
    var readingHeader = Data(repeating: 0, count: 20)
    var readingChunkType: UInt8 = 0
    var readingChunkStreamID: UInt32 = 0
    var readingHeaderSize = 0
    var readingBasicHeaderSize = 0
    var readingPayloadSize = 0
    var readingPayload = Data()

    ///
    func parse(rawData: Data) -> [RTMPMessage]? {
        var messages:[RTMPMessage]? = nil
        var pos = 0
        
        while pos < rawData.count {
            var bytesAvaliable = rawData.count - pos
            switch state {
            case .start:
                let firstByte = rawData[pos]
                readingChunkType = (firstByte & 0xc0) >> 6
                readingChunkStreamID = UInt32(firstByte & 0x3f)
                readingBasicHeaderSize = 1 + (readingChunkStreamID < 2 ? Int(readingChunkStreamID) + 1 : 0)
                readingHeaderSize = readingBasicHeaderSize + RTMPChunkParser.ChunkTypeMessageHeaderSize[Int(readingChunkType)]
                readingHeader.count = 0
                
                if readingChunkType == 3 {
                    state = .readHeader
                } else {
                    state = .readTimestamp
                    fallthrough
                }
            case .readTimestamp:
                let copySize = min(bytesAvaliable, readingHeaderSize - readingHeader.count)
                readingHeader.append(rawData.subdata(in: pos..<pos+copySize))
                pos += copySize
                if readingHeader.count < readingBasicHeaderSize + 3 {
                    break
                }
                let timestamp = RTMPStream.unpackUInt24(readingHeader.subdata(in: readingBasicHeaderSize..<readingBasicHeaderSize + 3))
                if timestamp == 0xffffff {
                    readingHeaderSize += 4
                }
                state = .readHeader
                bytesAvaliable -= copySize
                if bytesAvaliable == 0 {
                    break
                }
                fallthrough
            case .readHeader:
                let copySize = min(bytesAvaliable, readingHeaderSize - readingHeader.count)
                readingHeader.append(rawData.subdata(in: pos..<pos+copySize))
                pos += copySize
                if readingHeaderSize > readingHeader.count {
                    break
                }
                /**
                 determind chunk payload size
                 */
                if readingChunkStreamID < 2 {
                    readingChunkStreamID = 64+UInt32(readingHeader[1])+(readingChunkStreamID==0 ? 0 : UInt32(readingHeader[2])*256)
                }
                let chunkStream = connection.getChunkStream(chunkStreamID: readingChunkStreamID)
                if readingChunkType == 0 || readingChunkType == 1 {
                    let messageLength = Int(RTMPStream.unpackUInt24(readingHeader.subdata(in: readingBasicHeaderSize+3..<readingBasicHeaderSize+6)))
                    readingPayloadSize = min(messageLength, chunkStream.chunkSize)
                } else {
                    if chunkStream.unpackMessageID == nil {
                        state = .failed
                        pos = rawData.count
                        break
                    }
                    let messageLength = chunkStream.unpackMessageLength
                    readingPayloadSize = chunkStream.unpackMessageState == .waitMessage ?
                        min(chunkStream.chunkSize, messageLength) :       /** no reading message, leftSize == messageLength*/
                        min(chunkStream.chunkSize, messageLength - chunkStream.unpackMessagePayload.count)  /** has reading message, leftSize = messageLength - readSize */
                }
                
                    
                //print("CHUNK PAYLOAD SIZE:\(readingPayloadSize)")

                readingPayload.reserveCapacity(connection.chunkSize)
                readingPayload.count = 0
                state = .readPayload
                bytesAvaliable = rawData.count - pos
                if bytesAvaliable > 0 {
                    fallthrough
                }
            case .readPayload:
                let leftPayloadSize = readingPayloadSize - readingPayload.count
                if bytesAvaliable < leftPayloadSize {
                    readingPayload.append(rawData.subdata(in: pos..<rawData.count))
                    pos = rawData.count
                } else {
                    let payloadData = rawData.subdata(in: pos..<pos+leftPayloadSize)
                    pos += leftPayloadSize
                    if !readingPayload.isEmpty { readingPayload.append(payloadData) }
                    let headerData = readingHeader.subdata(in: readingBasicHeaderSize..<readingHeader.count)
                    let chunkStream = connection.getChunkStream(chunkStreamID: readingChunkStreamID)

                    if let message = chunkStream.parseMessageChunk(readingChunkType, header: headerData, payload: readingPayload.isEmpty ? payloadData : readingPayload) {
                        if !connection.filterMessage(message: message) {
                            if messages == nil {
                                messages = [message]
                            } else {
                                messages?.append(message)
                            }
                        }
                    }
                    state = .start
                }
            case .failed: return nil
            }
        }
        return messages
    }
}
