//
//  LiveRenderSynchronizer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia

/**
 LiveRenderSynchronizer is used to synchronize audio and video playback.
 */
class LiveRenderSynchronizer : LivePlayerComponent {
    private weak var videoRenderer: LiveRendererProtocol?
    private weak var audioRenderer: LiveRendererProtocol?
    
    let dispatchQueue = DispatchQueue(label:"com.voodoo.liveplayer.render_queue")
    
    enum Mode {
        case NONE
        case AUDIO_TIME
        case TIMER
    }

    let mode: Mode

    let timer: LiveTimer? = LiveTimer(label:"LiveRenderSynchronizer")
    
    init(videoRenderer: LiveRendererProtocol?, audioRenderer: LiveRendererProtocol?, mode: Mode = .AUDIO_TIME) {
        self.mode = mode
        self.videoRenderer = videoRenderer
        self.audioRenderer = audioRenderer
        
        
        
    }
    
    private func formatTime(_ time:CMTime) -> String {
        return String(format:"%.4f", time.seconds)
    }
    

    private var videoFrameReferencePTS: Int64 = VOODOO_NOPTS_VALUE
    private var videoFrameReferenceTimeStamp: CMTime = .invalid
    private func correctVideoFrameTimeStamp(_ frame: LiveFrame) {
        if self.videoFrameReferenceTimeStamp == .invalid {
            self.videoFrameReferencePTS = frame.pts
            self.videoFrameReferenceTimeStamp = CMTimeMake(value: 0, timescale: Constants.VIDEO_TIME_SCALE)
        }
        let newTimeStamp = self.videoFrameReferenceTimeStamp + CMTimeMake(value: frame.pts - self.videoFrameReferencePTS, timescale: Constants.VIDEO_TIME_SCALE)
        CMSampleBufferSetOutputPresentationTimeStamp(frame.sampleBuffer!, newValue: newTimeStamp)
    }
    
    private var lastVideoFrameTimeStamp: CMTime = .invalid
    private var lastVideoKeyFrameTimeStamp: CMTime = .invalid

    private var renderVideoFrameCount = 0
    private func renderVideoFrame(_ frame: LiveFrame) {
        if let videoRenderer = self.videoRenderer, let sampleBuffer = frame.sampleBuffer {
            if testFunctionOn {
                if renderVideoFrameCount >= testFrameControlCount {
                    return
                }
                if !frame.keyFrame {
                    return
                }
            }
            //let rendererTime = videoRenderer.time
            /**
             step 1: correct time stamp
             */
            correctVideoFrameTimeStamp(frame)
            lastVideoFrameTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
            if frame.keyFrame {
                lastVideoKeyFrameTimeStamp = lastVideoFrameTimeStamp
                /**
                 0帧时，打开计时器
                 */
                if renderVideoFrameCount == 0 {
                    timer?.setRate(1, andTime: .zero)
                }
                //print("KEY FRAME \(renderVideoFrameCount) RENDER TIME:", formatTime(rendererTime), "FRAME TIME:", formatTime(lastVideoFrameTimeStamp), "CACHE DURATION:", formatTime((lastVideoFrameTimeStamp - rendererTime)))
            }
            
            
            /**
             step 2: enqueue frame buffer
             */
            videoRenderer.enqueue(sampleBuffer)
            
            /**
             step 3: calc cache duration
             */
            //let cacheDuration = (lastVideoFrameTimeStamp - rendererTime).seconds
            /*
            if cacheDuration < 0 ||
                cacheDuration >= 5 {
                print("KEY FRAME \(renderVideoFrameCount) RENDER TIME:", formatTime(rendererTime), "FRAME TIME:", formatTime(lastVideoFrameTimeStamp), "CACHE DURATION:", formatTime((lastVideoFrameTimeStamp - rendererTime)))
            }
            */
            /**
             step 4: update cache state change
             */
            //updateCacheState(cacheDuration: cacheDuration)
            if frame.keyFrame {
                //let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
                //print("DURATION is ", formatTime(duration))
                //checkCacheHealth()
                
            }
            updateCacheState()
            renderVideoFrameCount += 1
        }
    }
    
