//
//  NWError.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation



public enum NWProxyError : Error, Hashable {
    case wrong_version
    case auth_failed
    case auth_method_not_accept
    case connect_failed(Int32)
    case read_error
    case write_error
    case unknown(Int)
    case warped(Error)
    
    public static func == (a:NWProxyError, b:NWProxyError) -> Bool {
        switch(a,b) {
        case (.wrong_version, .wrong_version), (.auth_failed, .auth_failed), (.auth_method_not_accept, .auth_method_not_accept), (.read_error, .read_error), (.write_error, .write_error):
            return true
        case let (.connect_failed(code1), .connect_failed(code2)) where code1 == code2:
            return true
        case let (.unknown(code1), .unknown(code2)) where code1 == code2:
            return true
        //case let (.warped(e1), .warped(e2)) where e1 == e2: return true
        default:
            return false
        }
    }
    
    public func hash(into hasher:inout Hasher) {
        switch self {
        case .wrong_version:
            hasher.combine(0)
        case .auth_failed:
            hasher.combine(1)
        case .auth_method_not_accept:
            hasher.combine(2)
        case .connect_failed(let code):
            hasher.combine(3)
            hasher.combine(code)
        case .read_error:
            hasher.combine(4)
        case .write_error:
            hasher.combine(5)
        case .unknown(let code):
            hasher.combine(6)
            hasher.combine(code)
        case .warped(_):
            hasher.combine(7)
            //hasher.combine(e)
        }
    }
}
/// NWError is a type to deliver error codes relevant to NWConnection and NWListener objects.
/// Generic connectivity errors will be delivered in the posix domain, resolution errors will
/// be delivered in the dns domain, and security errors will be delivered in the tls domain.
//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public enum NWError : Error, CustomDebugStringConvertible, Equatable, Hashable {

    /// The error code will be a POSIX error as defined in <sys/errno.h>
    case posix(Int32)
    
    case proxy(NWProxyError)

    /// The error code will be a DNSServiceErrorType error as defined in <dns_sd.h>
    //case dns(DNSServiceErrorType)
    
    case resolve(NWResolver.ResolveError)

    /// The error code will be a TLS error as defined in <Security/SecureTransport.h>
    case tls(OSStatus)
    
    /// Unknown error code
    case unknown(Int32)
    
    case graceful_close
    
    case none
    
    public static let wouldBlock = NWError.posix(EWOULDBLOCK)
    public static let again = NWError.posix(EAGAIN)
    public static let inProgress = NWError.posix(EINPROGRESS)

    init(posixError:Int32) {
        self = .posix(posixError)
    }
    
    init(posixErrorCode:POSIXErrorCode) {
        let errNO = posixErrorCode.rawValue
        self = .posix(errNO)
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
            case .proxy(let e):
                return "proxyError(\(e))"
            case .posix(let code):
                let desc = String(cString:strerror(code))
                return "posixError(\(code) - \(desc))"
            case .resolve(let e):
                return "resolveError(\(e))"
            case .tls(let osstatus):
                return "tlsError(\(osstatus))"
            case .unknown(let code):
                return "unknownError(\(code))"
            case .graceful_close:
                return "graceful_close"
            case .none:
                return "none"
//                default:
//                    break
            }
//                return ""
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
    public static func == (a: NWError, b: NWError) -> Bool {
        switch (a,b) {
        case let (.posix(code1), .posix(code2)) where code1 == code2:
            return true
        case let (.resolve(code1), .resolve(code2)) where code1 == code2:
            return true
        case let (.tls(code1), .tls(code2)) where code1 == code2:
            return true
        case let (.unknown(code1), .unknown(code2)) where code1 == code2:
            return true
        case let (.proxy(code1), .proxy(code2)) where code1 == code2:
            return true
        case (.none, .none), (.graceful_close, .graceful_close):
            return true
        default:
            return false
        }
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
        case .proxy(let code):
            hasher.combine(".proxy")
            hasher.combine(code)
        case .posix(let code):
            hasher.combine(".posix")
            hasher.combine(code)
        case .resolve(let e):
            hasher.combine(".resolve")
            hasher.combine(e)
        case .tls(let osstatus):
            hasher.combine(".tls")
            hasher.combine(osstatus)
        case .unknown(let code):
            hasher.combine(".unknown")
            hasher.combine(code)
        case .graceful_close:
            hasher.combine(".graceful_close")
        case .none:
            hasher.combine(".none")
        }
    }
}
