//
//  LiveSampleBufferVideoDecoder.swift
//  live_player
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVFoundation

class LiveSampleBufferVideoDecoder : LiveVideoDecoder {
    private let streamInfo: LiveVideoStreamInfo
    private let formatDescription: CMVideoFormatDescription
    init?(streamInfo:LiveVideoStreamInfo, delegate: LiveDecoderDelegate? = nil, delegateQueue: DispatchQueue?) {
        self.streamInfo = streamInfo
        if let formatDesc = LiveSampleBufferVideoDecoder.createFormatDescription(streamInfo: streamInfo) {
            formatDescription = formatDesc
            super.init(delegate: delegate, delegateQueue: delegateQueue)
        } else {
            return nil
        }
    }
    
    private class func createFormatDescription(streamInfo: LiveVideoStreamInfo) -> CMVideoFormatDescription? {
        var formatDescription:CMVideoFormatDescription? = nil
        let pointerSPS = UnsafePointer<UInt8>(streamInfo.sps!)
        let pointerPPS = UnsafePointer<UInt8>(streamInfo.pps!)
        // make pointers array
        let dataParamArray = [pointerSPS, pointerPPS]
        let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)
        
        // make parameter sizes array
        let sizeParamArray = [streamInfo.sps!.count, streamInfo.pps!.count]
        let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
        
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: kCFAllocatorDefault, parameterSetCount: 2, parameterSetPointers: parameterSetPointers, parameterSetSizes: parameterSetSizes, nalUnitHeaderLength: 4, formatDescriptionOut: &formatDescription)
        
        guard status == noErr else { return nil }
        
        return formatDescription
    }
    
    override func feed(data:Data, ts:[Int64], flag:UInt32) {
        let dataLength = data.count
        if let videoFrame = data.withUnsafeBytes ({ (vp:UnsafeRawBufferPointer) -> LiveVideoCodedFrame? in
            if let dataPtr = vp.baseAddress {
                return LiveVideoCodedFrame(formatDesc: self.formatDescription, videoData: dataPtr, videoDataLength: dataLength, ts: ts)
            }
            return nil
        }) {
            if flag == VOODOO_VIDEO_PACKET_FLAG_IS_KEY_FRAME {
                videoFrame.keyFrame = true
            }
            delegate?.handle(decoder: self, outputFrame: videoFrame)
        }
    }
}
