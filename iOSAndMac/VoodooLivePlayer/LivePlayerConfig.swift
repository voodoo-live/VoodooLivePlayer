//
//  LivePlayerConfig.swift
//  live_player
//
//  Created by voodoo on 2019/12/10.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public struct LivePlayerConfig {
    public enum RenderMethod {
        case AUTO
        case SYSTEM
        case SOFTWARE
        case HARDWARE
        case NOT_RENDER
    }
    
    public var videoRenderMethod: RenderMethod = .NOT_RENDER
    public var audioRenderMethod: RenderMethod = .NOT_RENDER
    
    public init(videoRenderMethod: RenderMethod, audioRenderMethod: RenderMethod) {
        self.videoRenderMethod = videoRenderMethod
        self.audioRenderMethod = audioRenderMethod
    }
}
