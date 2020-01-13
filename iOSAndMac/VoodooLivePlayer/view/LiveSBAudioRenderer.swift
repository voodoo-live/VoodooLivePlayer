//
//  LiveSBAudioRenderer.swift
//  live_mac
//
//  Created by voodoo on 2019/12/25.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia
import AVKit

class LiveSBAudioRendererNull : LiveRendererProtocol {
    let rendererTimer = LiveTimer(label:"LiveSBAudioRendererNull")
    
    init() {}
    
    var controlTimebase: CMTimebase? {
        get { return rendererTimer?.timebase }
    }
    
    var time: CMTime {
        get { return rendererTimer?.time ?? .invalid }
        set { rendererTimer?.time = newValue }
    }
    
    var rate: Double {
        get { return rendererTimer?.rate ?? 0 }
        set { rendererTimer?.rate = newValue }
    }
    
    func setRate(_ rate: Double, andTime time: CMTime) {
        
    }
    
    func enqueue(_ buffer: CMSampleBuffer) {
        
    }
    
    func flush() {
        
    }
    
    func flushAndRemoveImage() {
        
    }
    
    let isReadyForMoreMediaData: Bool = false
    
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        
    }
    
    func stopRequestingMediaData() {
        
    }
    
    
}

@available(OSX 10.13, *)
@available(iOS 11.0, *)
class LiveSBAudioRenderer : LiveRendererProtocol {
    private let renderer = AVSampleBufferAudioRenderer()
    private let synchronizer = AVSampleBufferRenderSynchronizer()
    private let rendererTimer : LiveTimer
    init() {
        synchronizer.addRenderer(renderer)
        rendererTimer = LiveTimer(timebase:renderer.timebase, label: "LiveSBAudioRenderer")
    }
    
    deinit {
        self.rate = 0
    }
    
    var controlTimebase: CMTimebase? {
        get { return renderer.timebase }
    }
    
    var time: CMTime {
        get { return rendererTimer.time }
        set { synchronizer.setRate(synchronizer.rate, time: newValue) }
    }
    
    var rate: Double {
        get { return Double(synchronizer.rate) }
        set {
            //print("SET VALUE:", newValue, "PREV VALUE:", synchronizer.rate)
            synchronizer.setRate(Float(newValue), time: .invalid)
            //print("NOW VALUE:", synchronizer.rate)
        }
    }
    
    func setRate(_ rate: Double, andTime time: CMTime) {
        synchronizer.setRate(Float(rate), time: time)
    }
    
    func enqueue(_ buffer: CMSampleBuffer) {
        renderer.enqueue(buffer)
    }
    
    
    /**
        @method            flush
        @abstract        Instructs the layer to discard pending enqueued sample buffers.
        @discussion        It is not possible to determine which sample buffers have been decoded,
                        so the next frame passed to enqueueSampleBuffer: should be an IDR frame
                        (also known as a key frame or sync sample).
    */
    func flush() {
        renderer.flush()
    }

    
    /**
        @method            flushAndRemoveImage
        @abstract        Instructs the layer to discard pending enqueued sample buffers and remove any
                        currently displayed image.
        @discussion        It is not possible to determine which sample buffers have been decoded,
                        so the next frame passed to enqueueSampleBuffer: should be an IDR frame
                        (also known as a key frame or sync sample).
    */
    func flushAndRemoveImage() {
        renderer.flush()
    }

    
    /**
        @property        readyForMoreMediaData
        @abstract        Indicates the readiness of the layer to accept more sample buffers.
        @discussion        AVSampleBufferDisplayLayer keeps track of the occupancy levels of its internal queues
                        for the benefit of clients that enqueue sample buffers from non-real-time sources --
                        i.e., clients that can supply sample buffers faster than they are consumed, and so
                        need to decide when to hold back.
                        
                        Clients enqueueing sample buffers from non-real-time sources may hold off from
                        generating or obtaining more sample buffers to enqueue when the value of
                        readyForMoreMediaData is NO.
                        
                        It is safe to call enqueueSampleBuffer: when readyForMoreMediaData is NO, but
                        it is a bad idea to enqueue sample buffers without bound.
                        
                        To help with control of the non-real-time supply of sample buffers, such clients can use
                        -requestMediaDataWhenReadyOnQueue:usingBlock
                        in order to specify a block that the layer should invoke whenever it's ready for
                        sample buffers to be appended.
     
                        The value of readyForMoreMediaData will often change from NO to YES asynchronously,
                        as previously supplied sample buffers are decoded and displayed.
        
                        This property is not key value observable.
    */
    var isReadyForMoreMediaData: Bool {
        get {
            return renderer.isReadyForMoreMediaData
        }
    }

    
    /**
        @method            requestMediaDataWhenReadyOnQueue:usingBlock:
        @abstract        Instructs the target to invoke a client-supplied block repeatedly,
                        at its convenience, in order to gather sample buffers for display.
        @discussion        The block should enqueue sample buffers to the layer either until the layer's
                        readyForMoreMediaData property becomes NO or until there is no more data
                        to supply. When the layer has decoded enough of the media data it has received
                        that it becomes ready for more media data again, it will invoke the block again
                        in order to obtain more.
                        If this function is called multiple times, only the last call is effective.
                        Call stopRequestingMediaData to cancel this request.
                        Each call to requestMediaDataWhenReadyOnQueue:usingBlock: should be paired
                        with a corresponding call to stopRequestingMediaData:. Releasing the
                        AVSampleBufferDisplayLayer without a call to stopRequestingMediaData will result
                        in undefined behavior.
    */
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        renderer.requestMediaDataWhenReady(on: queue, using: block)
    }

    
    /**
        @method            stopRequestingMediaData
        @abstract        Cancels any current requestMediaDataWhenReadyOnQueue:usingBlock: call.
        @discussion        This method may be called from outside the block or from within the block.
    */
    func stopRequestingMediaData() {
        renderer.stopRequestingMediaData()
    }
}

