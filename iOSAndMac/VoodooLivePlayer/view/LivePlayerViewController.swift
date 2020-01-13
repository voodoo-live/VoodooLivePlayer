//
//  LivePlayerViewController.swift
//  live_mac
//
//  Created by voodoo on 2019/12/25.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVKit



class LivePlayerViewController : LivePlayerViewProtocol {
    init(mode: LivePlayerViewMode = .none) {
        self.mode = mode
    }
    
    deinit {
        print("LivePlayerViewController DEINITED")
    }
    
    func initMode() {
        if _mode == .AVPlayerMode {
            initAVPlayerMode()
        } else if _mode == .sampleBufferMode {
            initSampleBufferMode()
        }
    }
    
    func fintMode() {
        if _mode == .AVPlayerMode {
            fintAVPlayerMode()
        } else if _mode == .sampleBufferMode {
            fintSampleBufferMode()
        }
    }
    
    private var playbackViewController: LiveViewControllerType?
    private var _mode: LivePlayerViewMode = .none
    var mode: LivePlayerViewMode {
        get {
            return _mode
        }
        set {
            if _mode != newValue {
                if _mode != .none {
                    fintMode()
                }
                _mode = newValue
                if _mode != .none {
                    initMode()
                }
            }
        }
    }
    
    var audioRenderer: LiveRendererProtocol? {
        get {
            guard _mode == .sampleBufferMode else { return nil }
            return (playbackViewController as? LiveSBPlayerViewController)?.audioRenderer
        }
    }
    var videoRenderer: LiveRendererProtocol? {
        get {
            guard _mode == .sampleBufferMode else { return nil }
            return (playbackViewController as? LiveSBPlayerViewController)?.videoRenderer
        }
    }
    
    private func initSampleBufferMode() {
        playbackViewController = LiveSBPlayerViewController()
        linkPlaybackView()
    }
    
    private func fintSampleBufferMode() {
        unlinkPlaybackView()
        playbackViewController = nil
    }

    var player: AVPlayer? {
        get {
            guard _mode == .AVPlayerMode else { return nil }
            return (playbackViewController as? LiveAVPlayerViewController)?.player
        }
        set {
            guard _mode == .AVPlayerMode else { return }
            (playbackViewController as? LiveAVPlayerViewController)?.player = newValue
        }
    }
    
    private func initAVPlayerMode() {
        playbackViewController = LiveAVPlayerViewController()
        linkPlaybackView()
    }
    
    private func fintAVPlayerMode() {
        unlinkPlaybackView()
        playbackViewController = nil
    }
    


    private var containerView : LiveViewType?
    private var widgetBounds: CGRect = .null
    private var insertIndex: Int = 0
    
    private func unlinkPlaybackView() {
        if let playbackViewController = self.playbackViewController, let _ = self.containerView {
            playbackViewController.view.removeFromSuperview()
        }
    }
    
    private func linkPlaybackView() {
        if let playbackViewController = self.playbackViewController, let containerView = self.containerView {
            playbackViewController.view.frame = containerView.bounds
            containerView.autoresizesSubviews = true
            #if os(OSX)
            playbackViewController.view.autoresizingMask = [.width, .height]
            
            var relativeView: NSView? = nil
            var positioned: NSWindow.OrderingMode = .above
            if insertIndex < containerView.subviews.count {
                relativeView = containerView.subviews[insertIndex]
                positioned = .below
            }
            containerView.addSubview(playbackViewController.view, positioned: positioned, relativeTo: relativeView)
            #elseif os(iOS)
            playbackViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.insertSubview(playbackViewController.view, at: insertIndex)
            #endif
            
        }
    }

    /**
     设置renderer到containView上。
     */
    func setupWidget(bounds:CGRect, containView: LiveViewType, insertIndex: Int) {
        print("SETUP WIDGET")
        if self.containerView != nil {
            unlinkPlaybackView()
        }
        self.containerView = containView
        self.widgetBounds = bounds
        self.insertIndex = insertIndex
        linkPlaybackView()
    }
    
    /**
     移除widget
     */
    func removeWidget() {
        print("REMOVE WIDGET")
        if self.containerView != nil {
            unlinkPlaybackView()
            self.containerView = nil
        }
    }

}
