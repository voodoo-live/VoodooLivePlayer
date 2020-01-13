//
//  LiveRenderer.swift
//  live_player
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia


class LiveRenderer : NSObject, LivePlayerComponent {
    var currentRate: Double { get { return 0 } }
    var currentTime: CMTime { get { return .invalid } }
    
    func setRate(rate: Double) {}
    func setTime(time: CMTime) {}
    func setRate(_ rate: Double, andTime time: CMTime) {}
    
    func render(frame:LiveFrame) {}
    func start() -> Bool { true }
    func stop() {}
    func synchronize(time: CMTime) -> Bool { true }
}

