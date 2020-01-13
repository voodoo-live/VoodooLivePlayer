//
//  NWConnection.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation


public final class NWConnection : NWAsyncObject, NWProtocolLayer, CustomDebugStringConvertible {
    final public var debugDescription: String { get {""} }
    
    
    public final func markReady() {
        state = .ready
    }
    /*
    func markFailed(_ error: NWError) {
        state = .failed(error)
    }
    */
    
    public final let name: String = "connection"
    
    public final private(set) var error: NWError = .none
    
    public final weak var prevLayer: NWProtocolLayer?
    
    public final weak var nextLayer: NWProtocolLayer?
    
    public final func open(endpoint: NWEndpoint, in queue:DispatchQueue, using: NWParameters) -> Bool {
        return prevLayer?.open(endpoint: endpoint, in: queue, using: using) ?? false
    }
    
    public final func close() {
        prevLayer?.close()
    }
    
    public final func read(buffer: UnsafeMutableRawBufferPointer?) -> Int {
        let ret = prevLayer?.read(buffer: buffer) ?? -1
        if ret < 0 {
            self.error = prevLayer?.error ?? .none
        }
        return ret
    }
    
    public final func write(data: UnsafeRawBufferPointer?) -> Int {
        let ret = prevLayer?.write(data: data) ?? -1
        if ret < 0 {
            self.error = prevLayer?.error ?? .none
        }
        return ret
    }
    
    public final func pong(state: NWAsyncObjectState) {
        prevLayer?.pong(state: state)
    }
    
    public final func dismissed(layer: NWProtocolLayer) {
        if layer.prevLayer != nil {
            layer.prevLayer?.nextLayer = layer.nextLayer
        }
        
        if layer.nextLayer != nil {
            layer.nextLayer?.prevLayer = layer.prevLayer
        }
        
        layer.nextLayer = nil
        layer.prevLayer = nil
        
        for i in 0..<protocolLayers.count {
            if ObjectIdentifier(protocolLayers[i]) == ObjectIdentifier(layer) {
                protocolLayers.remove(at: i)
                break
            }
        }
        
        print("\(layer.name) dismissed!")
    }
    
    public final func ping() {
        print("PING ARRIVED!")
        pong(state: state)
    }
    
    public final func handleWrite(_ len: Int) {
        writeFlag = true
        writeLen = len
        
        self.queuedSerializer.handleWrite(len)
    }
    
    public final func handleRead(_ len: Int) {
        //print("CONNECTION READ:", len)
        readFlag = true
        readLen = len
        
        self.queuedSerializer.handleRead(len)
    }
    
    public final func handleEOF(_ error: Int32) {
        self.queuedSerializer.handleEOF(error)
        markFailed(.posix(error))
    }
    
    var readFlag = false
    var readLen = 0
    var writeFlag = false
    var writeLen = 0
    
    var endpoint: NWEndpoint
    var parameters: NWParameters
    var protocolLayers = [NWProtocolLayer]()
    /*
    private func addProtocolLayer(layer:NWProtocolLayer) {
        let lastLayer = protocolLayers.last
        lastLayer?.nextLayer = layer
        layer.prevLayer = lastLayer
        layer.nextLayer = self
        self.prevLayer = layer
        protocolLayers.append(layer)
    }
    */
    
    private func initLayers() -> Bool {
        //protocolLayers.append(NWTCPLayer())
        //if !self.parameters.preferNoProxies, let proxyConfiguration = NWNetworkConfiguration.shared.proxyConfiguration, proxyConfiguration.isSocksEnabled, !proxyConfiguration.checkInExceptionList(endpoint: self.endpoint) {
          //  protocolLayers.append(NWSOCKSLayer())
        //}
        /*if self.parameters.defaultProtocolStack.transportProtocol != nil &&
            self.parameters.defaultProtocolStack.transportProtocol!.definition == NWProtocolDefinition.tls {
            if let tlsLayer = NWTLSLayer() {
                protocolLayers.append(tlsLayer)
            } else {
                protocolLayers.removeAll()
                return false
            }
        }*/
        return true
    }
    
    private func connectLayers() {
        var prevLayer: NWProtocolLayer?
        let lastLayer = self
        
        for i in 0..<protocolLayers.count {
            protocolLayers[i].prevLayer = prevLayer
            protocolLayers[i].nextLayer = i + 1 >= protocolLayers.count ? lastLayer : protocolLayers[i+1]
            prevLayer = protocolLayers[i]
        }
        
        self.prevLayer = prevLayer
    }
    
