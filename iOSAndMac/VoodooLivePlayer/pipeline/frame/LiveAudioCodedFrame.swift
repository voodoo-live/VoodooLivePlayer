//
//  LiveAudioCodedFrame.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/13.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VideoToolbox

public class LiveAudioCodedFrame : LiveAudioFrame {
    
    private func initSampleBuffer(streamInfo: LiveAudioStreamInfo, formatDescription: CMAudioFormatDescription, data: Data, presentationTimeStamp: CMTime) -> Bool {
        var blockBuffer: CMBlockBuffer?
        /*
         Create memory block
         */
        let dataLength = data.count
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: dataLength, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: dataLength, flags: 0, blockBufferOut: &blockBuffer)
        
        guard status == kCMBlockBufferNoErr, blockBuffer != nil else {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            return false
        }
        
        status = data.withUnsafeBytes( { (vp:UnsafeRawBufferPointer) -> OSStatus in
            return CMBlockBufferReplaceDataBytes(with: vp.baseAddress!, blockBuffer: blockBuffer!, offsetIntoDestination: 0, dataLength: dataLength)
        })

        guard status == kCMBlockBufferNoErr else {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            return false
        }
        
        let timescale = Int32(streamInfo.sampleRate)
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = presentationTimeStamp
        timingInfo.decodeTimeStamp = .invalid
        timingInfo.duration = CMTimeMake(value: Int64(streamInfo.samplesPerPacket), timescale: timescale)
        
        let sampleSizeArray = [dataLength]
        let timingInfoArray = [timingInfo]
        
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                           dataBuffer: blockBuffer,
                                           formatDescription: formatDescription,
                                           sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: timingInfoArray,
                                           sampleSizeEntryCount: 1, sampleSizeArray: sampleSizeArray,
                                           sampleBufferOut: &self.sampleBuffer)
        
        if status != kCMBlockBufferNoErr {
            print(NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            return false
        }
        
        return true
    }
    
    init?(streamInfo: LiveAudioStreamInfo, formatDescription: CMAudioFormatDescription, data: Data, pts: Int64, presentationTimeStamp: CMTime) {
        super.init()
        if !initSampleBuffer(streamInfo: streamInfo, formatDescription: formatDescription, data: data, presentationTimeStamp: presentationTimeStamp) {
            return nil
        }
        
        self.contentType = .AUDIO
        self.decoded = false
        self.pts = pts
    }
}
