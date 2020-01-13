//
//  NWResolver.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public class NWResolver {

    
    public enum ResolveError : Hashable, CustomDebugStringConvertible {
        case no_records
        case exceed_max_retry_times
        case gai_error(Int32,String)
        
        init(gaiError:Int32) {
            self = .gai_error(gaiError, String(cString:gai_strerror(gaiError)))
        }
        
        public var debugDescription: String {
            get {
                switch self {
                case .exceed_max_retry_times:
                    return ".exceed_max_retry_times"
                case .no_records:
                    return ".no_records"
                case let .gai_error(code, desc):
                    return ".gai_error(\(code), \(desc))"
                //default:
                //    break
                }
                //return ""
            }
        }
        
        public var hashValue: Int {
            get {
                var hasher = Hasher()
                self.hash(into: &hasher)
                return hasher.finalize()
            }
        }
        
        
        
        public func hash(into hasher:inout Hasher) {
            switch self {
            case let .gai_error(code, _):
                hasher.combine(".gai_error")
                hasher.combine(code)
            default:
                hasher.combine(self.debugDescription)
            }
        }
    }
    
    public enum Result {
        case failed(ResolveError)
        case success(Data!, Data!, String!)
    }
    
    private let host: String?
    private var hostCString:[CChar]?
    private let service: String?
    private var serviceCString:[CChar]?

    public var queue:DispatchQueue?
    
    public enum ResultType {
        case v4
        case v6
        case both
    }
    
    public enum TargetType {
        case hostOnly(String)
        case ipOnly(String)
        case portOnly(UInt16)
        case serviceOnly(String)
        case hostAndPort(String, UInt16)
        case hostAndService(String, String)
        case ipAndPort(String, UInt16)
        case ipAndService(String, String)
    }
    
    public enum ResultUseType {
        case listen
        case connect
        case cname
    }
    
    public enum ResultProtocol {
        case tcp
        case udp
        case unspec
    }
    
    init(target:TargetType, resultType:ResultType = .both, resultUseType: ResultUseType = .connect, resultProtocol:ResultProtocol = .unspec) {
        var flags = Int32(0)
        
        switch target {
        case let .hostOnly(host):
            self.host = host
            self.service = nil
        case let .ipOnly(ip):
            self.host = ip
            self.service = nil
            flags = flags | AI_NUMERICHOST
        case let.portOnly(port):
            self.host = nil
            self.service = String(format: "%u", port)
            flags = flags | AI_NUMERICSERV
        case let.serviceOnly(service):
            self.host = nil
            self.service = service
        case let.hostAndPort(host, port):
            self.host = host
            self.service = String(format: "%u", port)
            flags = flags | AI_NUMERICSERV
        case let .hostAndService(host, service):
            self.host = host
            self.service = service
        case let .ipAndPort(ip, port):
            self.host = ip
            self.service = String(format: "%u", port)
            flags = flags | AI_NUMERICHOST | AI_NUMERICSERV
        case let .ipAndService(ip, service):
            self.host = ip
            self.service = service
            flags = flags | AI_NUMERICHOST
        }
        if self.host != nil {
            self.hostCString = self.host?.cString(using: .utf8)
        }
        if self.service != nil {
            self.serviceCString = self.service?.cString(using: .utf8)
        }
        
        switch resultType {
        case .v4:
            hint.ai_family = PF_INET
        case .v6:
            hint.ai_family = PF_INET6
        case .both:
            hint.ai_family = PF_UNSPEC
        }
        
        switch resultUseType {
        case .listen:
            flags |= AI_PASSIVE
        case .connect:
            flags |= 0
        case .cname:
            flags |= AI_CANONNAME
        }
        
        switch resultProtocol {
        case .tcp:
            hint.ai_protocol = IPPROTO_TCP
            hint.ai_socktype = SOCK_STREAM
        case .udp:
            hint.ai_protocol = IPPROTO_UDP
            hint.ai_socktype = SOCK_DGRAM
        case .unspec:
            hint.ai_protocol = 0
            hint.ai_socktype = 0
        }
        
        hint.ai_flags = flags
    }
    
    deinit {
        result.deallocate()
    }
    
    private var hint = addrinfo()
    private let result = UnsafeMutablePointer<UnsafeMutablePointer<addrinfo>?>.allocate(capacity: 1)
    private var loopCount = 0
    private var asyncResult: NWAsyncResult<Result>?
    public func start(queue:DispatchQueue? = nil) -> NWAsyncResult<Result> {
        self.queue = queue ?? DispatchQueue.global()
        self.asyncResult = NWAsyncResult<Result>(dispatchQueue: self.queue!)
        
        self.queue?.async {
            self.internalLoop()
        }
        
        return self.asyncResult!
    }
    
    private func parseResult() {
        let ptr = result.pointee
        var ap = ptr
        
        var v4Data:Data!
        var v6Data:Data!
        var cname:String!
        
        while ap != nil {
            //let addrInfo = ap!.pointee
            
            if (ap!.pointee.ai_flags & AI_CANONNAME) != 0 &&
                ap!.pointee.ai_canonname != nil {
                cname = String(cString: ap!.pointee.ai_canonname)
            }
            
            if ap!.pointee.ai_family == PF_INET && v4Data == nil {
                v4Data = Data(bytes: ap!.pointee.ai_addr, count: MemoryLayout<sockaddr_in>.size)
            } else if ap!.pointee.ai_family == PF_INET6 && v6Data == nil {
                v6Data = Data(bytes: ap!.pointee.ai_addr, count: MemoryLayout<sockaddr_in6>.size)
            }
            
            ap = ap!.pointee.ai_next
        }
        
        freeaddrinfo(ptr)
        result.pointee = nil
        
        if v4Data == nil && v6Data == nil && cname == nil {
            self.asyncResult?.signal(value: .failed(.no_records))
        } else {
            self.asyncResult?.signal(value: .success(v4Data, v6Data, cname))
        }
    }
    
    private var resolveResult:Int32 = -1
    private func internalLoop() {
        self.loopCount += 1
        
        let ret = getaddrinfo(self.hostCString, self.serviceCString, &self.hint, result)
        if ret == 0 {
            parseResult()
            return
        }
        
        if ret != EAI_AGAIN {
            self.asyncResult?.signal(value: .failed(.init(gaiError:ret)))
            return
        }
        if self.loopCount < 8 {
            queue?.async {
                self.internalLoop()
            }
        } else {
            self.asyncResult?.signal(value: .failed(.exceed_max_retry_times))
        }
    }
    
}


