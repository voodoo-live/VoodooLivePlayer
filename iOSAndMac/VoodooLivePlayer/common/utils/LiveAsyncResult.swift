//
//  LiveAsyncAction.swift
//  QLive
//
//  Created by voodoo on 2019/12/28.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public class LiveAsyncResult<T> {
    private(set) var value: T?
    public let dispatchQueue: DispatchQueue
    private var actionSemaphore = DispatchSemaphore(value: 0)
    
    public init(dispatchQueue:DispatchQueue) {
        self.dispatchQueue = dispatchQueue
    }
    
    public func waitResult() -> T? {
        if actionSemaphore.wait(timeout: .distantFuture) == .success {
            return value
        }
        return nil
    }
    
    public func wait(milliseconds:Int) -> Bool {
        actionSemaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.milliseconds(milliseconds)) == .success
    }
    
    public func signal(value:T?) {
        self.value = value
        actionSemaphore.signal()
    }
}
