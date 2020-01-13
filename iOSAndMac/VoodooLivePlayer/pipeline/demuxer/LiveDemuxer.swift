//
//  LiveDemuxer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

protocol LiveDemuxerDelegate : class {
    func handle(demuxerData data:Data, withType type: LivePipelineDataType, ts: [Int64], flag: UInt32)
    func handle(demuxerError error:Error?)
}

class LiveDemuxer : LivePlayerComponent{
    weak var delegate: LiveDemuxerDelegate?
    unowned var delegateQueue: DispatchQueue?

    init(delegate:LiveDemuxerDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue == nil ? DispatchQueue.main : delegateQueue
    }
    func feed(data:Data) {}
    
    func start() -> Bool { true }
    func stop() {}
}