extension NWResolver {
    public enum ResolveEndPointResult {
        case success([NWSockAddr])
        case failed(NWError)
    }
    
    /**
     todo: use correct interface
     */
    public static func resolveEndpoint(_ endpoint:NWEndpoint, resultType:ResultType = .both, resultUseType: ResultUseType = .connect, resultProtocol:ResultProtocol = .unspec) -> ResolveEndPointResult {
        switch endpoint {
        case let .hostPort(host, port):
            var resolveTarget: TargetType
            switch host {
            case let .name(hostName, _):
                print("HOST NAME:", hostName)
                resolveTarget = TargetType.hostAndPort(hostName, port.rawValue)
            case let .ipv4(v4addr):
                resolveTarget = .ipAndPort(v4addr.stringValue, port.rawValue)
            case let .ipv6(v6addr):
                resolveTarget = .ipAndPort(v6addr.stringValue, port.rawValue)
            }

            if let result = NWResolver(target: resolveTarget, resultType: .both).start().waitResult() {
                switch result {
                case let .success(v4Data, v6Data, _):
                    var sockAddrs = [NWSockAddr]()
                    
                    if let v4AddrData = v4Data, let sockAddr = NWSockAddr(data:v4AddrData) {
                        sockAddrs.append(sockAddr)
                    }
                    
                    if let v6AddrData = v6Data, let sockAddr = NWSockAddr(data:v6AddrData) {
                        sockAddrs.append(sockAddr)
                    }
                    
                    return .success(sockAddrs)
                case let .failed(e):
                    return .failed(.resolve(e))
                }
            }
        case .sockAddrs(let addrs):
            return .success(addrs)
        }
        
        return .failed(.resolve(.no_records))
    }
}
