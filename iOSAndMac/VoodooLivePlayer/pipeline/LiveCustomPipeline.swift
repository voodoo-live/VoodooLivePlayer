//
//  LiveCustomPipeline.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/21.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

class LiveCustomPipeline : LivePipeline, LiveLoaderDelegate, LiveDemuxerDelegate, LiveDecoderDelegate {
    private(set) var streamInfo: LiveStreamInfo
    private var _renderSynchronizer: LiveRenderSynchronizer!
    var renderSynchronizer: LiveRenderSynchronizer {
        get {
            if _renderSynchronizer == nil {
                _renderSynchronizer = LiveRenderSynchronizer(videoRenderer: player.playerViewController.videoRenderer, audioRenderer: player.playerViewController.audioRenderer, mode: .AUDIO_TIME)
            }
            return _renderSynchronizer
        }
    }

    override init(player: LivePlayer, streamSource source: LiveStreamSource) {
        self.streamInfo = LiveStreamInfo(source: source)
        super.init(player: player, streamSource: source)
    }
    /**
     loader delegate
     */
    func handle(loaderData data: Data, withType type: LivePipelineDataType) {}
    func handle(loaderError error: Error?) {
        raiseError(error: error)
        if error == nil {
            /**
             reload
             */
            change(state: .READY)
            change(state: .LOADING)
        }
    }
    /**
     demuxer delegate
     */
    func handle(demuxerData data: Data, withType type: LivePipelineDataType, ts: [Int64], flag: UInt32) {
        print("HERE \(type)")
    }
    func handle(demuxerError error: Error?) { raiseError(error: error) }
    /**
     decoder delegate
     */
    func handle(decoder: LiveDecoder, outputFrame frame:LiveFrame) {
        if frame.contentType == .UNKNOWN {
            print("[ERROR] WRONG FRAME CONTENT TYPE...")
            return
        }
        if state != .PLAYING {
            if state != .LOADING {
                print("NOT LOADING STATE, QUIT")
                return
            }
            change(state: .PLAYING)
        }
        self.renderSynchronizer.render(frame: frame)
    }
    func handle(decoder: LiveDecoder, raisedError error:Error?) { raiseError(error: error) }
    

    
    func destroyRenderers() {
        self._renderSynchronizer = nil
    }
    
    override func test() {
        self._renderSynchronizer.test()
    }
}
