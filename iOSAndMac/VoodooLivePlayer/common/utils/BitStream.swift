//
//  BitStream.swift
//  live_player
//
//  Created by voodoo on 2019/12/17.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public final class BitStream {
    let data:Data
    private var dataIndex:Int
    private var sampleLeftBitsCount:Int
    private var leftBitsCount:Int
    private var dataSample:UInt8
    
    public var eof : Bool {
        get {
            return dataIndex >= data.count
        }
    }
    
    init(_ data:Data) {
        self.data = data
        self.leftBitsCount = self.data.count * 8
        self.dataIndex = 0
        self.dataSample = dataIndex < data.count ? data[dataIndex] : 0
        self.sampleLeftBitsCount = 8
    }
    
    convenience init(_ data:Data, pos:Int, size:Int) {
        self.init(data.subdata(in: pos..<pos+size))
    }
    
    private func _nextSample() {
        dataIndex += 1
        leftBitsCount = (data.count - self.dataIndex) * 8
        dataSample = dataIndex < data.count ? data[dataIndex] : 0
        sampleLeftBitsCount = 8
    }
    
    private func _advance(_ bc:Int) {
        let skipBitsCount = min(bc, leftBitsCount)
        leftBitsCount -= skipBitsCount
        sampleLeftBitsCount = leftBitsCount % 8
        if sampleLeftBitsCount == 0 { sampleLeftBitsCount = 8 }
        dataIndex = data.count - ((leftBitsCount+7) / 8)
        dataSample = dataIndex < data.count ? data[dataIndex] : 0
    }
    
    private func _eof() -> Bool {
        return dataIndex >= data.count
    }
    
    public func skip(bitsCount:Int) {
        _advance(bitsCount)
    }
    
    private func _readByte(_ bc:Int) -> UInt8 {
        if _eof() {
            return 0
        }
        if bc <= sampleLeftBitsCount {
            let mask = UInt8((1<<bc)-1)
            let moveRight = sampleLeftBitsCount - bc
            print(String(format: "%02X %02X %02X", dataSample, dataSample >> moveRight, mask))
            let result = (dataSample >> moveRight) & mask
            self._advance(bc)
            return result
        }

        let mask1 = UInt8((1<<sampleLeftBitsCount)-1)
        let move1 = bc - sampleLeftBitsCount
        var result = (dataSample & mask1) << move1
        _nextSample()
        if _eof() { return result }
        let mask2 = UInt8((1<<move1)-1)
        let move2 = 8 - move1
        result |= (dataSample  >> move2) & mask2
        
        sampleLeftBitsCount -= move1
        leftBitsCount -= move1
        
        return result
    }
    
    private func _read<R>(bitsCount:Int) -> R where R: BinaryInteger {
        guard bitsCount <= (MemoryLayout<R>.size * 8) else { return R(0) }
        
        var result:R = 0
        var toReadBitsCount = bitsCount
        while toReadBitsCount > 0 {
            let readBitsCount = toReadBitsCount > 8 ? 8 : toReadBitsCount
            toReadBitsCount -= readBitsCount
            
            result = (result << readBitsCount) | R(_readByte(readBitsCount))
        }
        return result
    }
    
    
    
    public func read(bitsCount:Int) -> Int {
        return _read(bitsCount:bitsCount)
    }
    
    public func readU(bitsCount:Int) -> UInt {
        return _read(bitsCount:bitsCount)
    }
    
    public func read64(bitsCount:Int) -> Int64 {
        return _read(bitsCount:bitsCount)
    }
    
    public func readU64(bitsCount:Int) -> UInt64 {
        return _read(bitsCount:bitsCount)
    }
    public func read32(bitsCount:Int) -> Int32 {
        return _read(bitsCount:bitsCount)
    }
    public func readU32(bitsCount:Int) -> UInt32 {
        return _read(bitsCount:bitsCount)
    }
    public func read16(bitsCount:Int) -> UInt16 {
        return _read(bitsCount:bitsCount)
    }
    public func readU16(bitsCount:Int) -> UInt16 {
        return _read(bitsCount:bitsCount)
    }
    public func read8(bitsCount:Int) -> UInt16 {
        return _read(bitsCount:bitsCount)
    }
    public func readU8(bitsCount:Int) -> UInt16 {
        return _read(bitsCount:bitsCount)
    }
    
}

