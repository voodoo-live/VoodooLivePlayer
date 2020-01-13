//
//  LiveRTMPDemuxer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/6.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class LiveRTMPDemuxer : LiveDemuxer {
    override init(delegate:LiveDemuxerDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        super.init(delegate: delegate, delegateQueue: delegateQueue)
    }
    
    deinit {
    }
        
    override func feed(data:Data) {
        //let dataLength = data.count
        data.withUnsafeBytes { (ptr) -> Void in
        }
    }
}
