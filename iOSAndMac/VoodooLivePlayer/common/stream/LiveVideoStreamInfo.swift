//
//  LiveVideoStreamInfo.swift
//  live_player
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia

public struct LiveVideoStreamInfo {
    public enum CodecID : Int {
        case H264 = 7
        case HEVC = 12
        case UNKONWN
    }
    
    public var videoCodecID: CodecID = .UNKONWN
    
    public var sps:[UInt8]? = nil
    public var pps:[UInt8]? = nil
    public var vps:[UInt8]? = nil  //  for hevc codec
}
