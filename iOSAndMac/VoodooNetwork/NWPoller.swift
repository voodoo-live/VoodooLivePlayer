//
//  NWPoller.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation


internal protocol NWPollable : class {
    var ident: UInt { get }
    func handleWrite(_ len:Int)
    func handleRead(_ len:Int)
    func handleEOF(_ error:Int32)
}

internal class NWPoller : NWAsyncObject, NWPollable {
    var ident: UInt { get { UInt(kq) }}
    func handleWrite(_ len: Int) {}
    func handleRead(_ len: Int) {}
    func handleEOF(_ error: Int32) {}
    
    private static weak var _shared: NWPoller?
    static var shared: NWPoller? {
        get {
            if _shared == nil {
                let created = NWPoller(Int(1024))
                _shared = created
                return created
            }
            return _shared
        }
    }
    
    private let kq: Int32
    private var events:[Darwin.kevent]
    private let kqDispatchQueue = DispatchQueue(label: "mininetwork.nwpoller.queue")
    init?(_ maxEvents:Int) {
        kq = kqueue()
        if kq < 0 {
            return nil
        }
        self.events = [Darwin.kevent](repeating: Darwin.kevent(), count: maxEvents)
    }
    
    deinit {
        if kq >= 0 {
            close(kq)
        }
    }
    
    override func internalLoop() {
        self.poll()
        super.internalLoop()
    }
    
    private static let POLL_TIME = timespec(tv_sec: 0, tv_nsec: 1000000)
    private func poll() {
        /**
         empty dict means no events
         */
        if objectDict.count == 0 {
            internalCheckStop()
            return
        }
        
        var pollTime = NWPoller.POLL_TIME
        let keventRet = kevent(self.kq, nil, 0, &self.events, Int32(self.events.count), &pollTime)
        if keventRet < 0 {
            return
        }
        
        for i in 0..<Int(keventRet) {
            dealWithEvent(event: &self.events[i])
        }
    }
    
    private func dealWithEvent(event:inout Darwin.kevent) {
        if let objectData = objectDict[event.ident] {
            if let object = objectData.object {
                if (event.flags & UInt16(EV_EOF)) != 0 {
                    //print("EOF:", event.fflags)
                    internalRemoveObjectData(event.ident)
                    let errorCode = Int32(event.fflags)
                    object.handleEOF(errorCode)
                } else if event.filter == EVFILT_READ {
                    let dataLen = event.data
                    //print("READ:", dataLen)
                    object.handleRead(dataLen)
                } else if event.filter == EVFILT_WRITE {
                    let dataLen = event.data
                    //print("WRITE:", dataLen)
                    object.handleWrite(dataLen)
                } else {
                    print("[ERROR] NWPOLLER INVALID FILTER \(event.filter) OF IDENT \(event.ident)")
                }
            } else {
                internalRemoveObjectData(event.ident)
            }
        }
    }
    
    
    override func internalStart() -> Bool {
        state = .ready
        return true
    }
    private func internalCheckStart() {
        if self.state != .ready {
            print("START POLLER")
            start(queue: self.kqDispatchQueue)
        }
    }
    
    private func internalCheckStop() {
        if self.state == .ready {
            print("STOP POLLER")
            cancel()
        }
    }
    
    class PollableData {
        weak var object: NWPollable?
        let ident: UInt
        var read: Bool = false
        var write: Bool = false
        
        init(_ object:NWPollable) {
            self.object = object
            self.ident = object.ident
        }
    }
    
    private var objectDict:Dictionary = Dictionary<UInt, PollableData>()
    
    
    private func internalAddEvent(_ ident: UInt, filter: Int16, flags: UInt16, udata: UnsafeMutableRawPointer? = nil) -> Bool {
        let eventflags:UInt16 = UInt16(EV_ADD) | flags | UInt16(EV_RECEIPT)
        var event = Darwin.kevent(ident: ident, filter: filter, flags: eventflags, fflags: 0, data: 0, udata: udata)
        let ret = withUnsafeMutablePointer(to: &event) { (ptr) -> Int32 in
            let keventRet = kevent(self.kq, ptr, 1, ptr, 1, nil)
            if keventRet != 1 {
                print("[ERROR] kevent not returned event when EV_RECEIPT set")
                return -1
            }
            
            if ptr.pointee.data != 0 {
                print("[ERROR] kevent add event met a error:", ptr.pointee.data, String(cString: strerror(Int32(ptr.pointee.data))))
                return -1
            }
            
            return 0
        }
        
        return (ret == 0)
    }
    
    private func internalRemoveEvent(_ ident: UInt, filter: Int16) {
        let eventflags:UInt16 = UInt16(EV_DELETE)
        var event = Darwin.kevent(ident: ident, filter: filter, flags: eventflags, fflags: 0, data: 0, udata: nil)
        let _ = withUnsafePointer(to: &event) { (ptr) -> Int32 in
            return kevent(self.kq, ptr, 1, nil, 0, nil)
        }
    }
    
