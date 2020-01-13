//
//  AACFormatHelper.swift
//  live_player
//
//  Created by voodoo on 2019/12/17.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVFoundation

public class AACFormatHelper {
    private static let SAMPLE_RATE_TABLE:[Int] = [96000,88200,64000,48000,44100,32000,24000,22050,16000,12000,11025,8000,7350,0,0,-1]
    
    public class func audioStreamInfo(fromADTSHeaderRawData data:Data) -> LiveAudioStreamInfo? {
        //let headerData = data.subdata(in: dataOffset..<dataOffset+7)
        guard data[0] == 0xff && (data[1] & 0xf0) == 0xf0 else { return nil }   ///     leading bits must 0xfff
        guard (data[1] & 0x8) == 0 else { return nil }                          ///     id must mpeg4(0)
        guard (data[1] & 0x6) == 0 else { return nil }                          ///     layer must be 00
        /*
         aot - 1
         0 = Main
         1 = LC
         2 = SSR
         3 = OTHER
         */
        let profile = (data[2] & 0xc0) >> 6
        guard profile == 1 else { return nil }                                  ///     must be AAC-LC
        /*
         samplerate table index
         */
        var sampleRate = AACFormatHelper.SAMPLE_RATE_TABLE[Int((data[2] & 0x3c) >> 2)]
        if sampleRate == 0 || sampleRate == -1 {
            return nil
        }
        var samplesPerPacket = 1024
        var channels = Int(((data[2] & 1) << 2) | ((data[3]&0xc0) >> 6))
        var formatID = kAudioFormatMPEG4AAC
        if sampleRate == 22050 {
            sampleRate = 44100
            samplesPerPacket = 2048
            if channels == 1 {
                channels = 2
                formatID = kAudioFormatMPEG4AAC_HE_V2
            } else {
                formatID = kAudioFormatMPEG4AAC_HE
            }
        }
        
        return LiveAudioStreamInfo(sampleRate: sampleRate, channels: channels, samplesPerPacket: samplesPerPacket, formatID: formatID)
    }
    
    public class func audioStreamInfo(fromAudioSpecificConfigRawData data:Data) -> LiveAudioStreamInfo? {
        
        let bitReader = BitStream(data)
        
        
        /*
         AudioSpecificConfig
         
         5 bits: object type
         if (object type == 31)
             6 bits + 32: object type
         4 bits: frequency index
         if (frequency index == 15)
             24 bits: frequency
         4 bits: channel configuration
         var bits: AOT Specific Config
         GASpecificConfig <for standard aac stream> {
             1 bit: frame length flag
             1 bit: dependsOnCoreCoder
             1 bit: extensionFlag
         }
         */
        
        let audioObjectType = bitReader.read(bitsCount: 5)
        var formatID = kAudioFormatMPEG4AAC
        /*
         only support AAC-LC, HE-AAC, HE-AAC v2
         */
        switch audioObjectType {
        case 2:
            formatID = kAudioFormatMPEG4AAC
        case 5:
            formatID = kAudioFormatMPEG4AAC_HE
        case 29:
            formatID = kAudioFormatMPEG4AAC_HE_V2
        default:
            return nil
        }
        var sampleRate = 44100
        let frequencyIndex = bitReader.read(bitsCount: 4)
        if frequencyIndex == 15 {
            sampleRate = bitReader.read(bitsCount: 24)
        } else {
            sampleRate = AACFormatHelper.SAMPLE_RATE_TABLE[frequencyIndex]
        }
        var channels = bitReader.read(bitsCount: 4)
        
        let frameLengthFlag = bitReader.read(bitsCount: 1)
        
        var samplesPerPacket = 1024
        if frameLengthFlag == 1 {
            samplesPerPacket = 960
        }
        
        if sampleRate == 22050 {
            sampleRate = 44100
            samplesPerPacket *= 2
            if channels == 1 {
                channels = 2
                formatID = kAudioFormatMPEG4AAC_HE_V2
            } else {
                formatID = kAudioFormatMPEG4AAC_HE
            }
        }
        return LiveAudioStreamInfo(sampleRate: sampleRate, channels: channels, samplesPerPacket: samplesPerPacket, formatID: formatID)
    }
    
    /*
     AOT TYPES
     0: Null
     1: AAC Main
     2: AAC LC (Low Complexity)                     <-  AAC-LC
     3: AAC SSR (Scalable Sample Rate)
     4: AAC LTP (Long Term Prediction)
     5: SBR (Spectral Band Replication)             <-  HE-AAC
     6: AAC Scalable
     7: TwinVQ
     8: CELP (Code Excited Linear Prediction)
     9: HXVC (Harmonic Vector eXcitation Coding)
     10: Reserved
     11: Reserved
     12: TTSI (Text-To-Speech Interface)
     13: Main Synthesis
     14: Wavetable Synthesis
     15: General MIDI
     16: Algorithmic Synthesis and Audio Effects
     17: ER (Error Resilient) AAC LC
     18: Reserved
     19: ER AAC LTP
     20: ER AAC Scalable
     21: ER TwinVQ
     22: ER BSAC (Bit-Sliced Arithmetic Coding)
     23: ER AAC LD (Low Delay)
     24: ER CELP
     25: ER HVXC
     26: ER HILN (Harmonic and Individual Lines plus Noise)
     27: ER Parametric
     28: SSC (SinuSoidal Coding)
     29: PS (Parametric Stereo)                     <-  HE-AAC v2
     30: MPEG Surround
     31: (Escape value)
     32: Layer-1
     33: Layer-2
     34: Layer-3
     35: DST (Direct Stream Transfer)
     36: ALS (Audio Lossless)
     37: SLS (Scalable LosslesS)
     38: SLS non-core
     39: ER AAC ELD (Enhanced Low Delay)
     40: SMR (Symbolic Music Representation) Simple
     41: SMR Main
     42: USAC (Unified Speech and Audio Coding) (no SBR)
     43: SAOC (Spatial Audio Object Coding)
     44: LD MPEG Surround
     45: USAC
     */
    
    public class func audioFormatDescription(fromStreamInfo streamInfo: LiveAudioStreamInfo) -> CMAudioFormatDescription? {
        var audioFormatDescription:CMAudioFormatDescription?
        var audioStreamBasicDescription = AudioStreamBasicDescription(mSampleRate: Float64(streamInfo.sampleRate), mFormatID: streamInfo.formatID, mFormatFlags: 0, mBytesPerPacket: 0, mFramesPerPacket: UInt32(streamInfo.samplesPerPacket), mBytesPerFrame: 0, mChannelsPerFrame: UInt32(streamInfo.channels), mBitsPerChannel: 0, mReserved: 0)
        let status = CMAudioFormatDescriptionCreate(allocator: kCFAllocatorDefault, asbd: &audioStreamBasicDescription, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil, formatDescriptionOut: &audioFormatDescription)
        
        guard status == noErr else {
            return nil
        }

        return audioFormatDescription
    }
    
}
