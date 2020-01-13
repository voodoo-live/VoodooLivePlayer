//
//  AMFObject.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/7.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation


func AMFAnyEquable(a: [Any?], b: [Any?]) -> Bool {
    guard a.count == b.count else { return false }
    for i in 0..<a.count {
        if !AMFAnyEquable(a: a[i], b: b[i]) { return false }
    }
    return true
}

func AMFAnyEquable(a: [String:Any?], b: [String:Any?]) -> Bool {
    guard a.count == b.count else { return false }
    guard a.keys == b.keys else { return false }
    
    for k in a.keys {
        if !AMFAnyEquable(a: a[k] ?? AMFUndefined(), b: b[k] ?? AMFUndefined()) { return false }
    }
    return true
}

func AMFAnyEquable(a: Any?, b: Any?) -> Bool {
    if let intA = a as? Int, let intB = b as? Int {
        return intA == intB
    } else if let strA = a as? String, let strB = b as? String {
        return strA == strB
    } else if let doubleA = a as? Double, let doubleB = b as? Double {
        return doubleA == doubleB
    } else if let arrayA = a as? [Any?], let arrayB = b as? [Any?] {
        return AMFAnyEquable(a: arrayA, b: arrayB)
    } else if let dictA = a as? [String:Any?], let dictB = b as? [String:Any?] {
        return AMFAnyEquable(a: dictA, b: dictB)
    } else {
        return false
    }
}

class AMFWrapped : Equatable {
    let type: UInt8
    let value: Any?
    
    init(type: UInt8, value: Any?) {
        self.type = type
        self.value = value
    }
    
    static func ==(a: AMFWrapped, b: AMFWrapped) -> Bool {
        return a.type == b.type && AMFAnyEquable(a: a.value, b: b.value)
    }
}

class AMFClass : Equatable {
    var name: String = ""
    var isDynamic: Bool = false
    var fields: [String] = []
    
    static func ==(a: AMFClass, b: AMFClass) -> Bool {
        guard a.name == b.name else { return false }
        guard a.isDynamic == b.isDynamic else { return false }
        guard a.fields == b.fields else { return false }
        return true
    }
}

class AMFObject : Equatable {
    var classRef: AMFClass?
    var members: Dictionary<String, Any?> = [:]
    
    static func == (a: AMFObject, b: AMFObject) -> Bool {
        guard a.classRef == b.classRef else { return false }
        guard a.members.count == b.members.count else { return false }
        return AMFAnyEquable(a: a.members, b: b.members)
    }
}



enum AMFArray : Equatable {
    case strict([Any?])
    case named([String:Any?])
    
    static func == (a: AMFArray, b: AMFArray) -> Bool {
        switch (a,b) {
        case let (.strict(arrayA), .strict(arrayB)) where AMFAnyEquable(a:arrayA,b:arrayB): return true
        case let (.named(dictA), .named(dictB)) where AMFAnyEquable(a:dictA,b:dictB): return true
        default:
            return false
        }
    }
}

class AMFDictionary : Equatable {
    init(isWeakKey:Bool = false) {
        self.isWeakKey = isWeakKey
    }
    var isWeakKey: Bool
    var values: [(key:Any?, value:Any?)] = []
    
    subscript(key: Any?) -> Any? {
        get {
            if let index = values.firstIndex( where: { (kv) -> Bool in
                return AMFAnyEquable(a: kv.key, b: key)
            } ) {
                return values[index].value
            }
            return nil
        }
        
        set {
            if let index = values.firstIndex( where: { (kv) -> Bool in
                return AMFAnyEquable(a: kv.key, b: key)
            } ) {
                values[index].value = newValue
            } else {
                values.append((key, newValue))
            }
        }
    }
    
    static func == (a: AMFDictionary, b: AMFDictionary) -> Bool {
        guard a.isWeakKey == b.isWeakKey else { return false }
        guard a.values.count == b.values.count else { return false }
        for i in 0..<a.values.count {
            if !AMFAnyEquable(a: a.values[i].key, b: b.values[i].key) { return false }
            if !AMFAnyEquable(a: a.values[i].value, b: b.values[i].value) { return false }
        }
        return true
    }
}

