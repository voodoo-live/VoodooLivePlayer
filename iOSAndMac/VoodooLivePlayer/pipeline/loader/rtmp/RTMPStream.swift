//
//  RTMPStream.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/7.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

func showHexData(_ data:Data) {
    var hexIndex = 0
    var hexString = ""
    for v in data {
        if (hexIndex % 64) == 0 && !hexString.isEmpty {
            print(hexString)
            hexString = ""
        }
        hexString += String(format:"%02X ", v)
        hexIndex += 1
    }
    
    print(hexString)
}

class RTMPStream {
    var data: Data
    var pos: Int = 0
    
    init(capacity: Int) {
        self.data = Data(capacity: capacity)
    }
    
    init(data:Data) {
        self.data = data
    }
    
    var eof: Bool { get { pos >= data.count }}
    
    var bytesAvalible: Int {
        get {
            return pos < data.count ? data.count - pos : 0
        }
    }
    
    func randomFill(size:Int) {
        self.data.reserveCapacity(size + self.data.count)
        let pos = self.data.count
        self.data.count += size
        for i in pos..<self.data.count {
            self.data[i] = UInt8.random(in: 0...255)
        }
    }
    
    func write(data:Data) {
        self.data.append(data)
    }
    
    func write(bytes:[UInt8]) {
        data.append(contentsOf: bytes)
    }
    
    func write(_ value: UInt8) {
        data.append(value)
    }
    
    func readSkip(len:Int) -> Bool {
        guard pos + len <= data.count else { return false }
        pos += len
        return true
    }
    
    func writeSkip(len:Int) {
        data.count += len
    }
    
    func writeBool(_ value:Bool) {
        data.append(value ? 1 : 0)
    }
    
    func writeUInt8(_ value:UInt8) {
        data.append(value)
    }
    
    func readUInt8() -> UInt8? {
        guard !eof else { return nil }
        pos += 1
        return data[pos-1]
    }
    
    func writeUInt16(_ value:UInt16) {
        let wvalue = value.bigEndian
        withUnsafeBytes(of: wvalue) { (ptr) -> Void in
            self.data.append(ptr.bindMemory(to: UInt8.self))
        }
    }
    
    func readUInt16() -> UInt16? {
        guard pos + 2 <= data.count else { return nil }
        pos += 2
        return (UInt16(data[pos-2]) << 8) | UInt16(data[pos-1])
    }
    /**
     (hex)
     0x00000000 - 0x0000007F 0x00000080 - 0x00003FFF 0x00004000 - 0x001FFFFF 0x00200000 - 0x3FFFFFFF 0x40000000 - 0xFFFFFFFF
     : (binary)
     : 0xxxxxxx
     : 1xxxxxxx 0xxxxxxx
     : 1xxxxxxx 1xxxxxxx 0xxxxxxx
     : 1xxxxxxx 1xxxxxxx 1xxxxxxx xxxxxxxx : throw range exception
     In ABNF syntax, the variable length unsigned 29-bit integer type is described as follows:
     U29 = U29-1 | U29-2 | U29-3 | U29-4
     U29-1 = %x00-7F
     U29-2 = %x80-FF %x00-7F
     U29-3 = %x80-FF %x80-FF %x00-7F
     U29-4 = %x80-FF %x80-FF %x80-FF %x00-FF
     */
    func readUInt29() -> UInt32? {
        let oldPos = pos
        var value: UInt32 = 0
        for _ in 0...2 {
            if let byteValue = readUInt8() {
                value = (value << 7) | UInt32(byteValue & 0x7f)
                if (byteValue & 0x80) == 0 {
                    return value
                }
            } else {
                self.pos = oldPos
                return nil
            }
        }
        if let byteValue = readUInt8() {
            value = (value << 7) | UInt32(byteValue)
            return value
        } else {
            self.pos = oldPos
            return nil
        }
    }

    func writeUInt29(_ value: UInt32) -> Bool {
        let oldPos = data.count
        var wvalue = value
        for _ in 0...2 {
            let hasNextByte = wvalue > 0x7f
            writeUInt8(UInt8(hasNextByte ? 0x80 : 0)|UInt8(wvalue & 0x7f))
            wvalue >>= 7
            if hasNextByte { continue }
            break
        }
        if wvalue > 0xff {
            data.count = oldPos
            return false
        }
        writeUInt8(UInt8(wvalue & 0xff))
        return true
    }
    
    func writeShortString(_ value: String) -> Bool {
        if let wvalue = value.data(using: .utf8) {
            let len = min(wvalue.count, 255)
            writeUInt8(UInt8(len))
            write(data: wvalue.subdata(in: 0..<len))
            return true
        }
        return false
    }
    
