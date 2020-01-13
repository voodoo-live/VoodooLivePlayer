//
//  LiveFrame.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VideoToolbox

public class LiveFrame {
    public enum ContentType {
        case VIDEO
        case AUDIO
        case UNKNOWN
    }
    
    public var pts: Int64 = VOODOO_NOPTS_VALUE
    public var contentType: ContentType = .UNKNOWN
    public var decoded: Bool = false
    public var keyFrame: Bool = false
    public var sampleBuffer: CMSampleBuffer?
}
