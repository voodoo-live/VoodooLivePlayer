//
//  LiveTimer.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/27.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import CoreMedia


public class LiveTimer {
    private var timebasePtr: UnsafeMutablePointer<CMTimebase?>?
    private(set) weak var timebase: CMTimebase!
    private(set) var label : String

    public let isCreated: Bool
    public let isReadOnly: Bool

    public init(timebase:CMTimebase, isReadOnly:Bool = false, label:String?=nil) {
        self.timebase = timebase
        self.isCreated = false
        self.isReadOnly = isReadOnly
        self.label = label ?? "<NONAME>"
        self.timebasePtr = nil
    }
    
    public init?(masterClock: CMClock = CMClockGetHostTimeClock(), label:String?=nil) {
        self.timebasePtr = UnsafeMutablePointer<CMTimebase?>.allocate(capacity: 1)
        let status = CMTimebaseCreateWithMasterClock(allocator: kCFAllocatorDefault, masterClock: masterClock, timebaseOut: self.timebasePtr!)
        if status == noErr {
            self.isCreated = true
            self.isReadOnly = false
            self.timebase = self.timebasePtr?.pointee
            self.label = label ?? "<NONAME>"
        } else {
            self.timebasePtr?.deallocate()
            self.timebasePtr = nil
            return nil
        }
    }
    
    deinit {
        if isCreated {
            print("DEINIT CREATED LIVE TIMER:", self.label)
            CMTimebaseSetRate(timebase, rate: 0)
            timebase = nil
            timebasePtr!.deallocate()
        } else {
            print("DEINIT REFERED LIVE TIMER:", self.label)
            timebase = nil
        }
    }
    
    public var rate: Double {
        get { return CMTimebaseGetRate(self.timebase) }
        set {
            if isReadOnly { return }
            let osstatus = CMTimebaseSetRate(timebase, rate: newValue)
            if osstatus != noErr {
                print("LiveTimer set rate failed:", osstatus)
            }
        }
    }
    
    public var time: CMTime {
        get { return CMTimebaseGetTime(self.timebase) }
        set {
            if isReadOnly { return }
            let osstatus = CMTimebaseSetTime(timebase, time: newValue)
            if osstatus != noErr {
                print("LiveTimer set time failed:", osstatus)
            }
        }
    }
    
    public func setRate(_ rate: Double, andTime time: CMTime) {
        if isReadOnly { return }
        var masterTime: CMTime
        if #available(iOS 9.0, *) {
            
            masterTime = CMSyncGetTime(CMTimebaseCopyMaster(timebase))
        } else {
            masterTime = CMSyncGetTime(CMTimebaseGetMaster(timebase) ?? CMClockGetHostTimeClock())
        }
        //let master = CMTimebaseCopyMaster(timebase)
        let osstatus = CMTimebaseSetRateAndAnchorTime(timebase, rate: rate, anchorTime: CMTimebaseGetTime(timebase), immediateMasterTime: masterTime)
        if osstatus != noErr {
            print("LiveTimer set rate and time failed:", osstatus)
        }
    }
}

