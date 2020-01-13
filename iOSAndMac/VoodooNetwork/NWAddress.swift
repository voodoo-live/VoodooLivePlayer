//
//  NWAddress.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public protocol IPAddress {

    /// Fetch the raw address as data
    var rawValue: Data { get }

    /// Create an IP address from data. The length of the data must
    /// match the expected length of addresses in the address family
    /// (four bytes for IPv4, and sixteen bytes for IPv6)
    init?(_ rawValue: Data, _ interface: NWInterface?)

    /// Create an IP address from an address literal string.
    /// If the string contains '%' to indicate an interface, the interface will be
    /// associated with the address, such as "::1%lo0" being associated with the loopback
    /// interface.
    /// This function does not perform host name to address resolution. This is the same as calling getaddrinfo
    /// and using AI_NUMERICHOST.
    init?(_ string: String)

    /// The interface the address is scoped to, if any.
    var interface: NWInterface? { get }

    /// Indicates if this address is loopback
    var isLoopback: Bool { get }

    /// Indicates if this address is link-local
    var isLinkLocal: Bool { get }

    /// Indicates if this address is multicast
    var isMulticast: Bool { get }
}


    /// IPv4Address
    /// Base type to hold an IPv4 address and convert between strings and raw bytes.
    /// Note that an IPv4 address may be scoped to an interface.
    //@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    public struct IPv4Address : IPAddress, Hashable, CustomDebugStringConvertible {

        /// The IPv4 any address used for listening
        public static let any: IPv4Address = IPv4Address("0.0.0.0")!

        /// The IPv4 broadcast address used to broadcast to all hosts
        public static let broadcast: IPv4Address = IPv4Address("255.255.255.255")!

        /// The IPv4 loopback address
        public static let loopback: IPv4Address = IPv4Address("127.0.0.1")!

        /// The IPv4 all hosts multicast group
        public static let allHostsGroup: IPv4Address = IPv4Address("")!

        /// The IPv4 all routers multicast group
        public static let allRoutersGroup: IPv4Address = IPv4Address("")!

        /// The IPv4 all reports multicast group for ICMPv3 membership reports
        public static let allReportsGroup: IPv4Address = IPv4Address("")!

        /// The IPv4 multicast DNS group. (Note: Use the dns_sd APIs instead of creating your own responder/resolver)
        public static let mdnsGroup: IPv4Address = IPv4Address("")!

        /// Indicates if this IPv4 address is loopback (127.0.0.1)
        public var isLoopback: Bool {
            get{
                return (UInt32(self.addr.s_addr) & 0x00ffffff) == 0x0000007f
            }
        }

        /// Indicates if this IPv4 address is link-local
        public var isLinkLocal: Bool { get{false} }

        /// Indicates if this IPv4 address is multicast
        public var isMulticast: Bool { get{false} }

        
        

        /// Create an IPv4 address from a 4-byte data. Optionally specify an interface.
        ///
        /// - Parameter rawValue: The raw bytes of the IPv4 address, must be exactly 4 bytes or init will fail.
        /// - Parameter interface: An optional network interface to scope the address to. Defaults to nil.
        /// - Returns: An IPv4Address or nil if the Data parameter did not contain an IPv4 address.
        public init?(_ rawValue: Data, _ interface: NWInterface? = nil) {
            guard rawValue.count == 4 else { return nil }
            self.addr = rawValue.withUnsafeBytes({ (ptr) -> in_addr in
                return ptr.load(as: in_addr.self)
            })
            self.interface = interface
        }

        /// Create an IPv4 address from an address literal string.
        ///
        /// This function does not perform host name to address resolution. This is the same as calling getaddrinfo
        /// and using AI_NUMERICHOST.
        ///
        /// - Parameter string: An IPv4 address literal string such as "127.0.0.1", "169.254.8.8%en0".
        /// - Returns: An IPv4Address or nil if the string parameter did not
        /// contain an IPv4 address literal.
        public init?(_ string: String) {
            var addrPart:String
            var interfacePart:String?
            if let spIndex = string.firstIndex(of: "%") {
                addrPart = String(string[..<spIndex])
                interfacePart = String(string[string.index(spIndex, offsetBy: 1)..<string.endIndex])
            } else {
                addrPart = string
            }
            var inaddr = in_addr()
            if inet_aton(addrPart.cString(using: .utf8), &inaddr) == 0 {
                return nil
            }
            self.addr = inaddr
            self.interface = interfacePart == nil ? nil : NWInterface.fromName(name: interfacePart!)
        }
        
        public init(_ addr:in_addr, interface:NWInterface? = nil) {
            self.addr = addr
            self.interface = interface
        }

        /// The address
        public let addr: in_addr

        /// The interface the address is scoped to, if any.
        public let interface: NWInterface?
        
        
        /// Fetch the raw address (four bytes)
        public var rawValue: Data { get {Data(bytes:withUnsafePointer(to: self.addr, {$0}), count: MemoryLayout<in_addr>.size)} }
        
        public var stringValue: String {
            get {
                return getStringValue()
            }
        }
        
        public func getStringValue() -> String {
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            if inet_ntop(AF_INET, withUnsafePointer(to: self.addr, {$0}), &buffer, socklen_t(INET_ADDRSTRLEN)) == nil {
                return ""
            } else {
                return String(cString: buffer)
            }
        }
        
        public func withMask(maskBits:Int) -> IPv4Address {
            let addrValue = UInt32(self.addr.s_addr)
            let maskValue = UInt32((UInt64(1) << maskBits) - 1)
            let calcAddr = in_addr(s_addr: in_addr_t(addrValue & maskValue))
            return IPv4Address(calcAddr)
        }
        
        
        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (lhs: IPv4Address, rhs: IPv4Address) -> Bool {
            let p1 = withUnsafePointer(to: lhs.addr, {$0})
            let p2 = withUnsafePointer(to: rhs.addr, {$0})
            
            if memcmp(p1, p2, MemoryLayout<in_addr>.size) == 0 {
                switch (lhs.interface, rhs.interface) {
                case (nil, nil):
                    return true
                case let (v1, v2) where v1 != nil && v2 != nil && v1 == v2:
                    return true
                default:
                    break
                }
            }
            return false
        }

        /// Hashes the essential components of this value by feeding them into the
        /// given hasher.
        ///
        /// Implement this method to conform to the `Hashable` protocol. The
        /// components used for hashing must be the same as the components compared
        /// in your type's `==` operator implementation. Call `hasher.combine(_:)`
        /// with each of these components.
        ///
        /// - Important: Never call `finalize()` on `hasher`. Doing so may become a
        ///   compile-time error in the future.
        ///
        /// - Parameter hasher: The hasher to use when combining the components
        ///   of this instance.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(addr.s_addr)
            hasher.combine(interface?.name ?? "")
        }

        /// A textual representation of this instance, suitable for debugging.
        ///
        /// Calling this property directly is discouraged. Instead, convert an
        /// instance of any type to a string by using the `String(reflecting:)`
        /// initializer. This initializer works with any type, and uses the custom
        /// `debugDescription` property for types that conform to
        /// `CustomDebugStringConvertible`:
        ///
        ///     struct Point: CustomDebugStringConvertible {
        ///         let x: Int, y: Int
        ///
        ///         var debugDescription: String {
        ///             return "(\(x), \(y))"
        ///         }
        ///     }
        ///
        ///     let p = Point(x: 21, y: 30)
        ///     let s = String(reflecting: p)
        ///     print(s)
        ///     // Prints "(21, 30)"
        ///
        /// The conversion of `p` to a string in the assignment to `s` uses the
        /// `Point` type's `debugDescription` property.
        public var debugDescription: String {
            get {
                return String(format:"%u.%u.%u.%u", addr.s_addr & 0xff, (addr.s_addr & 0xff00)>>8, (addr.s_addr & 0xff0000)>>16, (addr.s_addr & 0xff000000)>>24) + (self.interface == nil ? "" : "%") + (self.interface?.name ?? "")
            }
        }

        /// The hash value.
        ///
        /// Hash values are not guaranteed to be equal across different executions of
        /// your program. Do not save hash values to use during a future execution.
        ///
        /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
        ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
        public var hashValue: Int {
            get {
                
                var hasher = Hasher()
                hash(into: &hasher)
                return hasher.finalize()

                //let v = UnsafeRawPointer(&in6addr_any)
                //let a = UnsafePointer<in6_addr>.init(T##from: OpaquePointer##OpaquePointer)
                //let addr = withUnsafePointer(to: &in6addr_any, {$0})
            }
        }
    }

    /// IPv6Address
    /// Base type to hold an IPv6 address and convert between strings and raw bytes.
    /// Note that an IPv6 address may be scoped to an interface.
    //@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
    public struct IPv6Address : IPAddress, Hashable, CustomDebugStringConvertible {

        /// IPv6 any address
        public static let any: IPv6Address = IPv6Address(in6addr_any)

        /// IPv6 broadcast address
        public static let broadcast: IPv6Address = IPv6Address("ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff")!

        /// IPv6 loopback address
        public static let loopback: IPv6Address = IPv6Address(in6addr_loopback)

        /// IPv6 all node local nodes multicast
        public static let nodeLocalNodes: IPv6Address = IPv6Address(in6addr_nodelocal_allnodes)

        /// IPv6 all link local nodes multicast
        public static let linkLocalNodes: IPv6Address = IPv6Address(in6addr_linklocal_allnodes)

        /// IPv6 all link local routers multicast
        public static let linkLocalRouters: IPv6Address = IPv6Address(in6addr_linklocal_allrouters)
        
        /// IPv6 all link local routers multicast
        public static let linkLocalV2Routers: IPv6Address = IPv6Address(in6addr_linklocal_allv2routers)

        public enum Scope : UInt8 {

            case nodeLocal

            case linkLocal

            case siteLocal

            case organizationLocal

            case global


        }

        /// Is the Any address "::0"
        public var isAny: Bool { get {false} }

        /// Is the looback address "::1"
        public var isLoopback: Bool { get {false} }

        /// Is an IPv4 compatible address
        public var isIPv4Compatabile: Bool { get {false} }

        /// Is an IPv4 mapped address such as "::ffff:1.2.3.4"
        public var isIPv4Mapped: Bool { get {false} }

        /// For IPv6 addresses that are IPv4 mapped, returns the IPv4 address
        ///
        /// - Returns: nil unless the IPv6 address was mapped or compatible, in which case the IPv4 address is
        /// returned.
        public var asIPv4: IPv4Address? { get {nil} }

        /// Is a 6to4 IPv6 address
        public var is6to4: Bool { get {false} }

        /// Is a link-local address
        public var isLinkLocal: Bool { get {false} }

        /// Is multicast
        public var isMulticast: Bool { get {false} }

        /// Returns the multicast scope
        public var multicastScope: IPv6Address.Scope? { get {.global} }

        /// Create an IPv6 from a raw 16 byte value and optional interface
        ///
        /// - Parameter rawValue: A 16 byte IPv6 address
        /// - Parameter interface: An optional interface the address is scoped to. Defaults to nil.
        /// - Returns: nil unless the raw data contained an IPv6 address
        public init?(_ rawValue: Data, _ interface: NWInterface? = nil) {
            guard rawValue.count == 16 else { return nil }
            self.addr = rawValue.withUnsafeBytes({ (ptr) -> in6_addr in
                return ptr.load(as: in6_addr.self)
            })
            self.interface = interface
        }
        
        
        public init(_ addr: in6_addr, _ interface: NWInterface? = nil) {
            self.addr = addr
            self.interface = interface
        }

        /// Create an IPv6 address from a string literal such as "fe80::1%lo0" or "2001:DB8::5"
        ///
        /// This function does not perform hostname resolution. This is similar to calling getaddrinfo with
        /// AI_NUMERICHOST.
        ///
        /// - Parameter string: An IPv6 address literal string.
        /// - Returns: nil unless the string contained an IPv6 literal
        public init?(_ string: String) {
            var addrPart:String
            var interfacePart:String?
            if let spIndex = string.firstIndex(of: "%") {
                addrPart = String(string[..<spIndex])
                interfacePart = String(string[string.index(spIndex, offsetBy: 1)..<string.endIndex])
            } else {
                addrPart = string
            }
            var addr = in6_addr()
            if inet_pton(AF_INET6, addrPart.cString(using: .utf8), &addr) <= 0 {
                return nil
            }
            self.addr = addr
            self.interface = interfacePart == nil ? nil : NWInterface.fromName(name: interfacePart!)
        }

        public let addr: in6_addr
        /// The interface the address is scoped to, if any.
        public let interface: NWInterface?

        /// Fetch the raw address (sixteen bytes)
        public var rawValue: Data { get { Data(bytes:withUnsafePointer(to: self.addr, {$0}), count: MemoryLayout<in6_addr>.size)} }

        public var stringValue: String {
            get {
                return getStringValue()
            }
        }
        
        public func getStringValue() -> String {
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            if inet_ntop(AF_INET6, withUnsafePointer(to: self.addr, {$0}), &buffer, socklen_t(INET6_ADDRSTRLEN)) == nil {
                return ""
            } else {
                return String(cString: buffer)
            }
        }
        
        public func withMask(maskBits:Int) -> IPv6Address {
            let srcData = self.rawValue
            var dstData = Data(repeating: 0, count: 16)
            var copyBytes = maskBits / 8
            var copyBits = maskBits % 8
            if copyBytes >= 16 {
                copyBytes = 16
                copyBits = 0
            }
            
            for i in 0..<copyBytes {
                dstData[i] = srcData[i]
            }
            
            if copyBits > 0 {
                let mask = UInt8((UInt32(1) << copyBits)-1)
                dstData[copyBytes] = srcData[copyBytes] & mask
            }
            
            //dstData.replaceSubrange(0..<copyBytes, with: srcData)
            
            
            return IPv6Address(dstData, self.interface)!
        }
        
        
        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (lhs: IPv6Address, rhs: IPv6Address) -> Bool {
            let p1 = withUnsafePointer(to: lhs.addr, {$0})
            let p2 = withUnsafePointer(to: rhs.addr, {$0})
            
            if memcmp(p1, p2, MemoryLayout<in6_addr>.size) == 0 {
                switch (lhs.interface, rhs.interface) {
                case (nil, nil):
                    return true
                case let (v1, v2) where v1 != nil && v2 != nil && v1 == v2:
                    return true
                default:
                    break
                }
            }
            return false
        }

        /// Hashes the essential components of this value by feeding them into the
        /// given hasher.
        ///
        /// Implement this method to conform to the `Hashable` protocol. The
        /// components used for hashing must be the same as the components compared
        /// in your type's `==` operator implementation. Call `hasher.combine(_:)`
        /// with each of these components.
        ///
        /// - Important: Never call `finalize()` on `hasher`. Doing so may become a
        ///   compile-time error in the future.
        ///
        /// - Parameter hasher: The hasher to use when combining the components
        ///   of this instance.
        public func hash(into hasher: inout Hasher) {
            hasher.combine(bytes: UnsafeRawBufferPointer(start:withUnsafePointer(to: self.addr, {$0}), count: MemoryLayout<in6_addr>.size))
            hasher.combine(self.multicastScope)
        }

        /// A textual representation of this instance, suitable for debugging.
        ///
        /// Calling this property directly is discouraged. Instead, convert an
        /// instance of any type to a string by using the `String(reflecting:)`
        /// initializer. This initializer works with any type, and uses the custom
        /// `debugDescription` property for types that conform to
        /// `CustomDebugStringConvertible`:
        ///
        ///     struct Point: CustomDebugStringConvertible {
        ///         let x: Int, y: Int
        ///
        ///         var debugDescription: String {
        ///             return "(\(x), \(y))"
        ///         }
        ///     }
        ///
        ///     let p = Point(x: 21, y: 30)
        ///     let s = String(reflecting: p)
        ///     print(s)
        ///     // Prints "(21, 30)"
        ///
        /// The conversion of `p` to a string in the assignment to `s` uses the
        /// `Point` type's `debugDescription` property.
        public var debugDescription: String {
            get {
                var descData = Data(capacity: Int(INET6_ADDRSTRLEN))
                let addrString = descData.withUnsafeMutableBytes { (ptr) -> String? in
                    let bufferPtr = ptr.baseAddress!.bindMemory(to: CChar.self, capacity: Int(INET6_ADDRSTRLEN))
                    if inet_ntop(AF_INET, withUnsafePointer(to: self.addr, {$0}), bufferPtr, socklen_t(INET6_ADDRSTRLEN)) == nil {
                        return nil
                    } else {
                        return String(cString: bufferPtr)
                    }
                }
                
                if addrString == nil {
                    return "[ERROR] IPv6Address inet_ntop:" + NWError(posixError: errno).debugDescription
                } else {
                    return addrString! + (self.interface == nil ? "" : ("%" + self.interface!.name))
                }
            }
        }

        /// The hash value.
        ///
        /// Hash values are not guaranteed to be equal across different executions of
        /// your program. Do not save hash values to use during a future execution.
        ///
        /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
        ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
        public var hashValue: Int { get {
            var hasher = Hasher()
            hash(into: &hasher)
            return hasher.finalize()
            } }
    }

