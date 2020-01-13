//
//  PlayerFLVPipeline.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/9.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VideoToolbox

class LiveFLVPipeline : LiveCustomPipeline {
    var loader:LiveLoaderProtocol
    var demuxer:LiveDemuxer
    
    var videoDecoder:LiveVideoDecoder?
    var audioDecoder:LiveAudioDecoder?
    
    let dispatchQueue = DispatchQueue(label: "VoodooLivePlayer.LivePlayerFLVPipeline.queue")

    init?(player: LivePlayer, source:LiveStreamSource) {
        if source.type != .HTTP_FLV { return nil }
        player.playerViewController.mode = .sampleBufferMode
        self.loader = LiveFLVLoader(source: source)
        self.demuxer = LiveFLVDemuxer()
        super.init(player: player, streamSource: source)
        //self.player.playerView.mode = .sampleBufferMode
        loader.delegate = self
        loader.delegateQueue = dispatchQueue
        demuxer.delegate = self
        demuxer.delegateQueue = dispatchQueue
    }
    
    override func start() -> Bool {
        dispatchQueue.async {
            guard self.state == .READY else { return }
            self.change(state: .LOADING)
            /*if self.loader.start() {
                print("LOADING...")
            } else {
                self.raiseError(error: nil)
            }*/
        }
        return true
    }
    
    override func stop() {
        let stopSemaphore = DispatchSemaphore(value: 0)
        dispatchQueue.async {
            if self.state == .LOADING {
                self.change(state: .READY)
            } else if self.state == .PLAYING {
                self.change(state: .FINISHED)
            }
            stopSemaphore.signal()
        }
        _ = stopSemaphore.wait(timeout: .distantFuture)
        print("STOPED")
    }
    
    private func stopAll() {
        super.renderSynchronizer.stop()
        self.loader.stop()
        self.demuxer.stop()
        self.audioDecoder?.stop()
        self.videoDecoder?.stop()
    }
    
    override func handle(stateWillChangeFrom from: LivePlayerState, to: LivePlayerState) -> StateChangeResult {
        if to == .PLAYING {
            guard super.renderSynchronizer.start() else { return .ERROR }
            return .SUCCESS
        } else if to == .LOADING {
            /*
             first start demuxer
             */
            guard demuxer.start() else { return .REJECT }
            /*
             second start loader
             */
            guard loader.start() else {
                demuxer.stop()
                return .REJECT
            }

            return .SUCCESS
        }
        return .SUCCESS
    }
    
    override func handle(stateChangedFrom from: LivePlayerState, to: LivePlayerState) {
        if to == .ERROR || to == .FINISHED || to == .READY {
            if from == .LOADING {
                self.loader.stop()
            } else if from == .PLAYING {
                self.stopAll()
            }
        } else if to == .PLAYING {
            
        }
        
        super.handle(stateChangedFrom: from, to: to)
    }
    
    override func handle(loaderData data: Data, withType type: LivePipelineDataType) {
        demuxer.feed(data: data)
    }
    
    override func handle(demuxerData data: Data, withType type: LivePipelineDataType, ts: [Int64], flag: UInt32) {
        switch type {
        case .streamConfig:
            handle(mediaFlag: flag)
        case .audioParameters:
            handle(audioParameters: data, flag: flag)
            checkDecoder()
        case .audioPacket:
            handle(audioPacket: data, ts: ts, flag: flag)
        case .videoParameters:
            handle(videoParameters: data, flag: flag)
            checkDecoder()
        case .videoPacket:
            handle(videoPacket: data, ts: ts, flag: flag)
        default:
            break
        }
    }
    var renderersCreated = false
    private func checkDecoder() {
        /*
        let audioChecked = streamInfo.hasAudioStream ? self.audioDecoder != nil : true
        let videoChecked = streamInfo.hasVideoStream ? self.videoDecoder != nil : true
        
        if audioChecked && videoChecked {
            if !createRenderers() {
                raiseError(error: PipelineErrors.create_renderers_failed)
            } else {
                renderersCreated = true
                print("RENDERERS CREATE OK")
            }
        } */
    }
    
    private func handle(mediaFlag flag: UInt32) {
        streamInfo.hasVideoStream = (flag & 1) == 1
        streamInfo.hasAudioStream = (flag & 4) == 4
        /*
         override hasVideoStream from config
         */
        if streamInfo.hasVideoStream && player?.config.videoRenderMethod == .NOT_RENDER {
            streamInfo.hasVideoStream = false
        }
        /*
         override hasAudioStream from config
         */
        if streamInfo.hasAudioStream && player?.config.audioRenderMethod == .NOT_RENDER {
            streamInfo.hasAudioStream = false
        }
    }
    private func handle(audioParameters parameters: Data, flag: UInt32) {
        guard self.streamInfo.hasAudioStream else { return }
        
        self.streamInfo.audioStreamInfo = AACFormatHelper.audioStreamInfo(fromAudioSpecificConfigRawData: parameters)
        if self.streamInfo.audioStreamInfo == nil {
            self.streamInfo.hasAudioStream = false
            return
        }
        
        self.audioDecoder = LiveSampleBufferAudioDecoder(streamInfo: self.streamInfo.audioStreamInfo!, delegate: self, delegateQueue: dispatchQueue)
        if self.audioDecoder == nil {
            self.streamInfo.hasAudioStream = false
            return
        }
    }
    
    private func handle(audioPacket packet: Data, ts: [Int64], flag: UInt32) {
        guard self.streamInfo.hasAudioStream else { return }
        self.audioDecoder!.feed(data: packet, ts: ts, flag: flag)
    }
    
    private func handle(videoParameters parameters: Data, flag: UInt32) {
        guard self.streamInfo.hasVideoStream else { return }
        if let codecID = LiveVideoStreamInfo.CodecID(rawValue: Int(flag)) {
            self.streamInfo.videoStreamInfo = VideoFormatHelper.videoStreamInfo(fromParameters: parameters, withCodecID: codecID)
        } else {
            self.streamInfo.videoStreamInfo = nil
        }
        
        if self.streamInfo.videoStreamInfo == nil {
            self.streamInfo.hasVideoStream = false
            return
        }
        
        self.videoDecoder = LiveSampleBufferVideoDecoder(streamInfo: self.streamInfo.videoStreamInfo!, delegate: self, delegateQueue: dispatchQueue)
    }
    
    private func handle(videoPacket packet: Data, ts: [Int64], flag: UInt32) {
        guard self.streamInfo.hasVideoStream else { return }
        self.videoDecoder?.feed(data: packet, ts: ts, flag: flag)
    }
    
    
}