class AMFVector {
    let isFixed: Bool
    init(isFixed: Bool = false) {
        self.isFixed = isFixed
    }
}

class AMFIntVector : AMFVector, Equatable {
    init() {
        self.values = []
        super.init(isFixed: false)
    }
    
    init(values: [Int32]) {
        self.values = values
        super.init(isFixed: true)
    }
    var values: [Int32]
    
    static func == (a: AMFIntVector, b: AMFIntVector) -> Bool {
        guard a.isFixed == b.isFixed else { return false }
        return a.values == b.values
    }
}

class AMFUIntVector : AMFVector, Equatable {
    init() {
        self.values = []
        super.init(isFixed: false)
    }
    
    init(values: [UInt32]) {
        self.values = values
        super.init(isFixed: true)
    }
    var values: [UInt32]
    static func == (a: AMFUIntVector, b: AMFUIntVector) -> Bool {
        guard a.isFixed == b.isFixed else { return false }
        return a.values == b.values
    }
}

class AMFDoubleVector : AMFVector, Equatable {
    init() {
        self.values = []
        super.init(isFixed: false)
    }
    
    init(values: [Double]) {
        self.values = values
        super.init(isFixed: true)
    }
    var values: [Double]
    static func == (a: AMFDoubleVector, b: AMFDoubleVector) -> Bool {
        guard a.isFixed == b.isFixed else { return false }
        return a.values == b.values
    }
}

class AMFObjectVector : AMFVector, Equatable {
    let typeClass: AMFClass
    init(typeClass: AMFClass) {
        self.typeClass = typeClass
        values = []
        super.init(isFixed: false)
    }
    init?(values: [AMFObject]) {
        guard !values.isEmpty && values[0].classRef != nil else { return nil }
        let classRef: AMFClass = values[0].classRef!
        for obj in values {
            if obj.classRef != classRef {
                return nil
            }
        }
        self.typeClass = classRef
        self.values = values
        super.init(isFixed: true)
    }
    var values: [AMFObject]
    static func == (a: AMFObjectVector, b: AMFObjectVector) -> Bool {
        guard a.isFixed == b.isFixed else { return false }
        return a.values == b.values
    }
}

class AMFByteArray : Equatable {
    let data: Data
    init(data: Data) {
        self.data = data
    }
    
    init(data:[UInt8]) {
        self.data = Data(data)
    }
    
    static func == (a: AMFByteArray, b: AMFByteArray) -> Bool {
        return a.data == b.data
    }
}





//typealias AMFDictionary = Dictionary<String, Any?>
//typealias AMFArray = Array<Any?>
class AMFUndefined {}
typealias AMFString = String
typealias AMFXMLDoc = String
typealias AMFXML = String
typealias AMFDate = Date
//typealias AMFByteArray = Data



class AMF3 {
    
    private class CodeContext {
        var failed = false

        var stringTable: [String] = []
        var classTraitTable: [String] = []
        var xmlDocumentTable: [String] = []
        var xmlTable: [String] = []
        var dateTable: [Date] = []
        var objectTable: [AMFObject] = []
        var classTable: [AMFClass] = []
        var arrayTable: [AMFArray] = []
        var dictionaryTable: [AMFDictionary] = []
        var intVectorTable: [AMFIntVector] = []
        var uintVectorTable: [AMFUIntVector] = []
        var doubleVectorTable: [AMFDoubleVector] = []
        var objectVectorTable: [AMFObjectVector] = []
        
        var byteArrayTable: [AMFByteArray] = []
        
        func cacheByteArray(value: AMFByteArray) -> Int? {
            if let index = byteArrayTable.firstIndex(of: value) {
                return index
            } else {
                byteArrayTable.append(value)
                return nil
            }
        }

        func cacheString(value: String) -> Int? {
            if let index = stringTable.firstIndex(of: value) {
                return index
            } else {
                stringTable.append(value)
                return nil
            }
        }
        
        func cacheDate(value: Date) -> Int? {
            if let index = dateTable.firstIndex(of: value) {
                return index
            } else {
                dateTable.append(value)
                return nil
            }
        }
        
