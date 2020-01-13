//
//  NWParameters.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
final public class NWParameters : CustomDebugStringConvertible {

    /// The conversion of `p` to a string in the assignment to `s` uses the
    /// `Point` type's `debugDescription` property.
    final public var debugDescription: String { get {""} }

    /// Creates a parameters object that is configured for TLS and TCP. The caller can use
    /// the default configuration for TLS and TCP, or set specific options for each protocol,
    /// or disable TLS.
    ///
    /// - Parameter tls: TLS options or nil for no TLS
    /// - Parameter tcp: TCP options. Defaults to NWProtocolTCP.Options() with no options overridden.
    /// - Returns: NWParameters object that can be used for creating a connection or listener
    public convenience init(tls: NWProtocolTLS.Options?, tcp: NWProtocolTCP.Options = NWProtocolTCP.Options()) {
        self.init()
        defaultProtocolStack.internetProtocol = tcp
        defaultProtocolStack.transportProtocol = tls
    }

    /// Creates a parameters object that is configured for DTLS and UDP. The caller can use
    /// the default configuration for DTLS and UDP, or set specific options for each protocol,
    /// or disable TLS.
    ///
    /// - Parameter dtls: DTLS options or nil for no DTLS
    /// - Parameter udp: UDP options. Defaults to NWProtocolUDP.Options() with no options overridden.
    /// - Returns: NWParameters object that can be used for create a connection or listener
    public convenience init(dtls: NWProtocolTLS.Options?, udp: NWProtocolUDP.Options = NWProtocolUDP.Options()) {
        self.init()
        defaultProtocolStack.internetProtocol = udp
        defaultProtocolStack.transportProtocol = dtls
    }

    /// Creates a generic NWParameters object. Note that in order to use parameters
    /// with a NWConnection or a NetworkListener, the parameters must have protocols
    /// added into the defaultProtocolStack. Clients using standard protocol
    /// configurations should use init(tls:tcp:) or init(dtls:udp:).
    public init() {
        self.defaultProtocolStack = ProtocolStack()
    }

    /// Default set of parameters for TLS over TCP
    /// This is equivalent to calling init(tls:NWProtocolTLS.Options(), tcp:NWProtocolTCP.Options())
    final public class var tls: NWParameters { get {NWParameters(tls:NWProtocolTLS.Options())} }

    /// Default set of parameters for DTLS over UDP
    /// This is equivalent to calling init(dtls:NWProtocolTLS.Options(), udp:NWProtocolUDP.Options())
    final public class var dtls: NWParameters { get {NWParameters(dtls:NWProtocolTLS.Options())} }

    /// Default set of parameters for TCP
    /// This is equivalent to calling init(tls:nil, tcp:NWProtocolTCP.Options())
    final public class var tcp: NWParameters { get {NWParameters(tls: nil)} }

    /// Default set of parameters for UDP
    /// This is equivalent to calling init(dtls:nil, udp:NWProtocolUDP.Options())
    final public class var udp: NWParameters { get {NWParameters(dtls: nil)} }

    /// If true, a direct connection will be attempted first even if proxies are configured. If the direct connection
    /// fails, connecting through the proxies will still be attempted.
    final public var preferNoProxies: Bool = false

    /// Use fast open for an outbound NWConnection, which may be done at any
    /// protocol level. Use of fast open requires that the caller send
    /// idempotent data on the connection before the connection may move
    /// into ready state. As a side effect, this may implicitly enable
    /// fast open for protocols in the stack, even if they did not have
    /// fast open explicitly enabled on them (such as the option to enable
    /// TCP Fast Open).
    final public var allowFastOpen: Bool = false

    public class ProtocolStack {

        public var applicationProtocols: [NWProtocolOptions] = []

        public var transportProtocol: NWProtocolOptions? = nil

        public var internetProtocol: NWProtocolOptions? = nil
    }

    /// Every NWParameters has a default protocol stack, although it may start out empty.
    final public var defaultProtocolStack: NWParameters.ProtocolStack

    /// Perform a deep copy of parameters
    final public func copy() -> NWParameters {NWParameters()}
}

