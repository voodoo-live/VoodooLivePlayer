//
//  NWProtocolFramer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

/// NWProtocolFramerImplementation is a Swift protocol that defines an
/// implementation of a custom framer protocol.
public protocol MiniNWProtocolFramerImplementation : AnyObject {

    /// A string label used to name this framer protocol. This does not
    /// define uniqueness, and is primarily used for logging and debugging.
    static var label: String { get }

    /// An initializer to create a new instance of the framer protocol.
    /// This may occur more than once for a single NWConnection.
    ///
    /// - Parameter framer: A new instance of the framer protocol.
    init(framer: NWProtocolFramer.Instance)

    /// A function invoked when starting a new instance of the framer
    /// protocol. This will occur exactly once for each initialized
    /// Return a StartResult indicate if the connection should become ready
    /// immediately, or wait.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult

    /// A function to be invoked whenever new input
    /// data is available to be parsed. When this block is
    /// run, the implementation should call functions like
    /// parseInput() and deliverInput().
    ///
    /// Each invocation represents new data being available
    /// to read from the network. This data may be insufficient
    /// to complete a message, or may contain multiple messages.
    /// Implementations are expected to try to parse messages
    /// in a loop until parsing fails to read enough to continue.
    ///
    /// Return a hint of the number of bytes that should be present
    /// before invoking this handler again. Returning 0 indicates
    /// that the handler should be invoked once any data is available.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    func handleInput(framer: NWProtocolFramer.Instance) -> Int

    /// A function to be invoked whenever an output
    /// message is ready to be sent. When this block is
    /// run, the implementation should call functions like
    /// parseOutput() and writeOutput().
    ///
    /// Each invocation represents a single complete or partial
    /// message that is being sent. The implementation is
    /// expected to write this message or let it be dropped
    /// in this handler.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    ///
    /// - Parameter message: The length of the data associated with
    ///   this message send. If the message is not complete, the length
    ///   represents the partial message length being sent, which may be
    ///   smaller than the complete message length.
    ///
    /// - Parameter isComplete: A boolean indicating whether or not the
    ///   message is now complete.
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool)

    /// A function to be invoked whenever the wakeup timer
    /// set via scheduleWakeup() fires. This is intended to
    /// be used for sending keepalives or other control traffic.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    func wakeup(framer: NWProtocolFramer.Instance)

    /// A function to be invoked when the connection
    /// is being disconnected, to allow the framer implementation
    /// a chance to send any final data.
    ///
    /// Return true if the framer is done and the connection
    /// can be fully disconnected, or false the stop should
    /// be delayed. If false, the implementation must later
    /// call markFailed(error:) on the instance.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    func stop(framer: NWProtocolFramer.Instance) -> Bool

    /// A function to be invoked when the protocol stack
    /// is being torn down and deallocated. This is the opportunity
    /// for the framer implementation to release any state it may
    /// have saved.
    ///
    /// - Parameter framer: The instance of the framer protocol.
    func cleanup(framer: NWProtocolFramer.Instance)
}


