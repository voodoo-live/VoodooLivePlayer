//
//  ViewController.swift
//  LivePlayeriOS
//
//  Created by voodoo on 2019/12/4.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import UIKit
import VoodooLivePlayer


class LiveViewController: UIViewController {
    var livePlayer:LivePlayer?
    var source: LiveStreamSource!
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    var localTimePoint:Int64 = 0
    
    
    var liveList:LiveListDownloader?
    weak var savedNavigationController: UINavigationController?
    override func viewDidDisappear(_ animated: Bool) {
        if let navigationController = self.savedNavigationController {
            navigationController.hidesBarsOnTap = false
            navigationController.hidesBarsOnSwipe = false
            //navigationController.setNavigationBarHidden(false, animated: false)
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
            self.navigationController?.setNavigationBarHidden(true, animated: false)

            print("RESET NAVIGATION CONTROLLLER")
        }
        livePlayer?.removeVideoWidget()
        livePlayer?.stop()
        livePlayer = nil
    }
    override func viewWillDisappear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        self.savedNavigationController = self.navigationController
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.hidesBarsOnTap = true
        navigationController?.hidesBarsOnSwipe = true
    }

    var navigationBarIsHidden = false
    
    private func hideNavigationBar() {
        navigationBarIsHidden = true
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    private func showNavigationBar() {
        navigationBarIsHidden = false
        self.navigationController?.setNavigationBarHidden(false, animated: true)
    }
    
    
    /*

    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        print("LIVE VIEW TOUCHES BEGAN")
        super.touchesBegan(touches, with: event)
        if navigationBarIsHidden {
            showNavigationBar()
        } else {
            hideNavigationBar()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if !navigationBarIsHidden {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+DispatchTimeInterval.seconds(10)) {
                self.hideNavigationBar()
            }
        }
    }
    */
    @IBAction func tapView(_ sender: Any) {
    }
    
    @IBAction func swipeOut(_ sender: Any) {
        
        //navigationController?.popViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.view.autoresizesSubviews = true
        self.view.backgroundColor = .darkGray
        

        navigationItem.title = self.source?.title
        navigationItem.leftItemsSupplementBackButton = true
        navigationController?.setNavigationBarHidden(true, animated: true)
        /*
        touchViewController = LiveTouchViewController()
        touchViewController.view.frame = self.view.bounds
        touchViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(touchViewController.view)
        */
        let config = LivePlayerConfig(videoRenderMethod: .AUTO, audioRenderMethod: .AUTO)
        livePlayer = LivePlayer(config: config)
        /*
        displayLayer = AVSampleBufferDisplayLayer()
        if let layer = displayLayer {
            layer.frame = self.view.bounds// CGRect(x: 0, y: 400, width: self.view.bounds.width, height: 300)
            layer.videoGravity = AVLayerVideoGravity.resizeAspect
            
            //layer.controlTimebase = CMTimebase(masterClock: .hostTimeClock)
            
            let _CMTimebasePointer = UnsafeMutablePointer<CMTimebase?>.allocate(capacity: 1)
            let status = CMTimebaseCreateWithMasterClock( allocator: kCFAllocatorDefault, masterClock: CMClockGetHostTimeClock(),  timebaseOut: _CMTimebasePointer )
            layer.controlTimebase = _CMTimebasePointer.pointee
            
            if let controlTimeBase = layer.controlTimebase, status == noErr {
                
                //CMTimebaseSetTime(controlTimeBase, time: CMTimeMake(value: 0, timescale: 600));
                CMTimebaseSetRate(controlTimeBase, rate: 0);
                
                //localTimePoint = gettime
            }
            self.view.layer.addSublayer(layer)
        }
        */
        
        livePlayer?.setupVideoWidget(bounds: self.view.bounds, containView: self.view, insertIndex: 0)
        
        
        // Do any additional setup after loading the view.
        //let config = LivePlayerConfig
        //config.videoRenderMethod = .DISPLAY_LAYER_RENDER
        //livePlayer = LivePlayer(config: config, delegate: self)
        
        

        //playXiguaLive()
        
        
        //let xiguaLiveURL = "https://pull-flv-l6.ixigua.com/game/stream-6769346806515239688.flv";
        //let localLiveURL = "http://localhost:10080/live?port=1935&app=myapp&stream=s1";
        
        //playLiveURL(url: "http://localhost:10080/live?port=1935&app=myapp&stream=s1")
        //playXiguaLive()
        
        playLiveSource(source: self.source!)
        
    }
    
    func playXiguaLive() {
        self.liveList = LiveListXiGua(delegate: self)
        self.liveList?.load()
    }
    
    
    func playLiveURL(url:String) {
        if let source = LiveStreamSource.parse(url: url) {
            playLiveSource(source: source)
        }
    }
    
    func playLiveSource(source:LiveStreamSource) {
        //DispatchQueue.global().async {
            if let player = self.livePlayer {
                guard player.load(fromSource: source) else {
                    print("ERROR WHEN LOAD URL")
                    return
                }
                let _ = player.play()
            }
        //}
    }
    
    var localFrameQueue = Array<LiveVideoFrame>()
    var firstPTS:Int64 = VOODOO_NOPTS_VALUE
    var firstTimeStamp:Int64 = 0;
}

extension LiveViewController : LiveListDownloaderDelegate {
    func handle(downloader:LiveListDownloader?,error:Error?) {
        print("LOAD LIVE LIST FAILED - ", error!)
    }
    
    func chooseLiveURL(liveList:Array<LiveListItem>) -> LiveStreamSource? {
        for _ in 0..<liveList.count {
            if let randomItem = liveList.randomElement(),
                let hlsURL = randomItem.hlsUrl,
                let url = URL(string: hlsURL) {
                return LiveStreamSource(title: randomItem.title, url: url, type: .HLS)
            }
        }
        return nil
    }
    
    func handle(downloader:LiveListDownloader?,liveList:Array<LiveListItem>) {
        if let source = chooseLiveURL(liveList: liveList) {
            print("CHOOSE LIVE:", source.url)
            playLiveSource(source: source)
        } else {
            print("NOT CHOOSE LIVE URL")
        }
    }
    

}

extension LiveViewController : LivePlayerDelegate {
    func handle(stateChangedFrom from:LivePlayerState, to:LivePlayerState) {
        
    }
}