    private func fintLayers() {
        for layer in protocolLayers {
            layer.prevLayer = nil
            layer.nextLayer = nil
        }
        self.prevLayer = nil
        self.nextLayer = nil
        
        protocolLayers.removeAll()
    }
    
    public final func addProtocolLayer(layer: NWProtocolLayer) -> Bool {
        guard self.state == .setup else { return false }
        if let lastLayer = protocolLayers.last {
            layer.prevLayer = lastLayer
            layer.nextLayer = lastLayer.nextLayer
            lastLayer.nextLayer = layer
        } else {
            
            layer.nextLayer = self
            layer.prevLayer = nil
        }
        
        self.prevLayer = layer
        
        protocolLayers.append(layer)
        return true
    }

    /// Create a new outbound connection to an endpoint, with parameters.
    /// The parameters determine the protocols to be used for the connection, and their options.
    ///
    /// - Parameter to: The remote endpoint to which to connect.
    /// - Parameter using: The parameters define which protocols and path to use.
    public init?(to: NWEndpoint, using: NWParameters) {
        /// At least have a internet protocol
        guard using.defaultProtocolStack.internetProtocol != nil else { return nil }
        guard
            using.defaultProtocolStack.internetProtocol?.definition == NWProtocolDefinition.tcp ||
            using.defaultProtocolStack.internetProtocol?.definition == NWProtocolDefinition.tls
        else {
            print("[ERROR] CONNECTION SUPPORT ONLY TCP AND TLS")
            return nil
        }
        
        protocolLayers.append(NWTCPLayer())
        if !using.preferNoProxies, let proxyConfiguration = NWNetworkConfiguration.shared.proxyConfiguration, proxyConfiguration.isSocksEnabled, !proxyConfiguration.checkInExceptionList(endpoint: to) {
            protocolLayers.append(NWSOCKSLayer())
        }
        
        if using.defaultProtocolStack.transportProtocol != nil &&
            using.defaultProtocolStack.transportProtocol!.definition == NWProtocolDefinition.tls {
            if let tlsLayer = NWTLSLayer() {
                protocolLayers.append(tlsLayer)
            } else {
                protocolLayers.removeAll()
                return nil
            }
        }

        self.endpoint = to
        self.parameters = using

        super.init()
        
        connectLayers()
        
        //queuedSerializer = NWQueuedSerializer(layer: self, queue: queue)
    }

    /// Create a new outbound connection to a hostname and port, with parameters.
    /// The parameters determine the protocols to be used for the connection, and their options.
    ///
    /// - Parameter host: The remote hostname to which to connect.
    /// - Parameter port: The remote port to which to connect.
    /// - Parameter using: The parameters define which protocols and path to use.
    public convenience init?(host: NWEndpoint.Host, port: NWEndpoint.Port, using: NWParameters) {
        self.init(to: NWEndpoint.hostPort(host, port), using: using)
    }
    
    deinit {
        print("CONNECTION DEINIT")
    }
    
    override func internalStart() -> Bool {
        return open(endpoint: self.endpoint, in: self.queue, using: self.parameters)
    }

    override func handleStateChange(from: NWAsyncObjectState, to: NWAsyncObjectState) {
        if to == .cancelled {
            fintLayers()
            
            self.queuedSerializer.clear()
        }
    }
    
    override func internalLoop() {
    }

    override func internalCancel() {
        if state == .ready {
            self.close()
        }
        super.internalCancel()
    }
    
    
    var _queuedSerializer : NWQueuedSerializer!
    
    public var queuedSerializer: NWQueuedSerializer! {
        get {
            if _queuedSerializer == nil {
                if self.queue == nil { return nil }
                _queuedSerializer = NWQueuedSerializer(layer: self, queue: self.queue)
            }
            return _queuedSerializer
        }
    }
    
    /// Cancel the currently connected endpoint, causing the connection to fall through to the next endpoint if
    /// available, or to go to the waiting state if no more endpoints are available.
    //final public func cancelCurrentEndpoint() {}

    /// NWConnections will normally re-attempt on network changes. This function causes a connection that is in
    /// the waiting state to re-attempt even without a network change.
    /// [MiniNetwork] We don't support restart for const innerSocket.
    ///final public func restart() {}

    public class ContentContext {

        /// A string description of the content, used for logging and debugging.
        final public let identifier: String = ""

        /// An expiration in milliseconds after scheduling a send, after which the content may be dropped.
        /// Defaults to 0, which implies no expiration. Used only when sending.
        final public let expirationMilliseconds: UInt64 = 0

        /// A numeric value between 0.0 and 1.0 to specify priority of this data/message. Defaults to 0.5.
        /// Used only when sending.
        final public let relativePriority: Double = 0