    private func internalGetObjectData(_ object:NWPollable) -> PollableData {
        var objectData = objectDict[object.ident]
        if objectData == nil {
            objectData = PollableData(object)
            objectDict[object.ident] = objectData
        } else if objectData!.object == nil ||
            ObjectIdentifier(objectData!.object!) != ObjectIdentifier(object) {
            /**
             todo: remove old ident, object events
             */
            if objectData!.read {
                internalRemoveEvent(objectData!.ident, filter: Int16(EVFILT_READ))
                objectData!.read = false
            }
            if objectData!.write {
                internalRemoveEvent(objectData!.ident, filter: Int16(EVFILT_WRITE))
                objectData!.write = false
            }
            objectData!.object = object
        }
        return objectData!
    }
    
    private func internalRemoveObjectData(_ ident: UInt) {
        if let objectData = objectDict[ident] {
            if objectData.read {
                internalRemoveEvent(ident, filter: Int16(EVFILT_READ))
                objectData.read = false
            }
            if objectData.write {
                internalRemoveEvent(ident, filter: Int16(EVFILT_WRITE))
                objectData.write = false
            }
            objectDict.removeValue(forKey: ident)
        }
    }
    
    private func internalAddReadWriteEvent(_ object:NWPollable, oneShot:Bool = false, clear:Bool = false) -> Bool {
        let objectData = internalGetObjectData(object)
        objectData.read = internalAddEvent(object.ident, filter: Int16(EVFILT_READ), flags: UInt16(oneShot ? EV_ONESHOT : 0)|UInt16(clear ? EV_CLEAR : 0))
        objectData.write = internalAddEvent(object.ident, filter: Int16(EVFILT_WRITE), flags: UInt16(oneShot ? EV_ONESHOT : 0)|UInt16(clear ? EV_CLEAR : 0))
        if !objectData.read ||
            !objectData.write {
            if objectData.read {
                internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_READ))
                objectData.read = false
            } else if objectData.write {
                internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_WRITE))
                objectData.write = false
            }
            objectDict.removeValue(forKey: object.ident)
            return false
        }
        internalCheckStart()
        return true
    }
    
    private func internalAddReadEvent(_ object:NWPollable, oneShot:Bool = false, clear:Bool = false) -> Bool {
        let objectData = internalGetObjectData(object)
        objectData.read = internalAddEvent(object.ident, filter: Int16(EVFILT_READ), flags: UInt16(oneShot ? EV_ONESHOT : 0)|UInt16(clear ? EV_CLEAR : 0))
        if !objectData.read {
            if !objectData.write {
                objectDict.removeValue(forKey: object.ident)
            }
            return false
        }
        internalCheckStart()
        return true
    }
    private func internalAddWriteEvent(_ object:NWPollable, oneShot:Bool = false, clear:Bool = false) -> Bool {
        let objectData = internalGetObjectData(object)
        objectData.write = internalAddEvent(object.ident, filter: Int16(EVFILT_WRITE), flags: UInt16(oneShot ? EV_ONESHOT : 0)|UInt16(clear ? EV_CLEAR : 0))
        if !objectData.write {
            if !objectData.read {
                objectDict.removeValue(forKey: object.ident)
            }
            return false
        }
        internalCheckStart()
        return true
    }
    
    private func internalRemoveReadWriteEvent(_ object:NWPollable) {
        let objectData = internalGetObjectData(object)
        if objectData.read {
            internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_READ))
            objectData.read = false
        }
        if objectData.write {
            internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_WRITE))
            objectData.write = false
        }
        objectDict.removeValue(forKey: object.ident)
    }
    private func internalRemoveReadEvent(_ object:NWPollable) {
        let objectData = internalGetObjectData(object)
        if objectData.read {
            internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_READ))
            objectData.read = false
        }
        if !objectData.write {
            objectDict.removeValue(forKey: object.ident)
        }
    }
    private func internalRemoveWriteEvent(_ object:NWPollable) {
        let objectData = internalGetObjectData(object)
        if objectData.write {
            internalRemoveEvent(objectData.ident, filter: Int16(EVFILT_WRITE))
            objectData.write = false
        }
        if !objectData.read {
            objectDict.removeValue(forKey: object.ident)
        }
    }
    
    final public func registerEvents(_ object:NWPollable) {
        kqDispatchQueue.async {
            let _ = self.internalAddReadWriteEvent(object, clear: true)
        }
    }

    final public func unregisterEvents(_ object: NWPollable) {
        kqDispatchQueue.async {
            self.internalRemoveReadWriteEvent(object)
        }
    }
}