//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
extension IPv6Address.Scope : Equatable {
}

//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
extension IPv6Address.Scope : Hashable {
}

public class NWSockAddr : Hashable, Equatable, CustomDebugStringConvertible {
    public var debugDescription: String {
        get {
            if family == AF_UNSPEC {
                return "<SOCKADDR UNSPEC>"
            } else if family == AF_INET {
                let ptr = asV4Ptr()
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                if inet_ntop(AF_INET, withUnsafePointer(to: ptr?.pointee.sin_addr, {$0}), &buffer, socklen_t(INET_ADDRSTRLEN)) == nil {
                    return "<inet_ntop ERROR(\(errno))"
                }
                return String(cString: buffer)
            } else if family == AF_INET6 {
                let ptr = asV6Ptr()
                var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
                if inet_ntop(AF_INET6, withUnsafePointer(to: ptr?.pointee.sin6_addr, {$0}), &buffer, socklen_t(INET6_ADDRSTRLEN)) == nil {
                    return "<inet_ntop ERROR(\(errno))"
                }
                return String(cString: buffer)
            } else {
                return "<invalid family:(\(family))"
            }
        }
    }
    
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes: asRawBufferPtr())
    }

    public static func == (a:NWSockAddr, b:NWSockAddr) -> Bool {
        if a.family == AF_UNSPEC ||
            b.family == AF_UNSPEC {
            return false
        }
        guard a.family != b.family else { return false }
        guard a.len != b.len else { return false }
        return (memcmp(a.asRawPtr(), b.asRawPtr(), Int(a.len)) == 0)
    }
    
    
    public var storage = sockaddr_storage()
    
    public init(addr:in_addr, port:UInt16) {
        setupV4(addr: addr, port: port)
    }
    
    public init(addr:in6_addr, port:UInt16, scope_id:UInt32 = 0, flowinfo:UInt32 = 0) {
        setupV6(addr: addr, port: port, scope_id: scope_id, flowinfo: flowinfo)
    }

    public init(sockaddr:sockaddr_in) {
        let ptr = self.asMutableRawBufferPtr()
        ptr.copyMemory(from: withUnsafeBytes(of: sockaddr, {$0}))
    }
    
    public init(sockaddr:sockaddr_in6) {
        let ptr = self.asMutableRawBufferPtr()
        ptr.copyMemory(from: withUnsafeBytes(of: sockaddr, {$0}))
    }
    
    public init?(data:Data) {
        let family = data.withUnsafeBytes { (ptr) -> Int32 in
            return Int32(ptr.load(as: sockaddr.self).sa_family)
        }
        
        if family == AF_INET {
            data.copyBytes(to: asMutableRawBufferPtr(), count: MemoryLayout<sockaddr_in>.size)
        } else if family == AF_INET6 {
            data.copyBytes(to: asMutableRawBufferPtr(), count: MemoryLayout<sockaddr_in6>.size)
        } else {
            return nil
        }
    }
    
    public init() { storage.ss_family = sa_family_t(AF_UNSPEC) }

    public var len: socklen_t { get { socklen_t(storage.ss_len) } }
    public var family: Int32 { get { Int32(storage.ss_family) } }
    
    public func setupV4(addr:in_addr, port:UInt16) {
        storage.ss_family = sa_family_t(AF_INET)
        let ptr = asMutableV4Ptr()
        ptr?.pointee.sin_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        ptr?.pointee.sin_addr = addr
        ptr?.pointee.sin_port = port.byteSwapped
        ptr?.pointee.sin_zero = (0,0,0,0,0,0,0,0)
    }
    
    public func setupV6(addr:in6_addr, port:UInt16, scope_id:UInt32 = 0, flowinfo:UInt32 = 0) {
        storage.ss_family = sa_family_t(AF_INET6)
        let ptr = asMutableV6Ptr()
        ptr?.pointee.sin6_len = UInt8(MemoryLayout<sockaddr_in6>.size)
        ptr?.pointee.sin6_addr = addr
        ptr?.pointee.sin6_port = port.byteSwapped
        ptr?.pointee.sin6_flowinfo = flowinfo
        ptr?.pointee.sin6_scope_id = scope_id
    }
    
    public func fromRawV4Data(data:Data) -> Bool {
        guard data.count == MemoryLayout<sockaddr_in>.size else { return false }
        data.copyBytes(to: asMutableRawBufferPtr())
        return true
    }
    
    public func fromRawV6Data(data:Data) -> Bool {
        guard data.count == MemoryLayout<sockaddr_in6>.size else { return false }
        data.copyBytes(to: asMutableRawBufferPtr())
        return true
    }
    
    public func asV4Ptr() -> UnsafePointer<sockaddr_in>? {
        guard self.storage.ss_family == AF_INET else { return nil }
        return asRawBufferPtr().bindMemory(to: sockaddr_in.self).baseAddress
    }
    
    public func asMutableV4Ptr() -> UnsafeMutablePointer<sockaddr_in>? {
        guard self.storage.ss_family == AF_INET else { return nil }
        return asMutableRawBufferPtr().bindMemory(to: sockaddr_in.self).baseAddress
    }

    public func asV6Ptr() -> UnsafePointer<sockaddr_in6>? {
        guard self.storage.ss_family == AF_INET6 else { return nil }
        return asRawBufferPtr().bindMemory(to: sockaddr_in6.self).baseAddress
    }
    
    public func asMutableV6Ptr() -> UnsafeMutablePointer<sockaddr_in6>? {
        guard self.storage.ss_family == AF_INET6 else { return nil }
        return asMutableRawBufferPtr().bindMemory(to: sockaddr_in6.self).baseAddress
    }

    public func asPtr() -> UnsafePointer<sockaddr> {
        return asRawBufferPtr().bindMemory(to: sockaddr.self).baseAddress!
    }
    
    public func asMutablePtr() -> UnsafeMutablePointer<sockaddr> {
        return asMutableRawBufferPtr().bindMemory(to: sockaddr.self).baseAddress!
    }
    
    public func asRawPtr() -> UnsafeRawPointer {
        return asRawBufferPtr().baseAddress!
    }
    
    public func asMutableRawPtr() -> UnsafeMutableRawPointer {
        return asMutableRawBufferPtr().baseAddress!
    }
    
    public func asRawBufferPtr() -> UnsafeRawBufferPointer {
        return withUnsafeBytes(of: &self.storage, {$0})
    }
    public func asMutableRawBufferPtr() -> UnsafeMutableRawBufferPointer {
        return withUnsafeMutableBytes(of: &self.storage, {$0})
    }
}
