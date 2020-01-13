//
//  RTMPMessage.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/8.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class RTMPMessage {
    init(streamID: UInt32, type: UInt8, timestamp: UInt32, data: Data, chunkID: UInt32 = 0) {
        self.streamID = streamID
        self.type = type
        self.timestamp = timestamp
        self.data = data
        self.chunkID = chunkID
    }
    let chunkID: UInt32
    let streamID: UInt32
    let type: UInt8
    let timestamp: UInt32
    let data: Data
}