        func cacheXMLDocument(value: String) -> Int? {
            if let index = xmlDocumentTable.firstIndex(of: value) {
                return index
            } else {
                xmlDocumentTable.append(value)
                return nil
            }
        }
        
        func cacheXML(value: String) -> Int? {
            if let index = xmlTable.firstIndex(of: value) {
                return index
            } else {
                xmlTable.append(value)
                return nil
            }
        }
        
        func cacheObject(value: AMFObject) -> Int? {
            for i in 0..<objectTable.count {
                if ObjectIdentifier(objectTable[i]) == ObjectIdentifier(value) {
                    return i
                }
            }
            objectTable.append(value)
            return nil
        }
        
        func cacheClass(value: AMFClass) -> Int? {
            for i in 0..<classTable.count {
                if ObjectIdentifier(classTable[i]) == ObjectIdentifier(value) {
                    return i
                }
            }
            classTable.append(value)
            return nil
        }
        
        func cacheDictionary(value: AMFDictionary) -> Int? {
            if let index = dictionaryTable.firstIndex(of: value) {
                return index
            } else {
                dictionaryTable.append(value)
                return nil
            }
        }
        
        func cacheArray(value: AMFArray) -> Int? {
            if let index = arrayTable.firstIndex(of: value) {
                return index
            } else {
                arrayTable.append(value)
                return nil
            }
        }
        
        func cacheIntVector(value: AMFIntVector) -> Int? {
            if let index = intVectorTable.firstIndex(of: value) {
                return index
            } else {
                intVectorTable.append(value)
                return nil
            }
        }
        func cacheUIntVector(value: AMFUIntVector) -> Int? {
            if let index = uintVectorTable.firstIndex(of: value) {
                return index
            } else {
                uintVectorTable.append(value)
                return nil
            }
        }
        func cacheObjectVector(value: AMFObjectVector) -> Int? {
            if let index = objectVectorTable.firstIndex(of: value) {
                return index
            } else {
                objectVectorTable.append(value)
                return nil
            }
        }
        func cacheDoubleVector(value: AMFDoubleVector) -> Int? {
            if let index = doubleVectorTable.firstIndex(of: value) {
                return index
            } else {
                doubleVectorTable.append(value)
                return nil
            }
        }
    }
    
    static func unpackValues(from: RTMPStream) -> Array<Any?>? {
        let context = CodeContext()
        
        var values: [Any?] = []
        
        while !from.eof {
            if let value = unpackValue(context, from: from) {
                values.append(value)
            } else if !context.failed {
                values.append(nil)
            } else {
                return nil
            }
        }
        
        return values
    }
    
    static func pack(values: Array<Any?>?, to: RTMPStream) -> Bool {
        
        return false
    }
    