/// An NWProtocolFramer defines a protocol in a connection's protocol
/// stack that parses and writes messages on top of a transport protocol, such
/// as a TCP stream. A framer can add and parse headers or delimiters around
/// application data to provide a message-oriented abstraction.
///
/// In order to implement a framer protocol, first define a class that conforms
/// to NWProtocolFramerImplementation. Pass this type to NWProtocolFramer.Definition
/// to create a protocol definition. This can be used to create options with
/// NWProtocolFramer.Options, which can be added to an NWParameters.ProtocolStack.
/// The callbacks and actions for the framer's protocol instance can be
/// set once the NWProtocolFramerImplementation object is intantiated.
///
/// In order to send and receive framer messages with custom values on an
/// NWConnection, use NWProtocolFramer.Message as part of a
/// NWConnection.ContentContext.
//@available(OSX 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public class NWProtocolFramer : NWProtocol {

    public class Definition : NWProtocolDefinition {

        /// Create a protocol definition for a custom framer protocol.
        ///
        /// - Parameter implementation: The custom class that implements
        ///   the NWProtocolFramerImplementation Swift protocol.
        public init(implementation: MiniNWProtocolFramerImplementation.Type) {
            super.init("Framer:" + implementation.label)
        }
    }

    public class Options : NWProtocolOptions {

        /// Create protocol options from a framer definition. This object can
        /// be added to an NWParameters.ProtocolStack to be used in an NWConnection
        /// or an NWListener.
        ///
        /// - Parameter definition: A definition for a custom framer protocol.
        public init(definition: NWProtocolFramer.Definition) {}
    }

    /// A framer message is an instance of NWProtocolMetadata associated
    /// with the definition of a framer, created with an NWProtocolFramer.Definition.
    public class Message : NWProtocolMetadata {

        /// Create an instance of a framer message on which per-
        /// message options can be configured when sending data
        /// on a connection. This is intended to be used by the
        /// application above the connection to send message data
        /// down to the framer protocol instance.
        public init(definition: NWProtocolFramer.Definition) {}

        /// Create a message using a framer instance rather than
        /// the definition. This can be used to deliver messages
        /// from a framer implementation to the application.
        public init(instance: NWProtocolFramer.Instance) {
            
        }

        private var valueStorage = Dictionary<String, Any>()
        /// Store key-value pairs in a framer message, where the
        /// value is an arbitrary object.
        public subscript(key: String) -> Any? {
            get {valueStorage[key]}
            set {valueStorage[key]=newValue}
        }
    }

    /// NWProtocolFramer.Instance is an object that a custom framer protocol
    /// interacts with in order to drive connection state, parse input and output,
    /// and deliver and write data.
    final public class Instance : CustomDebugStringConvertible {

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
        final public var debugDescription: String { get {""} }

        /// Mark the connection associated with the framer instance
        /// as ready (see NWConnection.State.ready). This is intended
        /// to be used by protocols that require a handshake before being
        /// able to send application data. This should only be called
        /// if the return value to the start function was willMarkReady.
        final public func markReady() {}

        /// Mark the connection associated with the framer instance
        /// as failed (see NWConnection.State.failed).
        final public func markFailed(error: NWError?) {}

        /// Parse currently available input starting at the location of the input
        /// cursor in the stream or message being parsed.
        ///
        /// The parse completion block will always be invoked inline exactly once.
        ///
        /// Returns true if the parse succeeded, or false if not enough bytes were
        /// available to meet the minimum requirement.
        ///
        /// - Parameter minimumIncompleteLength: The minimum number of bytes to
        ///   parse. If this amount is not available, the parse completion block
        ///   will be invoked with 0 bytes.
        ///
        /// - Parameter maximumLength: The maximum number of bytes to parse as a
        ///   contiguous buffer.
        ///
        /// - Parameter parse: The completion that provides the bytes to parse,
        ///   which will be called exactly once. Parameters to the completion are:
        ///
        ///   - buffer: The buffer of bytes being received.
        ///
        ///   - isComplete: A boolean indicating if this section of the buffer
        ///     indicates the end of a message or stream.
        ///
        ///   Return the number of bytes by which to advance the input cursor.
        ///   For example, if parseInput() is called and the completion returns 0,
        ///   calling parseInput() again will allow the implementation to start
        ///   parsing again at the same start location. However, if the completion
        ///   returns 10, the next call to parseInput() will return bytes starting
        ///   from 10 bytes beyond the previous call.
        ///
        ///   The cursor also defines the offset at which data being delivered
        ///   using deliverInputNoCopy() will start.
        ///
        ///   The returned value for incrementing the cursor may be larger than
        ///   the length of the buffer just parsed. This allows an implementation
        ///   to "skip" ahead by a number of bytes if it knows it does not
        ///   need to parse more.
        final public func parseInput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {false}

        /// Deliver arbitrary data to the application. This is intended to
        /// deliver any data that is generated or transformed by the
        /// protocol instance. This function will incur a copy of bytes.
        ///
        /// - Parameter data: The bytes to deliver to the application. This must
        ///   be non-nil. If an empty message needs to be delivered, use
        ///   deliverInputNoCopy.
        ///
        /// - Parameter message: The message to associate with the received data.
        ///
        /// - Parameter isComplete: A boolean indicating whether or not this data
        ///   represents the end of the message.
        final public func deliverInput(data: Data, message: NWProtocolFramer.Message, isComplete: Bool) {}

        /// Deliver bytes directly to the application without any
        /// transformation or copy. The bytes will start at the current
        /// input cursor used for parsing, and will implicitly advance
        /// the cursor by the length being delivered.
        ///
        /// - Parameter length: The number of input bytes to deliver. This
        ///   will advance the parsing cursor by the specified number of bytes.
        ///   To indicate the end of the message without delivering any data,
        ///   a length of 0 may be passed along with isComplete.
        ///
        /// - Parameter message: The message to associate with the received data.
        ///
        /// - Parameter isComplete: A boolean indicating whether or not this data
        ///   represents the end of the message.
        final public func deliverInputNoCopy(length: Int, message: NWProtocolFramer.Message, isComplete: Bool) -> Bool {false}

        /// Mark the input side of the framer as a pass-through, which
        /// means the framer will not be notified of any further input
        /// data.
        final public func passThroughInput() {}

        /// Parse currently available output from a message starting at the location
        /// of the output cursor in the message being parsed.
        ///
        /// The parse completion block will always be invoked inline exactly once.
        ///
        /// This function must only be called from within the handleOutput function.
        ///
        /// Returns true if the parse succeeded, or false if not enough bytes were
        /// available to meet the minimum requirement.
        ///
        /// - Parameter minimumIncompleteLength: The minimum number of bytes to
        ///   parse. If this amount is not available, the parse completion block
        ///   will be invoked with 0 bytes.
        ///
        /// - Parameter maximumLength: The maximum number of bytes to parse as a
        ///   contiguous buffer.
        ///
        /// - Parameter parse: The completion that provides the bytes to parse,
        ///   which will be called exactly once. Parameters to the completion are:
        ///
        ///   - bytes: The buffer of bytes being sent.
        ///
        ///   - count: The number of valid bytes in buffer.
        ///
        ///   - isComplete: A boolean indicating if this section of the buffer
        ///     indicates the end of a message.
        ///
        ///   Return the number of bytes by which to advance the output cursor.
        ///   For example, if parseOutput() is called and the completion returns 0,
        ///   calling parseOutput() again will allow the implementation to start
        ///   parsing again at the same start location. However, if the completion
        ///   returns 10, the next call to parseOutput() will return bytes starting
        ///   from 10 bytes beyond the previous call.
        ///
        ///   The cursor also defines the offset at which data being written
        ///   using writeOutputNoCopy() will start.
        ///
        ///   The returned value for incrementing the cursor may be larger than
        ///   the length of the buffer just parsed. This allows an implementation
        ///   to "skip" ahead by a number of bytes if it knows it does not
        ///   need to parse more.
        final public func parseOutput(minimumIncompleteLength: Int, maximumLength: Int, parse: (UnsafeMutableRawBufferPointer?, Bool) -> Int) -> Bool {false}

        /// Write arbitrary bytes as part of an outbound message. This
        /// is intended to be used for adding headers around application
        /// data, or writing any other data that is generated or transformed
        /// by the protocol instance. It does not pass along data directly
        /// from the application.
        ///
        /// This function may be called as part of any framer callback,
        /// not just handleOutput.
        ///
        /// - Parameter data: Arbitrary data to write on the connection.
        final public func writeOutput(data: Data) {}

        /// Write arbitrary DataProtocol bytes as part of an outbound message.
        /// This is intended to be used for adding headers around application
        /// data, or writing any other data that is generated or transformed
        /// by the protocol instance. It does not pass along data directly
        /// from the application.
        ///
        /// This function may be called as part of any framer callback,
        /// not just handleOutput.
        ///
        /// - Parameter data: Arbitrary DataProtocol to write on the connection.
        @inlinable final public func writeOutput<Output>(data: Output) where Output : DataProtocol {}

        /// Write bytes directly from the application without any
        /// transformation or copy. The bytes will start at the current
        /// output cursor used for parsing and will implicitly advance
        /// the cursor by the length being written.
        ///
        /// This function must only be called from within the handleOutput
        /// function on NWProtocolFramerImplementation.
        ///
        /// Throws an error if not called within the context of handleOutput,
        /// or if the specified length is longer than the current message.
        ///
        /// - Parameter length: Number of bytes from application to write.
        final public func writeOutputNoCopy(length: Int) throws {}

        /// Mark the output side of the framer as a pass-through, which
        /// means the framer will not be notified of any further output
        /// data.
        final public func passThroughOutput() {}

        /// A type representing a wakeup target, either milliseconds from now,
        /// or forever to unschedule the timer.
        public enum WakeupTime {

            /// Specify the number of milliseconds in the future that a wakeup
            /// should occur
            case milliseconds(UInt64)

            /// Specify that the wakeup should be unscheduled
            case forever
        }

        /// Schedule a wakeup on the framer instance for a number of
        /// milliseconds into the future. If this is called multiple
        /// times before the timeout is reached, the new value replaces
        /// the previous value.
        ///
        /// - Parameter wakeupTime: The number of milliseconds into
        ///   the future at which to invoke the wakeup handler, or
        ///   .forever, effectively unscheduling the timer.
        final public func scheduleWakeup(wakeupTime: NWProtocolFramer.Instance.WakeupTime) {}

        /// Schedule a block asynchronously on the framer instance. This
        /// must be used anytime the caller wants to perform any other
        /// action on the framer instance while not directly in the callstack
        /// of a callback from the framer.
        final public func async(execute: @escaping () -> Void) {}

        /// The remote endpoint for the framer's connection
        final public var remote: NWEndpoint? { get {nil} }

        /// The local endpoint for the framer's connection
        final public var local: NWEndpoint? { get {nil} }

        /// The parameters for the framer's connection
        final public var parameters: NWParameters? { get {nil} }

        /// Dynamically add a protocol to a connection establishment
        /// attempt "above" the framer protocol. This means that the
        /// protocol above will start running once the framer becomes
        /// ready by calling nw_framer_mark_ready(). This can only
        /// be used with framers that return a value of
        /// nw_framer_start_result_will_call_ready to their start
        /// handlers. An example of using this functionality is
        /// adding a security protocol, like TLS, above a framer
        /// once that framer completes its initial handshake.
        ///
        /// To ensure thread safety, this function can only be called
        /// in one of the callback blocks invoked on the framer, or
        /// in a block passed to NWProtocolFramer.Instance.async().
        ///
        /// Throws an error if the protocol could not be added. This
        /// will fail if the framer is already marked ready.
        ///
        /// - Parameter options: Protocol options for an application
        ///   protocol to dynamically add "above" the framer.
        final public func prependApplicationProtocol(options: NWProtocolOptions) throws {}
    }

    public enum StartResult {

        /// Indicates that the connection should be marked as ready upon start
        case ready

        /// Indicates that the framer will call markReady() sometime later. This
        /// should be used by framer protocols that require a handshake.
        case willMarkReady

        /// Returns a Boolean value indicating whether two values are equal.
        ///
        /// Equality is the inverse of inequality. For any values `a` and `b`,
        /// `a == b` implies that `a != b` is `false`.
        ///
        /// - Parameters:
        ///   - lhs: A value to compare.
        ///   - rhs: Another value to compare.
        public static func == (a: NWProtocolFramer.StartResult, b: NWProtocolFramer.StartResult) -> Bool {
            switch (a,b) {
            case (.ready, .ready), (.willMarkReady, .willMarkReady):
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
            case .ready:
                hasher.combine(".ready")
            case .willMarkReady:
                hasher.combine(".willMarkReady")
            }
        }
    }
}

extension NWProtocolFramer.StartResult : Equatable {
}

extension NWProtocolFramer.StartResult : Hashable {
}

