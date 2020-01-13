//
//  LivePlayer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import QuartzCore
import AVKit
#if os(OSX)
import Cocoa
public typealias LiveViewType = NSView
public typealias LiveViewControllerType = NSViewController
#elseif os(iOS)
import UIKit
public typealias LiveViewType = UIView
public typealias LiveViewControllerType = UIViewController
#endif
/**
    pipe line:
 
        【protocol】-》【demuxer】-》【decoder】-》【renderer】
 */
public enum LivePlayerState : Int {
    case READY = 0
    case LOADING = 1
    case PLAYING = 2
    case FINISHED = 3
    case ERROR = 4
}

public protocol LivePlayerDelegate : class {
    func handle(stateChangedFrom from:LivePlayerState, to:LivePlayerState)
}
public enum LiveMediaPlayerStatus : Int {
    case READY = 0
    case CACHING = 1
    case PLAYING = 2
    case REDUCING = 3
    case FAILED = 4
}

public protocol LiveMediaPlayerProtocol : class {
    var controlTimebase: CMTimebase? { get }
    var status: LiveMediaPlayerStatus { get }
    func enqueueFrame(_ frame: LiveFrame)
    func flush()
}


public protocol LiveRendererProtocol : class {
    var controlTimebase: CMTimebase? { get }
    var time: CMTime { get set }
    var rate: Double { get set }
    func setRate(_ rate: Double, andTime time: CMTime)
    func enqueue(_ buffer:CMSampleBuffer)
    
    /**
        @method            flush
        @abstract        Instructs the layer to discard pending enqueued sample buffers.
        @discussion        It is not possible to determine which sample buffers have been decoded,
                        so the next frame passed to enqueueSampleBuffer: should be an IDR frame
                        (also known as a key frame or sync sample).
    */
    func flush()

    
    /**
        @method            flushAndRemoveImage
        @abstract        Instructs the layer to discard pending enqueued sample buffers and remove any
                        currently displayed image.
        @discussion        It is not possible to determine which sample buffers have been decoded,
                        so the next frame passed to enqueueSampleBuffer: should be an IDR frame
                        (also known as a key frame or sync sample).
    */
    func flushAndRemoveImage()

    
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
    var isReadyForMoreMediaData: Bool { get }

    
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
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)

    
    /**
        @method            stopRequestingMediaData
        @abstract        Cancels any current requestMediaDataWhenReadyOnQueue:usingBlock: call.
        @discussion        This method may be called from outside the block or from within the block.
    */
    func stopRequestingMediaData()
}



public enum LivePlayerViewMode : Int {
    case none
    case sampleBufferMode
    case AVPlayerMode
}

public protocol LivePlayerViewProtocol : class {
    var mode : LivePlayerViewMode { get set }
    var audioRenderer: LiveRendererProtocol? { get }
    var videoRenderer: LiveRendererProtocol? { get }
    var player : AVPlayer? { get set }
}

public protocol LivePlayerVideoRenderViewControllerPrototype : class {
    func setContentLayer(_ layer:CALayer?)
}

protocol LivePlayerComponent : class {
    func start() -> Bool
    func stop()
}


/**
    LivePlayer
        Manage live playback pipeline
 */
open class LivePlayer {
    var config: LivePlayerConfig
    public weak var delegate: LivePlayerDelegate?
    public weak var delegateQueue: DispatchQueue?
    //public var videoRenderViewController: LivePlayerVideoRenderViewControllerPrototype!
//    internal let videoRenderViewController: LiveVideoRenderViewController
    //var playerView: LivePlayerViewProtocol!
    let playerViewController = LivePlayerViewController()
    
    public init(config:LivePlayerConfig, delegate:LivePlayerDelegate? = nil, delegateQueue:DispatchQueue? = nil) {
        self.config = config
        self.delegate = delegate
        self.delegateQueue = delegateQueue == nil ? DispatchQueue.main : delegateQueue
    }
    
    var streamSource:LiveStreamSource? = nil
    var pipeline:LivePipeline? = nil
    
    func load(fromURL url:String, title:String = "") -> Bool {
        if let streamSource = LiveStreamSource.parse(url: url, title: title) {
            return load(fromSource: streamSource)
        } else {
            return false
        }
    }
    
    private func replacePipeline(pipeline: LivePipeline) {
        if self.pipeline != nil {
            self.pipeline!.stop()
            self.pipeline = nil
        }
        self.pipeline = pipeline
    }
    
    public func load(fromSource source:LiveStreamSource) -> Bool {
        guard source.type != .UNKNOWN else { return false }
        switch source.type {
        case .HTTP_FLV:
            if let pipeline = LiveFLVPipeline(player: self, source: source) {
                replacePipeline(pipeline: pipeline)
                return true
            }
        case .RTMP:
            if let pipeline = LiveRTMPPipeline(player: self, source: source) {
                replacePipeline(pipeline: pipeline)
                return true
            }
        case .HLS:
            if let pipeline = LiveHLSPipeline(player: self, source: source) {
                replacePipeline(pipeline: pipeline)
                return true
            }
        default:
            break
        }
        
        return false
    }
    
    public func unload() {
        if pipeline?.state != .READY &&
            pipeline?.state != .FINISHED {
            pipeline?.stop()
        }
        pipeline = nil
    }

    public func play() -> Bool {
        if !(pipeline?.start() ?? true) {
            print("PLAY FAILED")
        }
        
        return true
    }
    
    public func stop() {
        pipeline?.stop()
    }
    /*
    public func setupVideoWidget(bounds:CGRect, containView: UIView, insertIndex: Int) {
        self.videoRenderViewController.setupWidget(bounds: bounds, containView: containView, insertIndex: insertIndex)
    }
    
    public func removeVideoWidget() {
        self.videoRenderViewController.removeWidget()
    }
    */
    
    public var state: LivePlayerState {
        get {
            if let playerPipeline = self.pipeline {
                return playerPipeline.state
            } else {
                return .READY
            }
        }
    }
    

    
    //let liveVideoRenderViewController = LiveVideoRenderViewController()
    
    
    
    /**
     设置renderer到containView上。
     */
    public func setupVideoWidget(bounds:CGRect, containView: LiveViewType, insertIndex: Int) {
        //self.liveVideoRenderViewController.setupWidget(bounds: bounds, containView: containView, insertIndex: insertIndex)
        self.playerViewController.setupWidget(bounds: bounds, containView: containView, insertIndex: insertIndex)
    }
    
    /**
     移除widget
     */
    public func removeVideoWidget() {
        //self.liveVideoRenderViewController.removeWidget()
        self.playerViewController.removeWidget()
    }
    
    public func test() {
        pipeline?.test()
    }
}
