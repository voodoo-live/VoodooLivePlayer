//
//  NWListener.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation


final public class NWListener : NWAsyncObject, CustomDebugStringConvertible {

    final public var debugDescription: String { get {""} }

    /// Defines a service to advertise
    public struct Service : Equatable, CustomDebugStringConvertible {

        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (lhs: NWListener.Service, rhs: NWListener.Service) -> Bool {
            false
        }

        public var debugDescription: String { get {""} }

        /// Bonjour service name - if nil the system name will be used
        public let name: String?

        /// Bonjour service type
        public let type: String

        /// Bonjour service domain - if nil the system will register in all appropriate domains
        public let domain: String?

        /// A convenience Bonjour TXT Record object. Setting this on an NWListener
        /// means it will advertise additional metadata about its service when
        /// the listener is active. An NWBrowser searching for the listener's
        /// service will be able to retrieve the metadata during browsing. Update
        /// the txtRecord by setting the service on the listener with the same
        /// name/type/domain and a new TXT record object.
        //@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
        //public var txtRecordObject: NWTXTRecord?

        /// Bonjour txtRecord - metadata for the service. Update the txtRecord by setting the
        /// service on the listener with the same name/type/domain and a new txtRecord.
        public let txtRecord: Data?

        /// By default, advertised services may be automatically renamed if there is
        /// a conflict with other service names on the network. Set noAutoRename
        /// to true to disable this behavior.
        //@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
        //public var noAutoRename: Bool

        /// Create a Service to advertise for the listener. Name, domain, and txtRecord all default to nil.
        public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: Data? = nil) {
            self.name = name
            self.type = type
            self.domain = domain
            self.txtRecord = txtRecord
        }

        /// Create a Service to advertise for the listener with an NWTXTRecord. Name and domain default to nil.
        //@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
        //public init(name: String? = nil, type: String, domain: String? = nil, txtRecord: NWTXTRecord)
    }


    /// Block to be called for new inbound connections
    //final public var newConnectionHandler: ((NWConnection) -> Void)?

    /// NWParameters used to create the listener
    final public let parameters: NWParameters

    /// Optional Bonjour service to advertise with the listener
    /// May be modified on the fly to update the TXT record or
    /// change the advertised service.
    final public var service: NWListener.Service?

    /// Static value to make the listener's new connection limit unbounded.
    public static let InfiniteConnectionLimit: Int = 0

    /// Configure the listener's new connection limit. Use the value
    /// NWListener.InfiniteConnectionLimit to disable connection limits.
    /// If the value is not NWListener.InfiniteConnectionLimit, the value
    /// will be decremented by 1 every time a new connection is received.
    /// When the value reaches 0, the new connection handler will no longer
    /// be invoked until the the limit is increased.
    final public var newConnectionLimit: Int

    /// The current port the listener is bound to, if any. The port is only valid when the listener is in the ready
    /// state.
    final public var port: NWEndpoint.Port? { get {nil} }

    public enum ServiceRegistrationChange {

        /// An event when a Bonjour service has been registered, with the endpoint being advertised
        case add(NWEndpoint)

        /// An event when a Bonjour service has been unregistered, with the endpoint being removed
        case remove(NWEndpoint)
    }

    /// Set a block to be called when the listener has added or removed a
    /// registered service. This may be called multiple times until the listener
    /// is cancelled.
    final public var serviceRegistrationUpdateHandler: ((NWListener.ServiceRegistrationChange) -> Void)?

    /// Creates a networking listener. The listener will be assigned a random
    /// port to listen on unless otherwise specified.
    ///
    /// - Parameter using: The parameters to use for the listener, which include the protocols to use for the
    /// listener. The parameters requiredLocalEndpoint may be used to specify the local address and port to listen on.
    /// - Parameter on: The port to listen on. Defaults to .any which will cause a random unused port to be assigned.
    /// Specifying a port that is already in use will cause the listener to fail after starting.
    /// - Returns: Returns a listener object that may be set up and started or throws an error if the parameters are
    /// not compatible with the provided port.
    public init(using: NWParameters, on: NWEndpoint.Port = .any) throws {
        self.parameters = using
        self.newConnectionLimit = NWListener.InfiniteConnectionLimit
        //super.init(ident: 0)
    }

}