        /// Any content marked as an antecedent must be sent prior to this content being sent. Defaults to nil.
        /// Used only when sending.
        final public let antecedent: ContentContext? = nil

        /// A boolean indicating if this context is the final context in a given direction on this connection. Defaults to false.
        final public let isFinal: Bool = false

        /// An array of protocol metadata to send (to inform the protocols of per-data options) or receive (to receive per-data options or statistics).
        public var protocolMetadata: [NWProtocolMetadata] { get {[]} }

        /// Access the metadata for a specific protocol from a context. The metadata may be nil.
        public func protocolMetadata(definition: NWProtocolDefinition) -> NWProtocolMetadata? {nil}

        /// Create a context for sending, that optionally can set expiration (default 0),
        /// priority (default 0.5), antecedent (default nil), and protocol metadata (default []]).
        public init(identifier: String, expiration: UInt64 = 0, priority: Double = 0.5, isFinal: Bool = false, antecedent: ContentContext? = nil, metadata: [NWProtocolMetadata]? = []) {}

        /// Use the default message context to send content with all default properties:
        /// default priority, no expiration, and not the final message. Marking this context
        /// as complete with a send indicates that the message content is now complete and any
        /// other messages that were blocked may be scheduled, but will not close the underlying
        /// connection. Use this context for any lightweight sends of datagrams or messages on
        /// top of a stream that do not require special properties.
        /// This context does not support overriding any properties.
        public static let defaultMessage: ContentContext = ContentContext(identifier: "defaultMessage")

        /// Use the final message context to indicate that no more sends are expected
        /// once this context is complete. Like .defaultMessage, all properties are default.
        /// Marking a send as complete when using this context will close the sending side of the
        /// underlying connection. This is the equivalent of sending a FIN on a TCP stream.
        /// This context does not support overriding any properties.
        public static let finalMessage: ContentContext = ContentContext(identifier: "finalMessage", isFinal: true)

        /// Use the default stream context to indicate that this sending context is
        /// the one that represents the entire connection. All context properties are default.
        /// This context behaves in the same way as .finalMessage, such that marking the
        /// context complete by sending isComplete will close the sending side of the
        /// underlying connection (a FIN for a TCP stream).
        /// Note that this context is a convenience for sending a single, final context.
        /// If the protocol used by the connection is a stream (such as TCP), the caller
        /// may still use .defaultMessage, .finalMessage, or a custom context with priorities
        /// and metadata to set properties of a particular chunk of stream data relative
        /// to other data on the stream.
        /// This context does not support overriding any properties.
        public static let defaultStream: ContentContext = ContentContext(identifier: "defaultStream")
    }

    /// Receive data from a connection. This may be called before the connection
    /// is ready, in which case the receive request will be queued until the
    /// connection is ready. The completion handler will be invoked exactly
    /// once for each call, so the client must call this function multiple
    /// times to receive multiple chunks of data. For protocols that
    /// support flow control, such as TCP, calling receive opens the receive
    /// window. If the client stops calling receive, the receive window will
    /// fill up and the remote peer will stop sending.
    /// - Parameter minimumIncompleteLength: The minimum length to receive from the connection,
    ///   until the content is complete.
    /// - Parameter maximumLength: The maximum length to receive from the connection in a single completion.
    /// - Parameter completion: A receive completion is invoked exactly once for a call to receive(...).
    ///   The completion indicates that the requested content has been received (in which case
    ///   the content is delivered), or else an error has occurred. Parameters to the completion are:
    ///
    ///   - content: The received content, as constrained by the minimum and maximum length. This may
    ///     be nil if the message or stream is complete (without any more data to deliver), or if
    ///     an error was encountered.
    ///
    ///   - contentContext: Content context describing the received content. This includes protocol metadata
    ///     that lets the caller introspect information about the received content (such as flags on a packet).
    ///
    ///   - isComplete: An indication that this context (a message or stream, for example) is now complete. For
    ///     protocols such as TCP, this will be marked when the entire stream has be closed in the
    ///     reading direction. For protocols such as UDP, this will be marked when the end of a
    ///     datagram has been reached.
    ///
    ///   - error: An error will be sent if the receive was terminated before completing. There may still
    ///     be content delivered along with the error, but this content may be shorter than the requested
    ///     ranges. An error will be sent for any outstanding receives when the connection is cancelled.
    final public func receive(minimumIncompleteLength: Int, maximumLength: Int, completion: @escaping (Data?, ContentContext?, Bool, NWError?) -> Void) {
        self.queuedSerializer.read(minimumLength: minimumIncompleteLength, maximumLength: maximumLength, context: completion as AnyObject, completedBlock: readCompleted(data:context:error:))
    }
    
