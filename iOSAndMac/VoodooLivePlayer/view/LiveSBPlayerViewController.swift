//
//  LiveSBPlayerView.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/25.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import AVKit

private class LiveSBPlayerView : LiveViewType {
    #if os(OSX)
    override func makeBackingLayer() -> CALayer {
        print("MAKING BACKING LAYER")
        let layer = AVSampleBufferDisplayLayer()
        return layer
    }
    #elseif os(iOS)
    override class var layerClass: AnyClass {
        get { return AVSampleBufferDisplayLayer.self }
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        print("HIT TEST!")
        return nil
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return false
    }
    #endif
    

}

class LiveSBPlayerViewController : LiveViewControllerType {
    private weak var displayLayer: AVSampleBufferDisplayLayer?
    
    private func setDisplayLayer(_ displayLayer:AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        if self.displayLayer != nil &&
            self.displayLayer?.controlTimebase == nil {
            //print("SETUP VIDEO TIMEBASE TO AUDIO TIMEBASE")
            //self.displayLayer?.controlTimebase = audioRenderer.controlTimebase
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if self.displayLayer == nil {
            print("viewDidLoad SET DISPLAY LAYER")
            setDisplayLayer(self.view.layer as! AVSampleBufferDisplayLayer)
        }
    }
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print(">>>> TOUCHES BEGIN!")
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        print(">>>> TOUCHES END!")
    }
    #endif
    override func loadView() {
        print("SB PLAYER VIEW LOADING")
        self.view = LiveSBPlayerView()
        #if os(OSX)
        self.view.wantsLayer = true
        #endif
        setDisplayLayer(self.view.layer as! AVSampleBufferDisplayLayer)
    }
    
    deinit {
        audioRenderer.rate = 0
        audioRenderer.flushAndRemoveImage()
        videoRenderer.rate = 0
        videoRenderer.flushAndRemoveImage()
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    lazy private(set) var audioRenderer: LiveRendererProtocol = {
        if #available(OSX 10.13, iOS 11.0, *) {
            return LiveSBAudioRenderer()
        } else {
            return LiveSBAudioRendererNull()
        }
    }()
    lazy var videoRenderer: LiveSBVideoRenderer = {
        let masterClock: CMClock
        if #available(iOS 9.0, *) {
            masterClock = CMTimebaseCopyMasterClock(self.audioRenderer.controlTimebase!) ?? CMClockGetHostTimeClock()
        } else {
            // Fallback on earlier versions
            masterClock = CMTimebaseGetMasterClock(self.audioRenderer.controlTimebase!) ?? CMClockGetHostTimeClock()
        }
        
        if self.displayLayer == nil {
            return LiveSBVideoRenderer(displayLayer: AVSampleBufferDisplayLayer(), masterClock: masterClock)
        }
        
        return LiveSBVideoRenderer(displayLayer: self.displayLayer!, masterClock: masterClock)
    }()
}
