//
//  LivePlayerHLSPipeline.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/21.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVKit

class LiveHLSPipeline : LivePipeline {
    let hlsPlayer: AVPlayer
    init?(player: LivePlayer, source: LiveStreamSource) {
        if source.type == .HLS {
            player.playerViewController.mode = .AVPlayerMode
            hlsPlayer = AVPlayer(url: source.url)
        } else {
            return nil
        }
        super.init(player: player, streamSource: source)
    }
    
    override func start() -> Bool {
        player?.playerViewController.player = hlsPlayer
        hlsPlayer.play()
        return true
    }
    
    override func stop() {
        hlsPlayer.rate = 0
        hlsPlayer.replaceCurrentItem(with: nil)
        player.playerViewController.player = nil
    }
}
