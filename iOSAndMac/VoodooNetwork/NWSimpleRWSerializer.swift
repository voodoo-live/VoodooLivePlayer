//
//  NWSimpleRWSerializer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/10.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class NWSimpleRWSerializer {
    unowned let layer: NWProtocolLayer
    unowned let queue: DispatchQueue
    
    public init(layer:NWProtocolLayer, queue: DispatchQueue) {
        self.layer = layer
        self.queue = queue
    }
    
    enum State {
        case idle
        case busy
    }
    
    var state: State = .idle
    
    enum Mode {
        case none
        case read
        case write
    }
    
    var mode: Mode = .none {
        didSet {
            if oldValue == mode { return }
            if mode == .none {
                buffer = nil
                position = 0
                context = nil
                completedBlock = nil
            }
        }
    }
    var buffer: Data!
    var position: Int = 0
    var minSize: Int = 0
    var maxSize: Int = 0
    var context: AnyObject?
    var completedBlock: CompletedBlock?
    
    public func clear() {
        mode = .none
    }
    
    typealias CompletedBlock = (Data?,AnyObject?,Error?) -> Void
    func read(minSize: Int, maxSize: Int, context: AnyObject?, completedBlock: @escaping CompletedBlock) -> Bool {
        guard mode == .none else { return false }
        self.mode = .read
        self.minSize = minSize
        self.maxSize = maxSize
        self.context = context
        self.position = 0
        self.completedBlock = completedBlock

        queue.async {
            self.state = .busy
            if self.readFlag {
                self.doRead()
            }
        }
        
        return true
    }
    
    func write(data: Data?, context: AnyObject?, completedBlock: @escaping CompletedBlock) -> Bool {
        guard mode == .none else { return false }
        internalWrite(data: data, context: context, completedBlock: completedBlock)
        return true
    }
    
    func write(data: Data?) -> Bool {
        guard mode == .none else { return false }
        internalWrite(data: data, context: nil, completedBlock: nil)
        return true
    }
    
    func internalWrite(data: Data?, context: AnyObject?, completedBlock: CompletedBlock?) {
        self.mode = .write
        self.buffer = data
        self.position = 0
        self.context = context
        self.completedBlock = completedBlock
        queue.async {
            self.state = .busy
            if self.writeFlag {
                self.doWrite()
            }
        }
    }
    
    func completeWrite(_ error: NWError? = nil) {
        self.state = .idle
        if let writeCompletedBlock = self.completedBlock {
            let context = self.context
            mode = .none
            writeCompletedBlock(nil, context, error)
        } else {
            mode = .none
        }
    }
    
    func doWrite() {
        print("doWrite")
        if self.buffer == nil {
            completeWrite()
            return
        }
        
        let writeRet = self.buffer.withUnsafeBytes({ (ptr) -> Int in
            let sliceData = ptr.suffix(from: self.position)
            let rebaseData = UnsafeRawBufferPointer(rebasing: sliceData)
            return self.layer.write(data: rebaseData)
        })
        if writeRet < 0 {
            self.writeFlag = false
            if layer.error != .wouldBlock &&
                layer.error != .again {
                completeWrite(layer.error)
            }
        } else {
            self.position += writeRet
            if self.position >= self.buffer.count {
                completeWrite(nil)
            } else {
                writeFlag = false
            }
        }
    }
    
    func completeRead(_ error: NWError? = nil) {
        self.state = .idle
        if let readCompletedBlock = self.completedBlock {
            self.buffer.count = self.position
            let data = self.buffer.isEmpty ? nil : self.buffer
            let context = self.context
            mode = .none
            readCompletedBlock(data, context, error)
        } else {
            mode = .none
        }
    }
    
    func doRead() {
        if self.buffer == nil {
            self.buffer = Data(capacity: self.maxSize)
            self.buffer.count = maxSize
        }
        
        let readRet = self.buffer.withUnsafeMutableBytes({ (ptr) -> Int in
            let sliceData = ptr.suffix(from: self.position)
            let rebaseData = UnsafeMutableRawBufferPointer(rebasing: sliceData)
            return self.layer.read(buffer: rebaseData)
        })
        
        if readRet < 0 {
            self.readFlag = false
            if layer.error != .wouldBlock && layer.error != .again {
                completeRead(layer.error)
            }
        } else if readRet == 0 {
            self.readFlag = false
            completeRead(.graceful_close)
        } else {
            self.position += readRet
            if self.position < maxSize {
                self.readFlag = false
            }
            if self.position >= minSize {
                completeRead()
            }
        }
    }
    
    var readFlag = false
    var writeFlag = false

    func handleWrite(_ len: Int) {
        print("handleWrite")
        writeFlag = true
        if state == .busy &&
            mode == .write {
            
            doWrite()
        }
    }
    
    func handleRead(_ len: Int) {
        print("handleRead")
        readFlag = true
        if state == .busy &&
            mode == .read {
            doRead()
        }
    }
    
    func handleEOF(_ error: Int32) {
        print("handleEOF")
        if readFlag && state == .busy &&
            mode == .read {
            doRead()
        }
    }
}