    private enum CacheState: Int {
        case `init` = 0
        case grow = 1
        case balance = 2
        case reduce = 3
    }
    
    private var cacheState: CacheState = .`init`
    
    private var initStateCount = 1
    private var growStateCount = 0
    private let initStateFactor = 4.0
    private let growStateFactor = 2.0
    
    private let initUpperBound = 0.8
    private let growUpperBound = 1.5
    private let growLowerBound = 0.1
    private let balanceUpperBound = 5.0
    private let balanceLowerBound = 0.5
    private let reduceLowerBound = 1.5

    private let CacheStatePlayRate = [0.0, 0.8, 1.0, 1.5]
    private var balanceDownSizeCountTime:CMTime = .zero
    private let balanceDownSizeCountInterval:CMTime = CMTimeMake(value: Int64(5*Constants.VIDEO_TIME_SCALE), timescale: Constants.VIDEO_TIME_SCALE)
    private func updateCacheState() {
        /**
         fixed: plus 30fps frame duration
         */
        let nowReferenceTime = timer?.time ?? .zero
        let cacheDuration = lastVideoFrameTimeStamp.seconds - videoRenderer!.time.seconds + (1.0/30)
        let oldCacheState = cacheState
    
        switch cacheState {
        case .`init`:
            if cacheDuration >= initUpperBound {
                cacheState = .balance
            }
        case .grow:
            if cacheDuration <= growLowerBound {
                cacheState = .`init`
            } else if cacheDuration >= growUpperBound {
                cacheState = .balance
            }
        case .balance:
            let upperBound = balanceUpperBound + initStateFactor * Double(initStateCount) + growStateFactor * Double(growStateCount)
            if cacheDuration <= growLowerBound {
                cacheState = .`init`
            } else if cacheDuration <= balanceLowerBound {
                cacheState = .grow
            } else if cacheDuration >= upperBound {
                if initStateCount > 0 {
                    initStateCount -= 1
                }
                if growStateCount > 0 {
                    growStateCount -= 1
                }
                cacheState = .reduce
            }
        case .reduce:
            let lowerBound = reduceLowerBound + (initStateFactor * Double(initStateCount) + growStateFactor * Double(growStateCount))/2
            if cacheDuration <= lowerBound {
                cacheState = .balance
            }
        //default:
        //    break
        }
 
        
        if oldCacheState != cacheState {
            print("CACHE STATE CHANGED FROM \(oldCacheState) TO \(cacheState) ..", String(format:"%.4f", cacheDuration))
            
            
            if cacheState == .`init` {
                initStateCount += 1
            } else if cacheState == .grow {
                growStateCount += 1
            } else if cacheState == .balance {
                balanceDownSizeCountTime = nowReferenceTime
            }
            
            let statePlayRate = CacheStatePlayRate[cacheState.rawValue]
            self.setRate(statePlayRate)
        } else {
            if cacheState == .balance {
                if (growStateCount > 0 || initStateCount > 0) &&
                    nowReferenceTime - balanceDownSizeCountTime >= balanceDownSizeCountInterval {
                    balanceDownSizeCountTime = balanceDownSizeCountTime + balanceDownSizeCountInterval
                    print("DOWN SIZE COUNT - ", formatTime(balanceDownSizeCountTime))
                    if growStateCount > 0 { growStateCount -= 1 }
                    if initStateCount > 0 { initStateCount -= 1 }
                }
            }
        }
    }
    

    private var videoIsWaitingAudio = false
    private var nowRate: Double = 0
    private func setRate(_ rate:Double) {
        //print("SET RATE:", rate)
        nowRate = rate
        audioRenderer?.rate = rate
        videoRenderer?.rate = rate * (videoIsWaitingAudio ? 0.5 : 1.0)
    }
    
    private func setRate(_ rate:Double, andTime time: CMTime) {
        //print("SET RATE:", rate, "AND TIME:", String(format:"%.4f", time.seconds))
        nowRate = rate
        audioRenderer?.setRate(rate, andTime: time)
        videoRenderer?.setRate(rate * (videoIsWaitingAudio ? 0.5 : 1.0), andTime: time)
    }

