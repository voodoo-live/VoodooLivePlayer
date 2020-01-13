//
//  NWProtocolLayerQueuedSerializer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/9.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

public class NWQueuedSerializer {
    
    unowned let layer: NWProtocolLayer
    unowned let queue: DispatchQueue
    
    public init(layer:NWProtocolLayer, queue: DispatchQueue) {
        self.layer = layer
        self.queue = queue
    }
    
    
    public func clear() {
        readFlag = false
        writeFlag = false
        readQueue.removeAll()
        writeQueue.removeAll()
    }
    
    enum QueuedItemResult : Equatable {
        case again
        case success
        case failed(NWError)
        
        static func == (a:QueuedItemResult, b:QueuedItemResult) -> Bool {
            switch (a,b) {
            case (.success, .success), (.again, .again):
                return true
            case let (.failed(e1), .failed(e2))
                where e1 == e2:
                return true
            default:
                return false
            }
        }
    }
    
    public typealias ReadCompletedBlock = (Data?, AnyObject?, Error?) -> Void
    
    class ReadQueueItem {
        let minimumLength: Int
        let maximumLength: Int
        let completedBlock: ReadCompletedBlock
        let context: AnyObject?
        var buffer: Data!
        var readLength = 0
        
        init(minimumLength: Int, maximumLength: Int, completedBlock: @escaping ReadCompletedBlock, context: AnyObject? = nil) {
            self.minimumLength = minimumLength
            self.maximumLength = maximumLength
            self.completedBlock = completedBlock
            self.context = context
        }
    }
    
    var readQueue:[ReadQueueItem] = []
    var readFlag = false
    
    
    func internalReadItem(_ item:ReadQueueItem) -> QueuedItemResult {
        if item.buffer == nil {
            item.buffer = Data(capacity: item.maximumLength)
            item.buffer.count = item.maximumLength
        }
        let begin = item.readLength
        let readRet = item.buffer.withUnsafeMutableBytes { (ptr) -> Int in
            let sliceBuffer = ptr.suffix(from: begin)
            let rebaseBuffer = UnsafeMutableRawBufferPointer(rebasing: sliceBuffer)
            return layer.read(buffer: rebaseBuffer)
        }
        
        if readRet < 0 {
            self.readFlag = false
            if layer.error != .again &&
                layer.error != .wouldBlock {
                item.buffer.count = item.readLength
                //print("QS READ FAILED:\(layer.error)")
                return .failed(layer.error)
            }
            return .again
        } else if readRet == 0 {
            self.readFlag = false
            item.buffer.count = item.readLength
            print("QS READ FAILED: EOF")
            return .failed(.graceful_close)
        }
        item.readLength += readRet
        if item.readLength < item.maximumLength {
            self.readFlag = false
        }
        if item.readLength < item.minimumLength {
            return .again
        }
        item.buffer.count = item.readLength
        return .success
    }
    
    func internalReadNext() {
        //print("QS READ NEXT")
        while !self.readQueue.isEmpty {
            if let firstItem = self.readQueue.first {
                let receiveResult = internalReadItem(firstItem)
                if receiveResult == .again {
                    break
                }
                self.readQueue.remove(at: 0)
                var error:NWError? = nil
                if case let .failed(e) = receiveResult {
                    error = e
                }
                firstItem.completedBlock(firstItem.buffer, firstItem.context, error)
            }
        }
    }
    
    func internalRead(_ item: ReadQueueItem) {
        let needReadNext = self.readQueue.isEmpty && readFlag
        //print("APPEND READ ITEM \(item)")
        readQueue.append(item)
        if needReadNext {
            internalReadNext()
        }
    }
    
    
    public func read(minimumLength:Int, maximumLength:Int, context: AnyObject? = nil, completedBlock: @escaping ReadCompletedBlock) {
        let queueItem = ReadQueueItem(minimumLength: minimumLength, maximumLength: maximumLength, completedBlock: completedBlock, context: context)
        queue.async {
            self.internalRead(queueItem)
        }
    }

    public func handleRead(_ len: Int) {
        readFlag = true
        if !readQueue.isEmpty {
            internalReadNext()
        }
    }
    
    public typealias WriteCompletedBlock = (AnyObject?, Error?) -> Void
    
    class WriteQueueItem {
        let data: Data!
        var writePos: Int = 0
        var context: AnyObject?
        var completedBlock: WriteCompletedBlock?
        
        init(data: Data?, completedBlock: @escaping WriteCompletedBlock, context: AnyObject? = nil) {
            self.data = data
            self.completedBlock = completedBlock
            self.context = context
        }
        
        init(data: Data?, context: AnyObject? = nil) {
            self.data = data
            self.context = context
        }
    }
    
    var writeQueue:[WriteQueueItem] = []
    var writeFlag = false
    
    func internalWriteItem(_ item: WriteQueueItem) -> QueuedItemResult {
        if item.data != nil {
            let writeRet = item.data.withUnsafeBytes { (ptr) -> Int in
                let sliceData = ptr.suffix(from: item.writePos)
                let rebaseData = UnsafeRawBufferPointer(rebasing: sliceData)
                return layer.write(data: rebaseData)
            }
            if writeRet < 0 {
                self.writeFlag = false
                if layer.error != .again &&
                    layer.error != .wouldBlock {
                    return .failed(layer.error)
                }
                return .again
            }
            
            item.writePos += writeRet
            
            if item.writePos < item.data.count {
                self.writeFlag = false
                return .again
            }
        }

        return .success
    }
    
    func internalWriteNext() {
        while !self.writeQueue.isEmpty {
            if let firstItem = self.writeQueue.first {
                let writeResult = internalWriteItem(firstItem)
                if writeResult == .again {
                    break
                }
                self.writeQueue.remove(at: 0)
                if let completedBlock = firstItem.completedBlock {
                    var error:NWError? = nil
                    if case let .failed(e) = writeResult { error = e }
                    completedBlock(firstItem.context, error)
                }
            }
        }
    }
    
    func internalWrite(_ item: WriteQueueItem) {
        let needWriteNext = self.writeQueue.isEmpty && writeFlag
        self.writeQueue.append(item)
        if needWriteNext {
            internalWriteNext()
        }
    }
    
    public func write(data: Data?, context: AnyObject?, completedBlock: @escaping WriteCompletedBlock) {
        let queueItem = WriteQueueItem(data: data, completedBlock: completedBlock, context: context)
        queue.async {
            self.internalWrite(queueItem)
        }
    }
    
    public func write(data: Data?, completedBlock: @escaping WriteCompletedBlock) {
        let queueItem = WriteQueueItem(data: data, completedBlock: completedBlock, context: nil)
        queue.async {
            self.internalWrite(queueItem)
        }
    }

    public func write(data: Data?, context: AnyObject?) {
        let queueItem = WriteQueueItem(data: data, context: context)
        queue.async {
            self.internalWrite(queueItem)
        }
    }
    
    public func write(data: Data?) {
        let queueItem = WriteQueueItem(data: data, context: nil)
        queue.async {
            self.internalWrite(queueItem)
        }
    }
    
    public func handleWrite(_ len: Int) {
        writeFlag = true
        if !self.writeQueue.isEmpty {
            internalWriteNext()
        }
    }

    
    public func handleEOF(_ error: Int32) {
        if error == 0 {
            if !readQueue.isEmpty {
                internalReadNext()
            }
        }
        
        clear()
    }
}

