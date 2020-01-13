//
//  LiveSBVideoRenderer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/25.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia
import AVKit

class LiveSBVideoRenderer : LiveRendererProtocol {
    private let displayLayer: AVSampleBufferDisplayLayer
    //private let createdTimeBase: CMTimebase?
    private let displayTimer: LiveTimer!
    init(displayLayer:AVSampleBufferDisplayLayer, masterClock: CMClock = CMClockGetHostTimeClock()) {
        self.displayLayer = displayLayer
        self.displayTimer = LiveTimer(masterClock: masterClock, label: "LiveSBVideoRenderer")
        self.displayLayer.controlTimebase = self.displayTimer.timebase
    }
    
    deinit {
        print("VIDEO RENDERER DEINIT")
        if !displayTimer.isCreated {
            displayLayer.controlTimebase = nil
        }
    }
    
    var controlTimebase: CMTimebase? {
        get { return displayTimer.timebase }
    }
    
    var time: CMTime {
        get { return displayTimer.time }
        set { displayTimer.time = newValue }
    }
    
    var rate: Double {
        get { return displayTimer.rate }
        set { displayTimer.rate = newValue }
    }
    
    func setRate(_ rate: Double, andTime time: CMTime) {
        displayTimer.setRate(rate, andTime: time)
    }
    
    func enqueue(_ buffer: CMSampleBuffer) {
        displayLayer.enqueue(buffer)
    }

    func flush() {
        displayLayer.flush()
    }

    func flushAndRemoveImage() {
        displayLayer.flush()
    }
    var isReadyForMoreMediaData: Bool {
        get { return displayLayer.isReadyForMoreMediaData }
    }

    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        displayLayer.requestMediaDataWhenReady(on: queue, using: block)
    }

    func stopRequestingMediaData() {
        displayLayer.stopRequestingMediaData()
    }
}

