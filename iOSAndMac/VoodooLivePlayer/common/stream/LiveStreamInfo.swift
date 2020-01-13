//
//  LiveMediaInfo.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/13.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia

public class LiveStreamInfo {
    public var source:LiveStreamSource
    public init(source:LiveStreamSource) {
        self.source = source
    }
        
    public var hasAudioStream:Bool = false
    public var audioStreamInfo:LiveAudioStreamInfo?
    public var audioNextPresentationTime:CMTime = CMTimeMake(value: 0, timescale: 1000)

    public var hasVideoStream:Bool = false
    public var videoStreamInfo:LiveVideoStreamInfo?
    
    
    
    public var videoWidth:Int = 0
    public var videoHeight:Int = 0
    public var videoCodecID:Int = 0
    public var videoProfile:Int = 0
    public var videoLevel:Int = 0
    public var videoFormatDesc:CMVideoFormatDescription? = nil
}