    private var audioFrameReferencePTS:Int64 = VOODOO_NOPTS_VALUE
    private var audioFrameReferenceTimeStamp:CMTime = .invalid
    private var lastAudioFrameTimeStamp:CMTime = .invalid
    
    
    private func calcCorrectVideoTimeStamp() -> CMTime {
        let ptsDist = audioFrameReferencePTS - videoFrameReferencePTS
        let audioTime = audioRenderer!.time
        
        return (audioTime + CMTimeMake(value: ptsDist, timescale: 1000))
    }
    
    
    private func renderAudioFrame(_ frame: LiveFrame) {
        
        if audioFrameReferencePTS == VOODOO_NOPTS_VALUE {
            audioFrameReferencePTS = frame.pts
            audioFrameReferenceTimeStamp = CMTimeMake(value: 0, timescale: 1000)
        }
        
        lastAudioFrameTimeStamp = CMSampleBufferGetOutputPresentationTimeStamp(frame.sampleBuffer!)
        
        audioRenderer?.enqueue(frame.sampleBuffer!)
        //let audioCurrentTime = audioRenderer!.time
        
        //print("AUDIO TIME:", formatTime(audioCurrentTime), "FRAME TIME:", formatTime(lastAudioFrameTimeStamp))
        
    }
    
    private func synchronizeVideoFromAudio() {
        if let audioCurrentTime = audioRenderer?.time, let videoCurrentTime = videoRenderer?.time {
            let diff = audioCurrentTime.seconds - videoCurrentTime.seconds
            if abs(diff) >= 0.05 {
                
                
                //let videoCorrectTime = calcCorrectVideoTimeStamp()
                
                //print("AUDIO TIME:", String(format:"%.4f", audioCurrentTime.seconds),
                //      "VIDEO TIME:", String(format:"%.4f", videoCurrentTime.seconds),
                //      "VIDEO CORRECT TIME:", String(format:"%.4f", videoCorrectTime.seconds))
                
                /*
                 sync video time with audio time
                 todo: use audio reference time to calc correct video time
                 */
                if videoCurrentTime > audioCurrentTime {
                    if !videoIsWaitingAudio {
                        print("VIDEO WAIT:", nowRate)
                        videoIsWaitingAudio = true
                        setRate(nowRate)
                    }
                } else {
                    if videoIsWaitingAudio {
                        print("VIDEO RECOVER:", nowRate)
                        videoIsWaitingAudio = false
                        setRate(nowRate)
                    }
                    videoRenderer?.time = audioCurrentTime
                    print("sync video time with", String(format:"%.4f", audioCurrentTime.seconds),"for diff:", String(format:"%.4f", diff))
                }
            }
        }


    }
    
    private func internalRender(frame: LiveFrame) {
        if frame.contentType == .AUDIO {
            renderAudioFrame(frame)
        } else if frame.contentType == .VIDEO {
            renderVideoFrame(frame)
        }
    }
    
    func render(frame:LiveFrame) {
        dispatchQueue.async {
            self.internalRender(frame: frame)
        }
    }
        
    private func internalStart() -> Bool {
        if cacheState != .`init` {
            return false
        }
        
        if videoRenderer == nil ||
            audioRenderer == nil {
            return false
        }

        return true
    }
    var started = false
    func start() -> Bool {
        let sem = DispatchSemaphore(value: 0)
        dispatchQueue.sync {
            started = internalStart()
            sem.signal()
        }
        let _ = sem.wait(timeout: .distantFuture)
        return started
    }
    
    func stop() {
        dispatchQueue.sync {
            videoRenderer?.rate = 0
            videoRenderer?.flush()
            audioRenderer?.rate = 0
            audioRenderer?.flush()
            self.cacheState = .`init`
        }
        print("[STOP] RENDER SYNCHRONIZER")
    }
    
    private var testFrameControlCount = 1
    private var testFunctionOn = false
    func test() {
        dispatchQueue.async {
            print("audio rate:", self.audioRenderer!.rate)
            print("video rate:", self.videoRenderer!.rate)
        }
        if testFunctionOn {
            dispatchQueue.async {
                self.videoRenderer?.rate = 0.5
                self.testFrameControlCount += 1
                print("CONTROL COUNT:", self.testFrameControlCount)
            }
        }
    }
}