    private static func packValue(_ value: Any?, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let value = value {
            if let _ = value as? AMFUndefined {
                to.writeUInt8(ValueType.undefined_marker.rawValue)
            } else if let boolValue = value as? Bool {
                to.writeUInt8(boolValue ? ValueType.true_marker.rawValue : ValueType.false_marker.rawValue)
            } else if let intValue = value as? Int {
                if intValue > 0x3ffffff {
                    /// write as double
                    let doubleValue = Double(intValue)
                    to.writeUInt8(ValueType.double_marker.rawValue)
                    to.writeDouble(doubleValue)
                } else {
                    to.writeUInt8(ValueType.integer_marker.rawValue)
                    _ = to.writeUInt29(UInt32(intValue))
                }
            } else if let doubleValue = value as? Double {
                to.writeUInt8(ValueType.double_marker.rawValue)
                to.writeDouble(doubleValue)
            } else if let stringValue = value as? String {
                to.writeUInt8(ValueType.string_marker.rawValue)
                return packString(stringValue, to: to, withContext: context)
            } else if let dateValue = value as? Date {
                to.writeUInt8(ValueType.date_marker.rawValue)
                if let cacheIndex = context.cacheDate(value: dateValue) {
                    let refIndex = UInt32(cacheIndex) << 1
                    if !to.writeUInt29(refIndex) { return false }
                } else {
                    to.writeUInt8(0x01)
                    to.writeDouble(dateValue.timeIntervalSince1970)
                }
            } else if let arrayValue = value as? [UInt8] {
                to.writeUInt8(ValueType.byte_array_marker.rawValue)
                let ba = AMFByteArray(data: arrayValue)
                if let cacheIndex = context.cacheByteArray(value: ba) {
                    let refIndex = UInt32(cacheIndex) << 1
                    if !to.writeUInt29(refIndex) { return false }
                } else {
                    let byteArrayLength = UInt32(ba.data.count) << 1 | 0x01
                    if !to.writeUInt29(byteArrayLength) { return false }
                    to.write(data: ba.data)
                }
            } else if let arrayValue = value as? [Int] {
                to.writeUInt8(ValueType.vector_int_marker.rawValue)
                
                let intArray = arrayValue.map { (v) -> Int32 in
                    return Int32(v)
                }
                
                if !packIntVector(AMFIntVector(values: intArray), to: to, withContext: context) { return false }
                
            } else if let arrayValue = value as? [Double] {
                to.writeUInt8(ValueType.vector_double_marker.rawValue)
                if !packDoubleVector(AMFDoubleVector(values: arrayValue), to: to, withContext: context) { return false }
            } else if let arrayValue = value as? [Int32] {
                to.writeUInt8(ValueType.vector_int_marker.rawValue)
                if !packIntVector(AMFIntVector(values: arrayValue), to: to, withContext: context) { return false }
            } else if let arrayValue = value as? [UInt32] {
                to.writeUInt8(ValueType.vector_uint_marker.rawValue)
                if !packUIntVector(AMFUIntVector(values: arrayValue), to: to, withContext: context) { return false }
            } else if let arrayValue = value as? [AMFObject] {
                to.writeUInt8(ValueType.vector_object_marker.rawValue)
                if let objectVector = AMFObjectVector(values: arrayValue) {
                    if !packObjectVector(objectVector, to: to, withContext: context) { return false }
                } else {
                    return false
                }
            } else if let arrayValue = value as? [Any?] {
                to.writeUInt8(ValueType.array_marker.rawValue)

                if let cacheIndex = context.cacheArray(value: .strict(arrayValue)) {
                    if !to.writeUInt29(UInt32(cacheIndex)<<1) { return false }
                } else {
                    let arrayCount = (UInt32(arrayValue.count) << 1) | 0x01
                    if !to.writeUInt29(arrayCount) { return false }
                    to.writeUInt8(0x01)
                    for i in 0..<arrayValue.count {
                        if !packValue(arrayValue[i], to: to, withContext: context) { return false }
                    }
                }
            } else if let namedArrayValue = value as? [String: Any?] {
                to.writeUInt8(ValueType.array_marker.rawValue)
                if let cacheIndex = context.cacheArray(value: .named(namedArrayValue)) {
                    if !to.writeUInt29(UInt32(cacheIndex)<<1) { return false }
                } else {
                    to.writeUInt8(0x01)
                    for kv in namedArrayValue {
                        if !packString(kv.key, to: to, withContext: context) { return false }
                        if !packValue(kv.value, to: to, withContext: context) { return false }
                    }
                }
            } else if let _ = value as? AMFDictionary {
                to.writeUInt8(ValueType.dictionary_marker.rawValue)
            } else if let objectValue = value as? AMFObject {
                to.writeUInt8(ValueType.object_marker.rawValue)
                if !packObject(objectValue, to: to, withContext: context) { return false }
            }
        } else {
            to.writeUInt8(ValueType.null_marker.rawValue)
        }
        return true
    }
    