    func writeString(_ value: String) -> Bool {
        if let wvalue = value.data(using: .utf8) {
            let len = min(wvalue.count, 0xffff)
            writeUInt16(UInt16(len))
            write(data: wvalue.subdata(in: 0..<len))
            return true
        }
        return false
    }
    
    func writeLongString(_ value: String) -> Bool {
        if let wvalue = value.data(using: .utf8) {
            /// here, we take Int32.max, actually we need UInt32.max, but in 32bits, Int = Int32, UInt32.max will overflow. And in 64bits, Int = Int64, Int.max is not fit UInt32.
            let len = min(wvalue.count, Int(Int32.max))
            writeUInt32(UInt32(len))
            write(data: wvalue.subdata(in: 0..<len))
            return true
        }
        return false
    }
    
    func readShortString() -> String? {
        let oldPos = pos
        if let len = readUInt8() {
            if let strValue = len == 0 ? "" : String(data: data.subdata(in: pos..<pos+Int(len)), encoding: .utf8) {
                pos += Int(len)
                return strValue
            }
            pos = oldPos
        }
        return nil
    }
    
    func readString() -> String? {
        let oldPos = pos
        if let len = readUInt16() {
            if let strValue = len == 0 ? "" : String(data: data.subdata(in: pos..<pos+Int(len)), encoding: .utf8) {
                pos += Int(len)
                return strValue
            }
            pos = oldPos
        }
        return nil
    }
    
    func readLongString() -> String? {
        let oldPos = pos
        if let len = readUInt32() {
            if let strValue = len == 0 ? "" : String(data: data.subdata(in: pos..<pos+Int(len)), encoding: .utf8) {
                pos += Int(len)
                return strValue
            }
            pos = oldPos
        }
        return nil
    }
    
    func writeUInt32(_ value:UInt32) {
        let wvalue = value.byteSwapped
        withUnsafeBytes(of: wvalue) { (ptr) -> Void in
            self.data.append(ptr.bindMemory(to: UInt8.self))
        }
    }
    
    func readUInt32() -> UInt32? {
        guard pos + 4 <= data.count else { return nil }
        pos += 4
        return (UInt32(data[pos-4]) << 24) |
        (UInt32(data[pos-3]) << 16) |
        (UInt32(data[pos-2]) << 8) |
        UInt32(data[pos-1])
    }

    static let MinInt24: Int32 = -0x800000
    static let MaxInt24: Int32 = 0x7fffff
    
    static func packInt24(_ value:Int32) -> [UInt8] {
        let uvalue = UInt32(bitPattern: value)
        let wvalue = (((uvalue & 0x80000000) >> 8) | (uvalue & 0x7fffff)).byteSwapped
        return withUnsafeBytes(of: wvalue) { (ptr) -> [UInt8] in
            return ptr.bindMemory(to: UInt8.self).suffix(3)
        }
    }
    
    static func unpackInt24(_ value:[UInt8]) -> Int32 {
        let uvalue = (UInt32(value[0]) << 16) |
        (UInt32(value[1]) << 8) |
        UInt32(value[2])
        
        return (uvalue & 0x800000) == 0 ?
        Int32(bitPattern: uvalue & 0x7fffff) :
        Int32(bitPattern: (0xff000000 | (uvalue & 0xffffff)))
    }
    
    static func packUInt24(_ value: UInt32) -> [UInt8] {
        let wvalue = (value & 0xffffff).byteSwapped
        return withUnsafeBytes(of: wvalue) { (ptr) -> [UInt8] in
            return ptr.bindMemory(to: UInt8.self).suffix(3)
        }
    }
    
    static func unpackUInt24(_ value: [UInt8]) -> UInt32 {
        return (UInt32(value[0]) << 16) |
        (UInt32(value[1]) << 8) |
        UInt32(value[2])
    }
    
    static func unpackUInt24(_ value: Data) -> UInt32 {
        return (UInt32(value[0]) << 16) |
        (UInt32(value[1]) << 8) |
        UInt32(value[2])
    }
    
    func writeInt24(_ value:Int32) {
        self.data.append(contentsOf: RTMPStream.packInt24(value))
    }
    
    func readInt24() -> Int32? {
        guard pos + 3 <= data.count else { return nil }
        pos += 3
        return RTMPStream.unpackInt24([data[pos-3], data[pos-2], data[pos-1]])
    }
    
    func writeDouble(_ value:Double) {
        withUnsafeBytes(of: value) { (ptr) -> Void in
            self.data.append(contentsOf: ptr.reversed())
        }
    }
    
    func readDouble() -> Double? {
        guard pos + 8 <= data.count else { return nil }
        pos += 8
        return data.withUnsafeBytes { (ptr) -> Double in
            let ar:[UInt8] = ptr[pos-8..<pos].reversed()
            return ar.withUnsafeBytes { (ptr) -> Double in
                return ptr.load(as: Double.self)
            }
        }
    }
}
