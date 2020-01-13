//
//  NWEndPoint.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public enum NWEndpoint : Hashable, CustomDebugStringConvertible {

    /// A host port endpoint represents an endpoint defined by the host and port.
    case hostPort(NWEndpoint.Host,NWEndpoint.Port)
    
    /// Resolved Endpoint
    case sockAddrs([NWSockAddr])

    /// A Host is a name or address
    public enum Host : Hashable, CustomDebugStringConvertible, ExpressibleByStringLiteral {

        /// A type that represents a string literal.
        ///
        /// Valid types for `StringLiteralType` are `String` and `StaticString`.
        public typealias StringLiteralType = String

        public func hash(into hasher: inout Hasher) {
            switch self {
            case let .name(_name, _interface):
                hasher.combine(_name)
                hasher.combine(_interface)
            case let .ipv4(v4addr):
                hasher.combine(v4addr)
            case let .ipv6(v6addr):
                hasher.combine(v6addr)
            }
        }

        /// A host specified as a name and optional interface scope
        case name(String, NWInterface?)

        /// A host specified as an IPv4 address
        case ipv4(IPv4Address)

        /// A host specified an an IPv6 address
        case ipv6(IPv6Address)

        /// Creates an instance initialized to the given string value.
        ///
        /// - Parameter value: The value of the new instance.
        public init(stringLiteral: NWEndpoint.Host.StringLiteralType) {
            self.init(stringLiteral)
        }

        /// Create a host from a string.
        ///
        /// This is the preferred way to create a host. If the string is an IPv4 address literal ("198.51.100.2"), an
        /// IPv4 host will be created. If the string is an IPv6 address literal ("2001:DB8::2", "fe80::1%lo", etc), an IPv6
        /// host will be created. If the string is an IPv4 mapped IPv6 address literal ("::ffff:198.51.100.2") an IPv4
        /// host will be created. Otherwise, a named host will be created.
        ///
        /// - Parameter string: An IPv4 address literal, an IPv6 address literal, or a hostname.
        /// - Returns: A Host object
        public init(_ string: String) {
            if let v4Addr = IPv4Address(string) {
                self = .ipv4(v4Addr)
            } else if let v6Addr = IPv6Address(string) {
                self = .ipv6(v6Addr)
            } else {
                self = .name(string, nil)
            }
        }

        /// Returns the interface the host is scoped to if any
        public var interface: NWInterface? {
            get {
                if case let .name(_, _interface) = self {
                    return _interface
                }
                return nil
            }
        }

        
        public var debugDescription: String {
            get {
                switch self {
                case let .ipv4(v4addr):
                    return v4addr.debugDescription
                case let .ipv6(v6addr):
                    return v6addr.debugDescription
                case let .name(name, interface):
                    return name + "-" + (interface?.debugDescription ?? "<all interfaces>")
                }
            }
        }

        public static func == (a: NWEndpoint.Host, b: NWEndpoint.Host) -> Bool {
            switch (a,b) {
            case let (.name(name1, interface1), .name(name2, interface2))
                where (name1 == name2 && interface1 == interface2):
                return true
            case let (.ipv4(v4addr1), .ipv4(v4addr2))
                where v4addr1 == v4addr2:
                return true
            case let (.ipv6(v6addr1), .ipv6(v6addr2))
                where v6addr1 == v6addr2:
                return true
            default:
                return false
            }
        }

        /// A type that represents an extended grapheme cluster literal.
        ///
        /// Valid types for `ExtendedGraphemeClusterLiteralType` are `Character`,
        /// `String`, and `StaticString`.
        public typealias ExtendedGraphemeClusterLiteralType = NWEndpoint.Host.StringLiteralType

        /// A type that represents a Unicode scalar literal.
        ///
        /// Valid types for `UnicodeScalarLiteralType` are `Unicode.Scalar`,
        /// `Character`, `String`, and `StaticString`.
        public typealias UnicodeScalarLiteralType = NWEndpoint.Host.StringLiteralType
    }

    /// A network port (TCP or UDP)
    public struct Port : Hashable, CustomDebugStringConvertible, ExpressibleByIntegerLiteral, RawRepresentable {

        /// A type that represents an integer literal.
        ///
        /// The standard library integer and floating-point types are all valid types
        /// for `IntegerLiteralType`.
        public typealias IntegerLiteralType = UInt16

        public static let any: NWEndpoint.Port = 0

        public static let ssh: NWEndpoint.Port = 22

        public static let smtp: NWEndpoint.Port = 25

        public static let http: NWEndpoint.Port = 80

        public static let pop: NWEndpoint.Port = 110

        public static let imap: NWEndpoint.Port = 143

        public static let https: NWEndpoint.Port = 443

        public static let imaps: NWEndpoint.Port = 993

        public static let socks: NWEndpoint.Port = 1080

        /// The corresponding value of the raw type.
        ///
        /// A new instance initialized with `rawValue` will be equivalent to this
        /// instance. For example:
        ///
        ///     enum PaperSize: String {
        ///         case A4, A5, Letter, Legal
        ///     }
        ///
        ///     let selectedSize = PaperSize.Letter
        ///     print(selectedSize.rawValue)
        ///     // Prints "Letter"
        ///
        ///     print(selectedSize == PaperSize(rawValue: selectedSize.rawValue)!)
        ///     // Prints "true"
        public var rawValue: UInt16

        /// Create a port from a string.
        ///
        /// Supports common service names such as "http" as well as number strings such as "80".
        ///
        /// - Parameter service: A service string such as "http" or a number string such as "80"
        /// - Returns: A port if the string can be converted to a port, nil otherwise.
        public init?(_ service: String) {
            switch service {
            case "http":
                self.rawValue = 80
            case "https":
                self.rawValue = 443
            case "ssh":
                self.rawValue = 22
            case "smtp":
                self.rawValue = 25
            case "pop":
                self.rawValue = 110
            case "imap":
                self.rawValue = 143
            case "imaps":
                self.rawValue = 993
            case "socks":
                self.rawValue = 1080
            default:
                return nil
            }
        }

        /// Creates an instance initialized to the specified integer value.
        ///
        /// Do not call this initializer directly. Instead, initialize a variable or
        /// constant using an integer literal. For example:
        ///
        ///     let x = 23
        ///
        /// In this example, the assignment to the `x` constant calls this integer
        /// literal initializer behind the scenes.
        ///
        /// - Parameter value: The value to create.
        public init(integerLiteral value: NWEndpoint.Port.IntegerLiteralType) {
            self.rawValue = value
        }

        /// Creates a new instance with the specified raw value.
        ///
        /// If there is no value of the type that corresponds with the specified raw
        /// value, this initializer returns `nil`. For example:
        ///
        ///     enum PaperSize: String {
        ///         case A4, A5, Letter, Legal
        ///     }
        ///
        ///     print(PaperSize(rawValue: "Legal"))
        ///     // Prints "Optional("PaperSize.Legal")"
        ///
        ///     print(PaperSize(rawValue: "Tabloid"))
        ///     // Prints "nil"
        ///
        /// - Parameter rawValue: The raw value to use for the new instance.
        public init?(rawValue: UInt16) {
            self.init(integerLiteral: rawValue)
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
        public var debugDescription: String { get{
            return String(format:"%u", rawValue)
            } }

        /// The raw type that can be used to represent all values of the conforming
        /// type.
        ///
        /// Every distinct value of the conforming type has a corresponding unique
        /// value of the `RawValue` type, but there may be values of the `RawValue`
        /// type that don't have a corresponding value of the conforming type.
        public typealias RawValue = UInt16
    }

    /// Returns the interface the endpoint is scoped to if any
    public var interface: NWInterface? {
        switch self {
        case let .hostPort(host, _):
            return host.interface
        default:
            return nil
        }
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
        switch self {
        case let .hostPort(host, port):
            hasher.combine(host)
            hasher.combine(port)
        case let .sockAddrs(addrs):
            for addr in addrs {
                hasher.combine(addr)
            }
        }
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
            switch self {
            case let .hostPort(host, port):
                return host.debugDescription + ":" + port.debugDescription
            case let .sockAddrs(addrs):
                var s = "sockAddrs ["
                var i = 0
                for addr in addrs {
                    if i > 0 {
                        s += ","
                    }
                    i += 1
                    s += addr.debugDescription
                }
                s += "]"
                
                return s
            }
        }
    }
    
    
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (a: NWEndpoint, b: NWEndpoint) -> Bool {
        switch (a,b) {
        case let (.hostPort(host1,port1), .hostPort(host2, port2))
            where host1 == host2 && port1 == port2:
            return true
        default:
            return false
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
        }
    }
    
    public var hostName: String? {
        get {
            if case let .hostPort(host, _) = self {
                switch host {
                case let .ipv4(v4Addr): return v4Addr.getStringValue()
                case let .ipv6(v6Addr): return v6Addr.getStringValue()
                case let .name(name, _): return name
                }
            }
            return nil
        }
    }
    
    public var family:Int32 {
        get {
            if case let .hostPort(host, _) = self {
                switch host {
                case .ipv4(_):
                    return AF_INET
                case .ipv6(_):
                    return AF_INET6
                default:
                    break
                }
            }
            return AF_UNSPEC
        }
    }
    
    public var IPv4Addr:sockaddr_in? {
        get {
            if case let .hostPort(host, port) = self {
                switch host {
                case let .ipv4(v4addr):
                    return sockaddr_in(sin_len: UInt8(MemoryLayout<sockaddr_in>.size), sin_family: sa_family_t(AF_INET), sin_port: in_port_t(port.rawValue.byteSwapped), sin_addr: v4addr.addr, sin_zero: (0,0,0,0,0,0,0,0))
                default:
                    break
                }
            }
            return nil
        }
    }
    
    public var IPv6Addr:sockaddr_in6? {
        get {
            if case let .hostPort(host, port) = self {
                switch host {
                case let .ipv6(v6addr):
                    return sockaddr_in6(sin6_len: UInt8(MemoryLayout<sockaddr_in6>.size), sin6_family: sa_family_t(AF_INET6), sin6_port: in_port_t(port.rawValue.byteSwapped), sin6_flowinfo: 0, sin6_addr: v6addr.rawValue.withUnsafeBytes({ (ptr) -> in6_addr in
                        return ptr.load(as: in6_addr.self)
                    }), sin6_scope_id: 0)
                default:
                    break
                }
            }
            return nil
        }
    }
}