    private static func packIntVector(_ value: AMFIntVector, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let cacheIndex = context.cacheIntVector(value: value) {
            let refIndex = UInt32(cacheIndex) << 1
            if !to.writeUInt29(refIndex) { return false }
        } else {
            let vectorLength = (UInt32(value.values.count) << 1) | 0x01
            if !to.writeUInt29(vectorLength) { return false }
            for intValue in value.values {
                if !to.writeUInt29(UInt32(bitPattern: intValue)) { return false }
            }
        }
        return true
    }
    private static func packUIntVector(_ value: AMFUIntVector, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let cacheIndex = context.cacheUIntVector(value: value) {
            let refIndex = UInt32(cacheIndex) << 1
            if !to.writeUInt29(refIndex) { return false }
        } else {
            let vectorLength = (UInt32(value.values.count) << 1) | 0x01
            if !to.writeUInt29(vectorLength) { return false }
            for uintValue in value.values {
                if !to.writeUInt29(uintValue) { return false }
            }
        }
        return true
    }
    private static func packDoubleVector(_ value: AMFDoubleVector, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let cacheIndex = context.cacheDoubleVector(value: value) {
            let refIndex = UInt32(cacheIndex) << 1
            if !to.writeUInt29(refIndex) { return false }
        } else {
            let vectorLength = (UInt32(value.values.count) << 1) | 0x01
            if !to.writeUInt29(vectorLength) { return false }
            for doubleValue in value.values {
                to.writeDouble(doubleValue)
            }
        }
        return true
    }
    private static func packObjectVector(_ value: AMFObjectVector, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let cacheIndex = context.cacheObjectVector(value: value) {
            let refIndex = UInt32(cacheIndex) << 1
            if !to.writeUInt29(refIndex) { return false }
        } else {
            let vectorLength = (UInt32(value.values.count) << 1) | 0x01
            if !to.writeUInt29(vectorLength) { return false }
            for vv in value.values {
                if !packObject(vv, to: to, withContext: context) { return false }
            }
        }
        return true
    }

    private static func packObject(_ value: AMFObject, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if let cacheIndex = context.cacheObject(value: value) {
            if !to.writeUInt29(UInt32(cacheIndex)<<1) { return false }
        } else {
            let classRef = value.classRef!
            if let classCacheIndex = context.cacheClass(value: classRef) {
                let refIndex = UInt32(classCacheIndex) << 2 | 0x1
                if !to.writeUInt29(refIndex) { return false }
            } else {
                let classIdentifier: UInt32 = 0x3 | (classRef.isDynamic ? 0x8 : 0) | UInt32(classRef.fields.count) << 4
                if !to.writeUInt29(classIdentifier) { return false }
                
                if !packString(classRef.name, to: to, withContext: context) { return false }
                
                for fieldName in classRef.fields {
                    if !packString(fieldName, to: to, withContext: context) { return false }
                }
            }
            
            for fieldName in classRef.fields {
                if !packValue(value.members[fieldName] ?? AMFUndefined(), to: to, withContext: context) {
                    return false
                }
            }
            
            if classRef.isDynamic {
                for kv in value.members {
                    if classRef.fields.firstIndex(of: kv.key) == nil {
                        if !packString(kv.key, to: to, withContext: context) { return false }
                        if !packValue(kv.value, to: to, withContext: context) { return false }
                    }
                }
                to.writeUInt8(0x01)
            }
        }
        return true
    }

    private static func packString(_ value: String, to: RTMPStream, withContext context: CodeContext) -> Bool {
        if value.isEmpty {
            to.writeUInt8(0x01)
        } else if let cacheIndex = context.cacheString(value: value) {
            let refIndex = UInt32(cacheIndex) << 1
            if !to.writeUInt29(refIndex) { return false }
        } else {
            if let strData = value.data(using: .utf8) {
                let strLength = (UInt32(strData.count) << 1) | 1
                if !to.writeUInt29(strLength) { return false }
                to.write(data: strData)
            } else {
                return false
            }
        }
        return true
    }
    
    private static func unpackValue(_ context: CodeContext, from: RTMPStream) -> Any? {
        return nil
    }
    
    
    enum ValueType : UInt8, CustomDebugStringConvertible {
        case undefined_marker = 0
        case null_marker = 1
        case true_marker = 2
        case false_marker = 3
        case integer_marker = 4
        case double_marker = 5
        case string_marker = 6
        case xml_doc_marker = 7
        case date_marker = 8
        case array_marker = 9
        case object_marker = 0x0a
        case xml_marker = 0x0b
        case byte_array_marker = 0x0c
        case vector_int_marker = 0x0d
        case vector_uint_marker = 0x0e
        case vector_double_marker = 0x0f
        case vector_object_marker = 0x10
        case dictionary_marker = 0x11
        
