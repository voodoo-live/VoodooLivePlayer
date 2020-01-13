//
//  MiniPath.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/28.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

/// An NWPath object represents a snapshot of network path state. This state
/// represents the known information about the local interface and routes that may
/// be used to send and receive data. If the network path for a connection changes
/// due to interface characteristics, addresses, or other attributes, a new NWPath
/// object will be generated. Note that the differences in the path attributes may not
/// be visible through public accessors, and these changes should be treated merely
/// as an indication that something about the network has changed.
@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public struct NWPath : Equatable, CustomDebugStringConvertible {

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
    public var debugDescription: String { get {""} }

    /// An NWPath status indicates if there is a usable route available upon which to send and receive data.
    public enum Status {

        /// The path has a usable route upon which to send and receive data
        case satisfied

        /// The path does not have a usable route. This may be due to a network interface being down, or due to system policy.
        case unsatisfied

        /// The path does not currently have a usable route, but a connection attempt will trigger network attachment.
        case requiresConnection

        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (a: NWPath.Status, b: NWPath.Status) -> Bool {false}

        /// The hash value.
        ///
        /// Hash values are not guaranteed to be equal across different executions of
        /// your program. Do not save hash values to use during a future execution.
        ///
        /// - Important: `hashValue` is deprecated as a `Hashable` requirement. To
        ///   conform to `Hashable`, implement the `hash(into:)` requirement instead.
        public var hashValue: Int { get {0} }

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
        public func hash(into hasher: inout Hasher) {}
    }

    public let status: NWPath.Status

    /// A list of all interfaces currently available to this path
    public let availableInterfaces: [NWInterface]

    /// Checks if the path uses an NWInterface that is considered to be expensive
    ///
    /// Cellular interfaces are considered expensive. WiFi hotspots from an iOS device are considered expensive. Other
    /// interfaces may appear as expensive in the future.
    public let isExpensive: Bool

    /// Checks if the path uses an NWInterface that is considered to be constrained
    /// by user preference
    @available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var isConstrained: Bool { get {false} }

    public let supportsIPv4: Bool

    public let supportsIPv6: Bool

    public let supportsDNS: Bool

    /// A list of IP addresses of routers acting as gateways for the path.
    @available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    public var gateways: [NWEndpoint] { get {[]} }

    /// Check the local endpoint set on a path. This will be nil for paths
    /// from an NWPathMonitor. For paths from an NWConnection, this will
    /// be set to the local address and port in use by the connection.
    public let localEndpoint: NWEndpoint?

    /// Check the remote endpoint set on a path. This will be nil for paths
    /// from an NWPathMonitor. For paths from an NWConnection, this will
    /// be set to the remote address and port in use by the connection.
    public let remoteEndpoint: NWEndpoint?

    /// Checks if the path uses an NWInterface with the specified type
    public func usesInterfaceType(_ type: NWInterface.InterfaceType) -> Bool {false}

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: NWPath, rhs: NWPath) -> Bool {false}
}

@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
extension NWPath.Status : Equatable {
}

@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
extension NWPath.Status : Hashable {
}

@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
final public class NWPathMonitor {

    /// Access the current network path tracked by the monitor
    final public var currentPath: NWPath = NWPath(status: .requiresConnection, availableInterfaces: [], isExpensive: false, supportsIPv4: false, supportsIPv6: false, supportsDNS: false, localEndpoint: nil, remoteEndpoint: nil)

    final public var pathUpdateHandler: ((NWPath) -> Void)?

    /// Start the path monitor and set a queue on which path updates
    /// will be delivered.
    /// Start should only be called once on a monitor, and multiple calls to start will
    /// be ignored.
    final public func start(queue: DispatchQueue) {}

    /// Cancel the path monitor, after which point no more path updates will
    /// be delivered.
    final public func cancel() {}

    /// Get queue used for delivering the pathUpdateHandler block.
    /// If the path monitor has not yet been started, the queue will be nil. Once the
    /// path monitor has been started, the queue will be non-nil.
    final public var queue: DispatchQueue? { get {nil} }

    /// Create a network path monitor to monitor overall network state for the
    /// system. This allows enumeration of all interfaces that are available for
    /// general use by the application.
    public init() {}

    /// Create a network path monitor that watches a single interface type.
    public init(requiredInterfaceType: NWInterface.InterfaceType) {}
}
