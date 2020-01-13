//
//  AACPlaybackConfiguration.swift
//  live_player
//
//  Created by voodoo on 2019/12/17.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVFoundation

public struct LiveAudioStreamInfo {
    public var sampleRate:Int = 44100
    public var channels:Int = 2
    public var samplesPerPacket:Int = 1024
    public var formatID:AudioFormatID = kAudioFormatMPEG4AAC
}