        var debugDescription: String {
            get {
                switch self {
                case .undefined_marker: return "undefined_marker"
                case .null_marker: return "null_marker"
                case .true_marker: return "true_marker"
                case .false_marker: return "false_marker"
                case .integer_marker: return "integer_marker"
                case .double_marker: return "double_marker"
                case .string_marker: return "string_marker"
                case .xml_doc_marker: return "xml_doc_marker"
                case .date_marker: return "date_marker"
                case .array_marker: return "array_marker"
                case .object_marker: return "object_marker"
                case .xml_marker: return "xml_marker"
                case .byte_array_marker: return "byte_array_marker"
                case .vector_int_marker: return "vector_int_marker"
                case .vector_uint_marker: return "vector_uint_marker"
                case .vector_double_marker: return "vector_double_marker"
                case .vector_object_marker: return "vector_object_marker"
                case .dictionary_marker: return "dictionary_marker"
                }
            }
        }
    }
}

class AMF {
    
    enum ValueType : UInt8, CustomDebugStringConvertible {
        case number = 0
        case boolean = 1
        case string = 2
        case object = 3
        case null = 5
        case map = 8
        case end_of_object = 9
        case array = 10
        case date = 11
        case long_string = 12
        
        //case amf3_marker = 0x11
        
        case root = 99
        
        var debugDescription: String {
            get {
                switch self {
                case .number: return "number"
                case .boolean: return "boolean"
                case .string: return "string"
                case .object: return "object"
                case .null: return "null"
                case .map: return "map"
                case .end_of_object: return "end_of_object"
                case .array: return "array"
                case .date: return "date"
                case .long_string: return "long_string"
                case .root: return "root"
                }
            }
        }
    }
    
    class Value : CustomDebugStringConvertible, Equatable {
        var debugDescription: String { type.debugDescription }
        var universalValue: Any? { return nil }
        var type: AMF.ValueType
        init(type: AMF.ValueType) {
            self.type = type
        }
        
        func pack(to:RTMPStream) -> Bool {
            to.writeUInt8(type.rawValue)
            return true
        }
        
        static func ==(a: Value, b: Value) -> Bool {
            switch (a.type, b.type) {
            case (.null, .null), (.end_of_object, .end_of_object): return true
            case (.string, .string), (.long_string, .long_string): return (a as! StringValue).value == (b as! StringValue).value
            case (.number, .number): return (a as! NumberValue).value == (b as! NumberValue).value
            case (.boolean, .boolean): return (a as! BooleanValue).value == (b as! BooleanValue).value
            case (.map, .map), (.object, .object): return (a as! ObjectValue).values == (b as! ObjectValue).values
            case (.array, .array): return (a as! ArrayValue).values == (b as! ArrayValue).values
            //case (.date, .date): return (a as! DateValue) == (b as! DateValue)
            default:
                return false
            }
        }
    }
    
    static func castAnyToValue(_ value: Any?) -> Value {
        if value == nil {
            return NullValue()
        } else if let strValue = value as? String {
            return StringValue(strValue)
        } else if let intValue = value as? Int {
            return NumberValue(intValue)
        } else if let doubleValue = value as? Double {
            return NumberValue(doubleValue)
        } else if let floatValue = value as? Float {
            return NumberValue(Double(floatValue))
        } else if let boolValue = value as? Bool {
            return BooleanValue(boolValue)
        } else if let arrayValue = value as? [Any] {
            return ArrayValue(arrayValue)
        } else if let dictValue = value as? [String:Any] {
            return ObjectValue(dictValue)
        } else if let directValue = value as? Value {
            return directValue
        } else {
            return NullValue()
        }
    }
    
    static func castValueToAny(_ value: Value) -> Any? {
        switch value.type {
        case .number: return (value as! NumberValue).value
        case .null: return nil
        default:
            return nil
        }
    }
    
