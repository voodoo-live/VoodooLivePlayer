//
//  PipeLineController.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/9.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import VideoToolbox


enum LivePipelineDataType : Int {
    case rawData = 0
    case streamConfig = 1
    case videoParameters = 2
    case videoPacket = 3
    case audioParameters = 4
    case audioPacket = 5
}

enum LivePipelineData {
    case rawData(Data)
    case streamConfig(UInt32)
    case videoParameters(Data, UInt32)
    case videoPacket(Data, Int64)
    case audioParameters(Data, UInt32)
    case audioPacket(Data, Int64)
    case videoFrame(LiveFrame)
    case audioFrame(LiveFrame)
}


/**
 Pipeline is used to control downloading, decoding and caching
 */
class LivePipeline : LivePlayerComponent {
    internal weak var player: LivePlayer!
    private(set) var source: LiveStreamSource
    private(set) var state: LivePlayerState = .READY
    private(set) var error: Error? = nil

    init(player:LivePlayer, streamSource source:LiveStreamSource) {
        self.player = player
        self.source = source
    }
    
    internal func change(state:LivePlayerState) {
        if state == self.state { return }
        let fromState = self.state
        var toState = state
        if toState != .ERROR {
            let result = self.handle(stateWillChangeFrom: fromState, to: toState)
            if result == .REJECT {
                print("PIPELINE STATUS WILL CHANGE FROM \(fromState) TO \(toState) REJECTED")
                return
            } else if result == .ERROR {
                toState = .ERROR
            }
        }
        self.state = toState
        self.handle(stateChangedFrom: fromState, to: toState)
        if toState == .ERROR {
            print("ERROR!!!")
        }
        print("PIPELINE STATUS CHANGED FROM \(fromState) TO \(toState)")
    }
    
    internal func raiseError(error:Error?) {
        self.error = error
        change(state: .ERROR)
    }
    
    enum StateChangeResult {
        case SUCCESS
        case REJECT
        case ERROR
    }
    
    func handle(stateWillChangeFrom from: LivePlayerState, to: LivePlayerState) -> StateChangeResult { .SUCCESS }
    func handle(stateChangedFrom from: LivePlayerState, to: LivePlayerState) {
        if player?.delegate != nil {
            player?.delegateQueue?.async {
                self.player?.delegate?.handle(stateChangedFrom: from, to: to)
            }
        }
    }
    func start() -> Bool { false }
    func stop() {}
    
    func reset() { change(state: .READY) }
    
    
    func test() {}
}
