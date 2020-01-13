//
//  NWProtocol.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import Security

public class NWProtocol {
}


public class NWProtocolDefinition : Equatable, CustomDebugStringConvertible {

    public static func == (lhs: NWProtocolDefinition, rhs: NWProtocolDefinition) -> Bool {
        return lhs.name == rhs.name
    }

    /// The name of the protocol, such as "TCP" or "UDP"
    final public let name: String
    
    public init(_ name: String) {
        self.name = name
    }
    
    public static let tcp = NWProtocolDefinition("tcp")
    public static let udp = NWProtocolDefinition("udp")
    public static let tls = NWProtocolDefinition("tls")
    public static let dtls = NWProtocolDefinition("dtls")
    public static let undefined = NWProtocolDefinition("undefined")

    public var debugDescription: String { get {name} }
}

public class NWProtocolMetadata {
    //public init() {}
}

public class NWProtocolOptions {
    //public init() {}
    
    public var definition: NWProtocolDefinition { get { return NWProtocolDefinition.undefined } }
}

public class NWProtocolTCP : NWProtocol {

    public static let definition = NWProtocolDefinition("tcp")

    public class Options : NWProtocolOptions {

        public override var definition: NWProtocolDefinition {
            return NWProtocolTCP.definition
        }
        /// A boolean indicating that TCP should disable
        /// Nagle's algorithm (TCP_NODELAY).
        public var noDelay: Bool = false

        /// A boolean indicating that TCP should be set into
        /// no-push mode (TCP_NOPUSH).
        public var noPush: Bool = false

        /// A boolean indicating that TCP should be set into
        /// no-options mode (TCP_NOOPT).
        public var noOptions: Bool = false

        /// A boolean indicating that TCP should send keepalives
        /// (SO_KEEPALIVE).
        public var enableKeepalive: Bool = false

        /// The number of keepalive probes to send before terminating
        /// the connection (TCP_KEEPCNT).
        public var keepaliveCount: Int = 0

        /// The number of seconds of idleness to wait before keepalive
        /// probes are sent by TCP (TCP_KEEPALIVE).
        public var keepaliveIdle: Int = 0

        /// The number of seconds of to wait before resending TCP
        /// keepalive probes (TCP_KEEPINTVL).
        public var keepaliveInterval: Int = 0

        /// The maximum segment size in bytes (TCP_MAXSEG).
        public var maximumSegmentSize: Int = 0

        /// A timeout for TCP connection establishment, in seconds
        /// (TCP_CONNECTIONTIMEOUT).
        public var connectionTimeout: Int = 0

        /// The TCP persist timeout, in seconds (PERSIST_TIMEOUT).
        /// See RFC 6429.
        public var persistTimeout: Int = 0

        /// A timeout for TCP retransmission attempts, in seconds
        /// (TCP_RXT_CONNDROPTIME).
        public var connectionDropTime: Int = 0

        /// A boolean to cause TCP to drop its connection after
        /// not receiving an ACK after a FIN (TCP_RXT_FINDROP).
        public var retransmitFinDrop: Bool = false

        /// A boolean to cause TCP to disable ACK stretching (TCP_SENDMOREACKS).
        public var disableAckStretching: Bool = false

        /// Configure TCP to enable TCP Fast Open (TFO). This may take effect
        /// even when TCP is not the top-level protocol in the protocol stack.
        /// For example, if TLS is running over TCP, the Client Hello message
        /// may be sent as fast open data.
        ///
        /// If TCP is the top-level protocol in the stack (the one the application
        /// directly interacts with), TFO will be disabled unless the application
        /// indicated that it will provide its own fast open data by calling
        /// NWParameters.allowFastOpen.
        public var enableFastOpen: Bool = false

        /// A boolean to disable ECN negotiation in TCP.
        public var disableECN: Bool = false

        /// Create TCP options to set in an NWParameters.ProtocolStack
        public override init() {
            self.connectionDropTime = 0
        }
    }

    public class Metadata : NWProtocolMetadata {

        /// Access the current number of bytes in TCP's receive buffer (SO_NREAD).
        public var availableReceiveBuffer: UInt32 { get {0} }

        /// Access the current number of bytes in TCP's send buffer (SO_NWRITE).
        public var availableSendBuffer: UInt32 { get {0} }
    }
}



//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class NWProtocolTLS : NWProtocol {

    public static let definition: NWProtocolDefinition = NWProtocolDefinition("tls")

    public class Options : NWProtocolOptions {
        public override var definition: NWProtocolDefinition {
            return NWProtocolTLS.definition
        }

        /// Access the sec_protocol_options_t for a given network protocol
        /// options instance. See <Security/SecProtocolOptions.h> for functions
        /// to further configure security options.
        //public var securityProtocolOptions: sec_protocol_options_t { get {sec_protocol_options_t()} }

        /// Create TLS options to set in an NWParameters.ProtocolStack
        //public init() {}
    }

    public class Metadata : NWProtocolMetadata {

        /// Access the sec_protocol_metadata_t for a given network protocol
        /// metadata instance. See <Security/SecProtocolMetadata.h> for functions
        /// to further access security metadata.
        /*public var securityProtocolMetadata: sec_protocol_metadata_t {
            get {
                return sec_protocol_metadata_t()
            }
        }*/
    }
}


//@available(OSX 10.14, iOS 12.0, watchOS 5.0, tvOS 12.0, *)
public class NWProtocolUDP : NWProtocol {

    public static let definition: NWProtocolDefinition = NWProtocolDefinition("udp")

    public class Options : NWProtocolOptions {
        public override var definition: NWProtocolDefinition {
            return NWProtocolUDP.definition
        }
        /// Configure UDP to skip computing checksums when sending.
        /// This will only take effect when running over IPv4 (UDP_NOCKSUM).
        public var preferNoChecksum: Bool = false

        /// Create UDP options to set in an NWParameters.ProtocolStack
        public override init() {}
    }

    public class Metadata : NWProtocolMetadata {

        /// Create an empty UDP metadata to send with ContentContext
        public override init() {}
    }
}