    static func unpackValue(from: RTMPStream) -> Value? {
        if let typeRawValue = from.readUInt8() {
            if let type = ValueType(rawValue: typeRawValue) {
                var value: Value?
                switch type {
                case .number: value = NumberValue(from: from)
                case .string, .long_string: value = StringValue(from: from, type: type)
                case .null: value = NullValue()
                case .end_of_object: value = EndOfObjectValue()
                case .boolean: value = BooleanValue(from: from)
                case .array: value = ArrayValue(from: from, type: type)
                case .date: value = DateValue(from: from)
                case .object, .map: value = ObjectValue(from: from, type: type)
                case .root: return nil
                }
                return value
            } else {
                print("[ERROR] AMF Invalid type: \(typeRawValue)")
            }
        }
        return nil
    }
    
    static func packValue(_ value: Value, to: RTMPStream) -> Bool {
        return value.pack(to: to)
    }
    
    class StringValue : Value {
        var value: String
        override var debugDescription: String { value }
        override var universalValue: Any? { value }
        init(_ value: String) {
            self.value = value
            if value.count > 65535 {
                super.init(type: .long_string)
            } else {
                super.init(type: .string)
            }
        }
        
        convenience init?(from: RTMPStream, type: ValueType) {
            var value: String? = nil
            if type == .string {
                value = from.readString()
            } else if type == .long_string {
                value = from.readLongString()
            }
            guard value != nil else { return nil }
            self.init(value!)
        }
        
        override func pack(to: RTMPStream) -> Bool {
            if !super.pack(to: to) { return false }
            if self.type == .string {
                return to.writeString(value)
            } else if self.type == .long_string {
                return to.writeLongString(value)
            }
            return false
        }
    }
    
    class NumberValue : Value {
        var value: Double
        var intValue: Int { Int(value) }
        override var debugDescription: String { String(value) }
        override var universalValue: Any? { value }
        
        init(_ value: Double) {
            self.value = value
            super.init(type: .number)
        }
        
        init(_ value: Int) {
            self.value = Double(value)
            super.init(type: .number)
        }
        
        convenience init?(from: RTMPStream) {
            if let value = from.readDouble() {
                self.init(value)
            } else {
                return nil
            }
        }
        
        override func pack(to: RTMPStream) -> Bool {
            if !super.pack(to: to) { return false }
            to.writeDouble(value)
            return true
        }
    }
    
    class BooleanValue : Value {
        var value: Bool
        override var debugDescription: String { String(value) }
        override var universalValue: Any? { value }
        
        init(_ value: Bool) {
            self.value = value
            super.init(type: .boolean)
        }
        
        convenience init?(from: RTMPStream) {
            if let value = from.readUInt8() {
                self.init(value == 1)
            } else {
                return nil
            }
        }
        
        override func pack(to: RTMPStream) -> Bool {
            if !super.pack(to: to) { return false }
            to.writeUInt8(value ? 1 : 0)
            return true
        }
    }
    
    class NullValue : Value {
        override var debugDescription: String { "(null)" }
        init() { super.init(type: .null) }
    }
    
    class EndOfObjectValue : Value {
        override var debugDescription: String { "(End Of Object Mark)" }
        init() { super.init(type: .end_of_object) }
    }
    
    class ArrayValue : Value {
        var values: [Value] = []
        fileprivate func unpackArray(from: RTMPStream) -> Bool {
            while !from.eof {
                if let value = AMF.unpackValue(from: from) {
                    if value.type == .end_of_object { break }
                    self.values.append(value)
                } else {
                    return false
                }
            }
            return true
        }
        
        fileprivate func packArray(to: RTMPStream) -> Bool {
            for value in values {
                if !value.pack(to: to) { return false }
            }
            return true
        }
        
        init() { super.init(type: .array) }
        init(asRoot: Bool) { super.init(type: asRoot ? .root : .array) }
        
        init?(from: RTMPStream, type: ValueType) {
            if type == .array {
                if let arrayLength = from.readUInt32() {
                    values.reserveCapacity(Int(arrayLength))
                } else {
                    return nil
                }
            }
            super.init(type: type)
            if !unpackArray(from: from) { return nil }
        }
        
        init(_ values:[Any?], asRoot: Bool = false) {
            for value in values {
                self.values.append(AMF.castAnyToValue(value))
            }
            super.init(type: asRoot ? .root : .array)
        }
        