    final private func readCompleted(data: Data?, context: AnyObject?, error: Error?) {
        let completion = context as! (Data?, ContentContext?, Bool, NWError?) -> Void
        completion(data, nil, false, error as? NWError)
    }

    /// Receive complete message content from the connection, waiting for the content to be marked complete
    /// (or encounter an error) before delivering the callback. This is useful for datagram or message-based
    /// protocols like UDP. See receive(minimumIncompleteLength:, maximumLength:, completion:) for a description
    /// of the completion handler.
    //final public func receiveMessage(completion: @escaping (Data?, ContentContext?, Bool, NWError?) -> Void) {
    //}

    /// A type representing a wrapped completion handler invoked when send content has been consumed by the protocol stack, or the lack of a completion handler because the content is idempotent.
    public enum SendCompletion {

        /// Completion handler to be invoked when send content has been successfully processed, or failed to send due to an error.
        /// Note that this does not guarantee that the data was sent out over the network, or acknowledge, but only that
        /// it has been consumed by the protocol stack.
        case contentProcessed((NWError?) -> Void)

        /// Idempotent content may be sent multiple times when opening up a 0-RTT connection, so there is no completion block
        case idempotent
    }

    /// Send data on a connection. This may be called before the connection is ready,
    /// in which case the send will be enqueued until the connection is ready to send.
    /// This is an asynchronous send and the completion block can be used to
    /// determine when the send is complete. There is nothing preventing a client
    /// from issuing an excessive number of outstanding sends. To minimize memory
    /// footprint and excessive latency as a consequence of buffer bloat, it is
    /// advisable to keep a low number of outstanding sends. The completion block
    /// can be used to pace subsequent sends.
    /// - Parameter content: The data to send on the connection. May be nil if this send marks its context as complete, such
    ///   as by sending .finalMessage as the context and marking isComplete to send a write-close.
    /// - Parameter contentContext: The context associated with the content, which represents a logical message
    ///   to be sent on the connection. All content sent within a single context will
    ///   be sent as an in-order unit, up until the point that the context is marked
    ///   complete (see isComplete). Once a context is marked complete, it may be re-used
    ///   as a new logical message. Protocols like TCP that cannot send multiple
    ///   independent messages at once (serial streams) will only start processing a new
    ///   context once the prior context has been marked complete. Defaults to .defaultMessage.
    /// - Parameter isComplete: A flag indicating if the caller's sending context (logical message) is now complete.
    ///   Until a context is marked complete, content sent for other contexts may not
    ///   be sent immediately (if the protocol requires sending bytes serially, like TCP).
    ///   For datagram protocols, like UDP, isComplete indicates that the content represents
    ///   a complete datagram.
    ///   When sending using streaming protocols like TCP, isComplete can be used to mark the end
    ///   of a single message on the stream, of which there may be many. However, it can also
    ///   indicate that the connection should send a "write close" (a TCP FIN) if the sending
    ///   context is the final context on the connection. Specifically, to send a "write close",
    ///   pass .finalMessage or .defaultStream for the context (or create a custom context and
    ///   set .isFinal), and pass true for isComplete.
    /// - Parameter completion: A completion handler (.contentProcessed) to notify the caller when content has been processed by
    ///   the connection, or a marker that this data is idempotent (.idempotent) and may be sent multiple times as fast open data.
    final public func send(content: Data?, contentContext: ContentContext = .defaultMessage, isComplete: Bool = true, completion: SendCompletion) {
        switch completion {
        case .idempotent:
            let context = (contentContext, isComplete)
            self.queuedSerializer.write(data: content, context: context as AnyObject)
        case .contentProcessed(let completedBlock):
            let context = (contentContext, isComplete, completedBlock)
            self.queuedSerializer.write(data: content, context: context as AnyObject, completedBlock: writeCompleted(context:error:))
        }
    }
    
    internal func writeCompleted(context: AnyObject?, error: Error?) {
        if let (_, _, completedBlock) = context as? (ContentContext, Bool, (NWError?) -> Void) {
            let nwError = error == nil ? nil : ((error as? NWError) ?? .unknown(-99))
            completedBlock(nwError)
        }
    }
    
    /// Batching mode flag
    private var batchMode = false
    
    /// Batching allows multiple send or receive calls provides a hint to the connection that the operations
    /// should be coalesced to improve efficiency. Calls other than send and receive will not be affected.
    final public func batch(_ block: () -> Void) {
        batchMode = true
        block()
        batchMode = false
    }
}
