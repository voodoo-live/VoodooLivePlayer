//
//  H264FormatHelper.swift
//  live_common
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVFoundation

public class VideoFormatHelper {
    public let FRAME_TIMESCALE = Int32(1000)
    public class func videoStreamInfo(fromParameters parameters:Data, withCodecID codecID: LiveVideoStreamInfo.CodecID) -> LiveVideoStreamInfo? {
        /*
            AVCDecoderConfigurationRecord
         
            unsigned int(8) configurationVersion = 1;
            unsigned int(8) AVCProfileIndication;
            unsigned int(8) profile_compatibility;
            unsigned int(8) AVCLevelIndication;
            bits(6) reserved = `111111`b;
            unsigned int(2) lengthSizeMinusOne;
            bits(3) reserved = `111`b;
            unsigned int(5) numOfSequenceParametersSets;
            for (i = 0;i < numOfSequenceParametersSets; i++) {
                unsigned int(16) sequenceParameterSegLength;
                bit(8*sequenceParameterSetLength) sequenceParameterSetNALUnit;
            }
            unsigned int(8) numOfPictureParameterSets;
            for (i = 0;i < numOfPictureParameterSets; i++) {
                unsigned int(16) pictureParameterSetLength;
                bit(8*pictureParameterSetLength) pictureParameterSetNALUnit
            }
        */
        
        
        
        guard parameters[0] == 1 else { return nil }
        guard (parameters[4] & 0xfc) == 0xfc else { return nil }
        //let NALUnitLength = (parameters[4] & 0x3) + 1
        guard (parameters[5] & 0xe0) == 0xe0 else { return nil }

        let spsCount = parameters[5] & 0x1f
        guard spsCount > 0 else { return nil }
        var ptr = 6
        var len = 0
        var sps:[UInt8]?
        for i in 0..<spsCount {
            len = (Int(parameters[ptr]) << 8) + Int(parameters[ptr+1])
            ptr += 2
            if i == 0 {
                sps = [UInt8](parameters.subdata(in: ptr..<ptr+len))
            }
            ptr += len
        }
        let ppsCount = parameters[ptr]
        guard ppsCount > 0 else { return nil }
        var pps:[UInt8]?
        ptr += 1
        len = (Int(parameters[ptr]) << 8) + Int(parameters[ptr+1])
        ptr += 2
        pps = [UInt8](parameters.subdata(in: ptr..<ptr+len))
        
        let vps:[UInt8]? = nil
    
        return LiveVideoStreamInfo(videoCodecID: codecID, sps: sps, pps: pps, vps: vps)
    }
    
    public class func videoFormatDescription(fromStreamInfo streamInfo: LiveVideoStreamInfo) -> CMVideoFormatDescription? {
        return nil
    }
    
    
}