/// An NWTXTRecord is used to provide additional information about a service
/// during advertisement or discovery.
///
/// Set an NWTXTRecord on an NWListener to provide additional information about
/// the service it is advertising, or get an NWTXTRecord from an NWBrowser's
/// browse result to get more information about a discovered service.
@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct NWTXTRecord {

    /// The entry mapped to a key in the TXT Record.
    public enum Entry : Hashable, CustomDebugStringConvertible {

        /// The key is mapped to no value.
        case none

        /// The key is mapped to an empty value.
        case empty

        /// The key is mapped to a string value.
        case string(String)

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

        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (a: NWTXTRecord.Entry, b: NWTXTRecord.Entry) -> Bool {false}

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

    /// Create an NWTXTRecord object from a Dictionary<String, String>. Every
    /// value in a key-value pair will be converted and stored as UTF8 encoded
    /// Data. The default value is an empty dictionary.
    /// - Parameter dictionary: The Dictionary<String, String>.
    public init(_ dictionary: [String : String] = [:]) {}

    /// Remove an entry from the TXT Record. If an invalid key is provided,
    /// the remove will fail.
    ///
    /// - Parameter key: The key of the entry.
    /// - Returns: Whether the remove was successful. If an invalid key is
    ///            provided, this value will be false.
    public mutating func removeEntry(key: String) -> Bool {false}

    /// Get an entry from the TXT Record. If an invalid key is provided,
    /// the return value will be nil.
    ///
    /// - Parameter key: The key of the entry.
    /// - Returns: The entry, or nil if the key is invalid or if they entry does
    ///            not exist in the TXT Record.
    public func getEntry(for key: String) -> NWTXTRecord.Entry? {nil}

    /// Set entry into the TXT Record. The new entry will replace any previous
    /// entry whose key matches case-insensitively. If an invalid key is
    /// provided, the insert will fail.
    ///
    /// - Parameter entry: The entry to insert.
    /// - Returns: Whether the insert was successful. If an invalid key is
    ///            provided, this value will be false.
    public mutating func setEntry(_ entry: NWTXTRecord.Entry, for key: String) -> Bool {false}

    /// A convenience accessor for getting and setting entries on the TXT Record.
    ///
    /// txtRecord.removeValue(forKey: "key") // removes the entry mapped to "key"
    ///    ...
    /// txtRecord["key"] = "data" // replaces the previous entry mapped to "key" with "data"
    ///    ...
    /// let value = txtRecord["key"] // gets the string mapped to "key", nil otherwise
    ///
    /// - Parameter key: The key of the entry.
    public subscript(key: String) -> String? {nil}

    private var dict = Dictionary<String,String>()
    /// Access the contents of an NWTXTRecord represented by a
    /// Dictionary<String, String>.
    public var dictionary: [String : String] { get {dict} }
}

/// Allow NWTXTRecords to be compared for equality.
@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension NWTXTRecord : Equatable {

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    public static func == (lhs: NWTXTRecord, rhs: NWTXTRecord) -> Bool {false}
}

/// Have NWTXTRecord conform to Collection so we can perform operations such as
/// isEmpty, count, first, map, reduce, filter, etc.
@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension NWTXTRecord : Collection {
    public subscript(position: NWTXTRecord.Index) -> (key: String, value: NWTXTRecord.Entry) {
        get {
            return ("", .none)
        }
    }
    

    /// A type representing the sequence's elements.
    public typealias Element = (key: String, value: NWTXTRecord.Entry)

    /// Accesses the element at the specified position.
    ///
    /// The following example accesses an element of an array through its
    /// subscript to print its value:
    ///
    ///     var streets = ["Adams", "Bryant", "Channing", "Douglas", "Evarts"]
    ///     print(streets[1])
    ///     // Prints "Bryant"
    ///
    /// You can subscript a collection with any valid index other than the
    /// collection's end index. The end index refers to the position one past
    /// the last element of a collection, so it doesn't correspond with an
    /// element.
    ///
    /// - Parameter position: The position of the element to access. `position`
    ///   must be a valid index of the collection that is not equal to the
    ///   `endIndex` property.
    ///
    /// - Complexity: O(1)
    public subscript(position: NWTXTRecord.Index) -> NWTXTRecord.Element? { get {nil} }

    /// A type that represents a position in the collection.
    ///
    /// Valid indices consist of the position of every element and a
    /// "past the end" position that's not valid for use as a subscript
    /// argument.
    public struct Index : Comparable {

        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (lhs: NWTXTRecord.Index, rhs: NWTXTRecord.Index) -> Bool {false}

        /// Returns a Boolean value indicating whether the value of the first
        /// argument is less than that of the second argument.
        ///
        /// This function is the only requirement of the `Comparable` protocol. The
        /// remainder of the relational operator functions are implemented by the
        /// standard library for any type that conforms to `Comparable`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func < (lhs: NWTXTRecord.Index, rhs: NWTXTRecord.Index) -> Bool {false}
    }

    /// The position of the first element in a nonempty collection.
    ///
    /// If the collection is empty, `startIndex` is equal to `endIndex`.
    public var startIndex: NWTXTRecord.Index { get {Index()} }

    /// The collection's "past the end" position---that is, the position one
    /// greater than the last valid subscript argument.
    ///
    /// When you need a range that includes the last element of a collection, use
    /// the half-open range operator (`..<`) with `endIndex`. The `..<` operator
    /// creates a range that doesn't include the upper bound, so it's always
    /// safe to use with `endIndex`. For example:
    ///
    ///     let numbers = [10, 20, 30, 40, 50]
    ///     if let index = numbers.firstIndex(of: 30) {
    ///         print(numbers[index ..< numbers.endIndex])
    ///     }
    ///     // Prints "[30, 40, 50]"
    ///
    /// If the collection is empty, `endIndex` is equal to `startIndex`.
    public var endIndex: NWTXTRecord.Index { get {Index()} }

    /// Returns the position immediately after the given index.
    ///
    /// The successor of an index must be well defined. For an index `i` into a
    /// collection `c`, calling `c.index(after: i)` returns the same index every
    /// time.
    ///
    /// - Parameter i: A valid index of the collection. `i` must be less than
    ///   `endIndex`.
    /// - Returns: The index value immediately after `i`.
    public func index(after i: NWTXTRecord.Index) -> NWTXTRecord.Index {Index()}

    /// A type that provides the collection's iteration interface and
    /// encapsulates its iteration state.
    ///
    /// By default, a collection conforms to the `Sequence` protocol by
    /// supplying `IndexingIterator` as its associated `Iterator`
    /// type.
    public typealias Iterator = IndexingIterator<NWTXTRecord>

    /// A sequence that represents a contiguous subrange of the collection's
    /// elements.
    ///
    /// This associated type appears as a requirement in the `Sequence`
    /// protocol, but it is restated here with stricter constraints. In a
    /// collection, the subsequence should also conform to `Collection`.
    public typealias SubSequence = Slice<NWTXTRecord>

    /// A type that represents the indices that are valid for subscripting the
    /// collection, in ascending order.
    public typealias Indices = DefaultIndices<NWTXTRecord>
}

/// Provide a debug description for an NWTXTRecord.
@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension NWTXTRecord : CustomDebugStringConvertible {

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
    public var debugDescription: String { get{""} }
}

