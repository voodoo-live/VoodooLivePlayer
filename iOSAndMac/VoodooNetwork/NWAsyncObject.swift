//
//  NWObject.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public enum NWAsyncObjectState : Equatable, Hashable, CustomDebugStringConvertible {
    case setup
    case waiting(NWError)
    case preparing
    case ready
    case failed(NWError)
    case cancelled
    
    public var debugDescription: String { get {
            switch self {
            case .failed(let e):
                return ".failed(\(e))"
            case .setup:
                return ".setup"
            case .waiting(let e):
                return ".waiting(\(e))"
            case .preparing:
                return ".preparing"
            case .ready:
                return ".ready"
            case .cancelled:
                return ".canceled"
            }
        }
    }
    
    public static func == (a:NWAsyncObjectState, b:NWAsyncObjectState) -> Bool {
        switch (a,b) {
        case (.setup, .setup), (.preparing, .preparing), (.ready, .ready), (.cancelled, .cancelled):
            return true
        case let (.failed(e1), .failed(e2))
            where e1 == e2:
            return true
        case let (.waiting(e1), .waiting(e2))
            where e1 == e2:
            return true
        default:
            break
        }
        return false
    }
    
    public var hashValue: Int {
        get {
            var hasher = Hasher()
            self.hash(into: &hasher)
            return hasher.finalize()
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .failed(let e):
            hasher.combine(".failed")
            hasher.combine(e)
        case .waiting(let e):
            hasher.combine(".waiting")
            hasher.combine(e)
        default:
            hasher.combine(self.debugDescription)
        }
    }
}

public protocol NWAsyncObjectProtocol : class {
    var state:NWAsyncObjectState { get }
    var handlerQueue: DispatchQueue? { get set }
    var stateUpdateHandler: ((NWAsyncObjectState) -> Void)? { get set }
    func start(queue:DispatchQueue)
    func cancel()
}

/// NWObject, basic async loop object
public class NWAsyncObject : NWAsyncObjectProtocol {
    
    internal func internalStop() {
        /**
         所有的handler都返回时，激活停止信号
         */
        if self.handlerGroup.wait(timeout: DispatchTime.now() + DispatchTimeInterval.milliseconds(10)) == .success {
            runningSemphore.signal()
            return
        }
        /**
         否则循环等待
         */
        self.queue?.async {
            self.internalStop()
        }
    }
    
    internal func handleStateChange(from: NWAsyncObjectState, to: NWAsyncObjectState) {}
    
    public final internal(set) var state: NWAsyncObjectState = .setup {
        didSet {
            
            if oldValue == state {
                print("REPEAT STATE: \(oldValue), \(state)")
                return
            }
            
            if let handler = stateUpdateHandler {
                let currentState = state
                runHandler {
                    handler(currentState)
                }
            }
            
            switch state {
            case .failed(_):
                self.queue.async {
                    self.state = .cancelled
                }
            case .cancelled:
                internalStop()
            default:
                break
            }
            
            handleStateChange(from: oldValue, to: state)
        }
    }
    
    public final func markFailed(_ error:NWError) {
        if state != .cancelled {
            state = .failed(error)
        } else {
            print("[ERROR] operation failed:", error)
        }
    }
    
    public final private(set) var queue: DispatchQueue!
    public final var stateUpdateHandler: ((NWAsyncObjectState) -> Void)?
    public final var handlerQueue: DispatchQueue?
    
    private final var handlerGroup: DispatchGroup = DispatchGroup()
    private final var runningSemphore = DispatchSemaphore(value: 0)
    
    
    public final func runHandler(_ run:@escaping @convention(block)()->Void) {
        self.handlerGroup.enter()
        let handlerQueue = self.handlerQueue ?? self.queue ?? DispatchQueue.main
        handlerQueue.async {
            run()
            self.handlerGroup.leave()
        }
    }
    
    public final func start(queue: DispatchQueue) {
        self.queue = queue
        queue.async {
            self.state = .waiting(.none)
            if !self.internalStart() {
                self.internalStop()
                return
            }
            
            self.internalLoop()
        }
    }
    
    public final func cancel() {
        queue?.async {
            self.internalCancel()
        }
    }
    
    public final func wait(timeout: DispatchTime) -> Bool {
        return self.runningSemphore.wait(timeout: timeout) == .success
    }
    
    
    func internalStart() -> Bool {true}
    func internalCancel() { self.state = .cancelled }

    func internalLoop() {
        switch state {
        case .cancelled, .failed(_):
            return
        default:
            break
        }
        self.queue?.async {
            self.internalLoop()
        }
    }
}


public class NWAsyncResult<T> {
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

