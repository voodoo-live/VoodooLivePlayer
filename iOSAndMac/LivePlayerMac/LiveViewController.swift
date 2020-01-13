//
//  LiveViewController.swift
//  LivePlayerMac
//
//  Created by voodoo on 2019/12/23.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Cocoa
import VoodooLivePlayer

class LiveViewController: NSViewController, LivePlayerDelegate {
    func handle(stateChangedFrom from: LivePlayerState, to: LivePlayerState) {
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        print("LIVE VIEW LOADED")
        //"rtmp://127.0.0.1:1935/myapp/s1"
        if let rtmpURL = URL(string:"file:///home/test.jpg") {
            print("RTMP URL:", rtmpURL.path,
                  rtmpURL.scheme ?? "<no scheme>", rtmpURL.host ?? "<no host>",
                  rtmpURL.port ?? "<no port>",
                  rtmpURL.pathExtension
            )
        }
        
    }
    
    private var _source: LiveStreamSource?
    private var player: LivePlayer?
    var source: LiveStreamSource? {
        get { return _source }
        set {
            if _source != nil {
                stopPlay()
            }
            _source = newValue
            if _source == nil {
                stopPlay()
            } else {
                if !playSource(source: _source!) {
                    _source = nil
                }
            }
        }
    }

    
    var playResult = false
    private func playSource(source:LiveStreamSource) -> Bool {
        let config = LivePlayerConfig(videoRenderMethod: .AUTO, audioRenderMethod: .AUTO)
        self.player = LivePlayer(config: config, delegate: self, delegateQueue: nil)
        
        if let player = self.player {
            player.setupVideoWidget(bounds: self.view.bounds, containView: self.view, insertIndex: 0)
            self.view.window?.title = source.title
            guard player.load(fromSource: source) else {
                print("LOAD FAIL")
                player.removeVideoWidget()
                self.player = nil
                return false
            }
            print("LOADED")
                
            guard player.play() else {
                player.unload()
                player.removeVideoWidget()
                self.player = nil
                return false
            }
            print("PLAYED")
            return true
        }
        return false
    }
    
    private func stopPlay() {
        if player != nil {
            print("STOP PLAY")
            player?.stop()
            player?.unload()
            player?.removeVideoWidget()
            player = nil
        }
    }
    
    public func stopLivePlayback() {
        print(Date.timeIntervalBetween1970AndReferenceDate + Date.timeIntervalSinceReferenceDate)
        print("stopLivePlayback")
        player?.test()
    }
    
    public func startLivePlayback() {
        
    }
}