        override func pack(to: RTMPStream) -> Bool {
            if self.type == .array {
                if !super.pack(to: to) { return false }
                to.writeUInt32(UInt32(values.count))
                
                if !packArray(to: to) { return false }
                /**
                 pack end of object mark
                 */
                to.writeUInt8(ValueType.end_of_object.rawValue)
                
                return true
            } else {
                return packArray(to: to)
            }
        }
        
        func addValue(_ value: String) { values.append(StringValue(value)) }
        func addValue(_ value: Int) { values.append(NumberValue(value)) }
        func addValue(_ value: Double) { values.append(NumberValue(value)) }
        func addValue(_ value: Bool) { values.append(BooleanValue(value)) }
        func addValue(_ value: [Any?]) { values.append(ArrayValue(value))}
        func addValue(_ value: [String:Any?]) { values.append(ObjectValue(value, asMap: true))}
        func addObjectValue() -> ObjectValue { let value = ObjectValue();values.append(value);return value }
        func addObjectValue(_ value: [String:Any?]) -> ObjectValue { let objectValue = ObjectValue(value);values.append(objectValue);return objectValue }
        
        func packData() -> Data? {
            if self.type != .root { return nil }
            let to = RTMPStream(capacity: 1024)
            if !self.pack(to: to) { return nil }
            return to.data
        }
    }
    
    static func RootValue() -> ArrayValue { return ArrayValue(asRoot: true) }
    static func RootValue(_ value:[Any?]) -> ArrayValue { return ArrayValue(value, asRoot: true) }
    static func RootValue(from: RTMPStream) -> ArrayValue? { return ArrayValue(from: from, type: .root) }
    
    class DateValue : Value {
        init?(from: RTMPStream) {
            if let zone = from.readUInt16(), let part0 = from.readUInt32(), let part1 = from.readUInt32() {
                print("DATE ZONE \(zone) PART0 \(part0) PART1 \(part1)")
                super.init(type: .date)
            }
            return nil
        }
    }
    
    class ObjectValue : Value {
        var values: Dictionary<String, Value> = [:]
        init() { super.init(type: .object) }
        init(asMap: Bool) { super.init(type: asMap ? .map : .object) }
        init?(from: RTMPStream, type: ValueType) {
            if type == .map {
                if from.readUInt32() == nil { return nil }
            }
            while !from.eof {
                if let name = from.readString() {
                    if let value = AMF.unpackValue(from: from) {
                        if value.type == .end_of_object {
                            break
                        }
                        values[name] = value
                        continue
                    }
                }
                return nil
            }
            super.init(type: type)
        }
        
        init(_ dict: [String:Any?], asMap: Bool = false) {
            for kv in dict {
                self.values[kv.key] = AMF.castAnyToValue(kv.value)
            }
            super.init(type: asMap ? .map : .object)
        }
        
        func addValue(_ name: String, value: String) { values[name] = StringValue(value) }
        func addValue(_ name: String, value: Double) { values[name] = NumberValue(value) }
        func addValue(_ name: String, value: Int) { values[name] = NumberValue(value) }
        func addValue(_ name: String, value: Bool) { values[name] = BooleanValue(value) }
        func addValue(_ name: String, value: [String:Any?]) { values[name] = ObjectValue(value, asMap: true) }
        func addValue(_ name: String, value: [Any?]) { values[name] = ArrayValue(value) }
        func addObjectValue(_ name: String) -> ObjectValue { let objectValue = ObjectValue(); values[name] = objectValue; return objectValue }
        func addObjectValue(_ name: String, value: [String:Any?]) -> ObjectValue { let objectValue = ObjectValue(value, asMap: false); values[name] = objectValue; return objectValue }

        subscript(name:String) -> Value? {
            get { values[name] }
            set { values[name] = newValue}
        }
        
        override func pack(to: RTMPStream) -> Bool {
            if !super.pack(to: to) { return false }
            if self.type == .map {
                to.writeUInt32(UInt32(values.count))
            }
            for kv in values {
                if !to.writeString(kv.key) { return false }
                if !kv.value.pack(to: to) { return false }
            }
            /**
             pack end of object mark
             */
            if !to.writeString("") { return false }
            to.writeUInt8(ValueType.end_of_object.rawValue)
            return true
        }
    }
}


