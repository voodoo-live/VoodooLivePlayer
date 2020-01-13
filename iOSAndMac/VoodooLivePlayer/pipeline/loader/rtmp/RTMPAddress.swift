//
//  RTMPAddress.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/9.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

class RTMPAddress {
    enum Scheme : String {
        case rtmp
        case rtmps
    }
    let scheme: Scheme
    let hostName: String
    private let _port: UInt16!
    private var _portString: String { get { (_port != nil) ? ":" + String(_port!) : "" }}
    var port : UInt16 { get { _port ?? 1935 } }
    let appName: String
    let streamName: String
    init?(url:URL) {
        guard url.scheme != nil && url.host != nil else { return nil }
        if let scheme = Scheme.init(rawValue: url.scheme!) {
            self.scheme = scheme
        } else {
            return nil
        }
        let pathParts = url.path.split(separator: "/")
        guard pathParts.count == 2 else { return nil }
        appName = String(pathParts[0])
        streamName = String(pathParts[1])
        hostName = url.host!
        _port = url.port == nil ? nil : UInt16(url.port!)
    }
    
    var tcURL: String { get { "\(scheme)://\(hostName)\(_portString)/\(appName)" } }
    var fullURL: String { get { "\(tcURL)/\(streamName)" } }
}
