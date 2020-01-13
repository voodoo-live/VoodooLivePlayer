//
//  LiveAVPlayerViewController.swift
//  live_mac
//
//  Created by voodoo on 2019/12/25.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVKit


#if os(OSX)

class LiveAVPlayerViewController : LiveViewControllerType {
    override func loadView() {
        self.view = AVPlayerView()
    }
    
    var player: AVPlayer? {
        get { return (self.view as! AVPlayerView).player }
        set { (self.view as! AVPlayerView).player = newValue }
    }
}
#else
typealias LiveAVPlayerViewController = AVPlayerViewController
#endif
