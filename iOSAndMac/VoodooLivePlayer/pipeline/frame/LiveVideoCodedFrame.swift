//
//  LiveCodedVideoFrame.swift
//  live_player
//
//  Created by voodoo on 2019/12/11.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VideoToolbox

public final class LiveVideoCodedFrame : LiveVideoFrame {
    func initSampleBuffer(formatDesc:CMVideoFormatDescription, dataPtr:UnsafeRawPointer, length:Int, ts:[Int64]) -> Bool {
        /*print("kCMBlockBufferNoErr", kCMBlockBufferNoErr)
        print("kCMBlockBufferStructureAllocationFailedErr",kCMBlockBufferStructureAllocationFailedErr)
        print("kCMBlockBufferBlockAllocationFailedErr",kCMBlockBufferBlockAllocationFailedErr)
        print("kCMBlockBufferBadCustomBlockSourceErr",kCMBlockBufferBadCustomBlockSourceErr)
        print("kCMBlockBufferBadOffsetParameterErr",kCMBlockBufferBadOffsetParameterErr)
        print("kCMBlockBufferBadLengthParameterErr",kCMBlockBufferBadLengthParameterErr)
        print("kCMBlockBufferBadPointerParameterErr",kCMBlockBufferBadPointerParameterErr)
        print("kCMBlockBufferEmptyBBufErr",kCMBlockBufferEmptyBBufErr)
        print("kCMBlockBufferUnallocatedBlockErr",kCMBlockBufferUnallocatedBlockErr)
        print("kCMBlockBufferInsufficientSpaceErr",kCMBlockBufferInsufficientSpaceErr)*/
        var blockBuffer: CMBlockBuffer?
        /*
         修改成数据拷贝到blockbuffer里，然后设置到samplebuffer里。
         这样sample用完自己销毁了。
         */
        
        //var status = CMBlockBufferCreateEmpty(allocator: kCFAllocatorDefault, capacity: UInt32(length), flags: 0, blockBufferOut: &blockBuffer)
        
        var status = CMBlockBufferCreateWithMemoryBlock(allocator: kCFAllocatorDefault, memoryBlock: nil, blockLength: length, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: length, flags: 0, blockBufferOut: &blockBuffer)
        
        if status != kCMBlockBufferNoErr {
            print("CMBlockBufferCreateEmpty - ", status)
            return false
        }
        
        if let buffer = blockBuffer {
            status = CMBlockBufferReplaceDataBytes(with: dataPtr, blockBuffer: buffer, offsetIntoDestination: 0, dataLength: length)
            if status != kCMBlockBufferNoErr {
                print("CMBlockBufferReplaceDataBytes - ", status)
                return false
            }
        } else {
            return false
        }
        let pts = ts[0], _ = ts[1]
        var timingInfo = CMSampleTimingInfo()
        timingInfo.presentationTimeStamp = CMTimeMake(value: pts, timescale: Constants.VIDEO_TIME_SCALE)
        timingInfo.decodeTimeStamp = .invalid//CMTimeMake(value: dts, timescale: Constants.VIDEO_TIME_SCALE)
        timingInfo.duration = .invalid// CMTimeMake(value: 1000*600/24, timescale: 600)
        let sampleSizeArray = [length]
        let timingInfoArray = [timingInfo]
        
        status = CMSampleBufferCreateReady(allocator: kCFAllocatorDefault,
                                           dataBuffer: blockBuffer,
                                           formatDescription: formatDesc,
                                           sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: timingInfoArray,
                                           sampleSizeEntryCount: 1, sampleSizeArray: sampleSizeArray,
                                           sampleBufferOut: &self.sampleBuffer)
        
        if status != kCMBlockBufferNoErr {
            return false
        }
        
        return true
    }
    
    init?(formatDesc:CMVideoFormatDescription, videoData:UnsafeRawPointer, videoDataLength:Int, ts:[Int64]) {
        super.init()
        if !initSampleBuffer(formatDesc: formatDesc, dataPtr: videoData, length: videoDataLength, ts: ts) {
            return nil
        }
        
        self.contentType = .VIDEO
        self.decoded = false
        self.pts = ts[0]
    }
    
    func setDisplayImmediately(_ value:Bool) {
        if let buffer = self.sampleBuffer, let attachmentArray = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) {
            let dic = unsafeBitCast(CFArrayGetValueAtIndex(attachmentArray, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(dic,
                                 Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                                 Unmanaged.passUnretained(value ? kCFBooleanTrue : kCFBooleanFalse).toOpaque())
        }
    }
}
