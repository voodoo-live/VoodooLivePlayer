//
//  LiveSampleBufferAudioDecoder.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVFoundation

class LiveSampleBufferAudioDecoder : LiveAudioDecoder {
    private let streamInfo: LiveAudioStreamInfo
    private let formatDescription: CMAudioFormatDescription
    private var nextFrameTimestamp: CMTime
    init?(streamInfo:LiveAudioStreamInfo, delegate: LiveDecoderDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        if let formatDescription = AACFormatHelper.audioFormatDescription(fromStreamInfo: streamInfo) {
            self.formatDescription = formatDescription
            self.streamInfo = streamInfo
            self.nextFrameTimestamp = CMTimeMake(value: 0, timescale: Int32(self.streamInfo.sampleRate))
            super.init(delegate: delegate, delegateQueue: delegateQueue)
        } else {
            return nil
        }
    }
    
    override func feed(data:Data, ts:[Int64], flag:UInt32) {
        if let frame = LiveAudioCodedFrame(streamInfo: self.streamInfo, formatDescription: self.formatDescription, data: data, pts: ts[0], presentationTimeStamp: self.nextFrameTimestamp), let sampleBuffer = frame.sampleBuffer {
            let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
            let pts = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            self.nextFrameTimestamp = pts + duration;
            self.delegateQueue!.async {
                self.delegate?.handle(decoder: self, outputFrame: frame)
            }
        }
    }
}
