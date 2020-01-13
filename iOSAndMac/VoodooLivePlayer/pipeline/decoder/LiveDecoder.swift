//
//  LiveDecoder.swift
//  live_player
//
//  Created by voodoo on 2019/12/6.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

protocol LiveDecoderDelegate : class {
    func handle(decoder: LiveDecoder, outputFrame frame:LiveFrame)
    func handle(decoder: LiveDecoder, raisedError error:Error?)
}

class LiveDecoder : LivePlayerComponent {
    weak var delegate: LiveDecoderDelegate?
    unowned var delegateQueue: DispatchQueue?
    init(delegate: LiveDecoderDelegate? = nil, delegateQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.delegateQueue = delegateQueue == nil ? DispatchQueue.main : delegateQueue
    }
    func feed(data:Data, ts:[Int64], flag:UInt32) {}
    func start() -> Bool { false }
    func stop() {}
}
