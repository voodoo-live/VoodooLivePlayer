//
//  LiveDemuxerFLV.swift
//  live_player
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

func flv_demuxer_callback(demuxerPtr:UnsafeMutableRawPointer?, type:Int32, data: UnsafeMutableRawPointer?, size:Int32, tsPointer:UnsafeMutablePointer<Int64>?, flag:UInt32) {
    //player?.handle(demuxerData: Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: data!), count: Int(size), deallocator: .none), withType: type)
    if demuxerPtr == nil { return }
    let demuxer = Unmanaged<LiveFLVDemuxer>.fromOpaque(demuxerPtr!).takeUnretainedValue()

    var ts:[Int64] = [VOODOO_NOPTS_VALUE,VOODOO_NOPTS_VALUE]
    if let tsPtr = tsPointer {
        ts[0] = tsPtr.pointee
        ts[1] = tsPtr.advanced(by: 8).pointee
    }
    demuxer.handleCallback(type: type, dataPtr: data, dataSize: size, ts: ts, flag: flag)
}

class LiveFLVDemuxer : LiveDemuxer {
    
    private var flvDemuxerContext: UnsafeMutableRawPointer? = nil
        
    class func initDemuxer(demuxer:inout LiveFLVDemuxer) {
        let selfPtr = withUnsafeMutablePointer(to: &demuxer, {return $0})
        demuxer.flvDemuxerContext = flv_demuxer_init(selfPtr, flv_demuxer_callback)
    }
    
    override init(delegate:LiveDemuxerDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        super.init(delegate: delegate, delegateQueue: delegateQueue)
        let selfPtr = Unmanaged<LiveFLVDemuxer>.passUnretained(self).toOpaque()
        self.flvDemuxerContext = flv_demuxer_init(selfPtr, flv_demuxer_callback)
    }
    
    deinit {
        if self.flvDemuxerContext != nil {
            flv_demuxer_fint(self.flvDemuxerContext)
            self.flvDemuxerContext = nil
        }
    }
    
    fileprivate func handleCallback(type:Int32, dataPtr: UnsafeMutableRawPointer?, dataSize:Int32, ts:[Int64], flag:UInt32) {
        var data: Data?
        if dataPtr != nil {
            data = Data(bytesNoCopy: dataPtr!, count: Int(dataSize), deallocator: .none)
        } else {
            data = Data()
        }
        
        if let dataType = LivePipelineDataType(rawValue: Int(type)) {
            delegate?.handle(demuxerData: data!, withType: dataType, ts: ts, flag: flag)
        } else {
            print("UNKNOWN FLV DATA TYPE VALUE: \(type)")
        }
        
        
    }
    
    override func feed(data:Data) {
        let dataLength = data.count
        data.withUnsafeBytes { (ptr) -> Void in
            if let dataPtr = ptr.baseAddress {
                flv_demuxer_feed(self.flvDemuxerContext, dataPtr, Int32(dataLength))
            }
        }
    }
}
