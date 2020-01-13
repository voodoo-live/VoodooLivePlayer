//
//  NWSocket.swift
//  VoodooNetwork
//
//  Created by voodoo on 2019/12/31.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public final class NWSocket {
    let fd : Int32
    let family: Int32
    let type: Int32
    let proto: Int32
    
    public private(set) var error: NWError = .none
    private func handleSocketError(_ ret:Int) -> Int {
        if ret < 0 {
            error = NWError(posixError: errno)
        }
        return ret
    }
    private func handleSocketError(_ ret:Int32) -> Int {
        return handleSocketError(Int(ret))
    }
    
    public init?(family: Int32 = AF_INET, type: Int32 = SOCK_STREAM, proto: Int32 = 0) {
        fd = socket(family, type, proto)
        if fd < 0 {
            print("ERROR AT socket:\(errno) ", String(cString:strerror(errno)))
            return nil
        }
        self.family = family
        self.type = type
        self.proto = proto
    }
    
    deinit {
        Darwin.close(fd)
    }
    
    public func setBlock(_ block:Bool) -> Bool {
        var flags = fcntl(fd, F_GETFL, 0)
        if flags < 0 {
            let _ = handleSocketError(flags)
            //print("ERROR AT fcntl(F_GETFL):\(errno) ", String(cString:strerror(errno)))
            return false
        }
        
        if block {
            flags = flags & ~O_NONBLOCK
        } else {
            flags = flags | O_NONBLOCK
        }
        
        if handleSocketError(fcntl(fd, F_SETFL, flags|O_NONBLOCK)) < 0 {
            return false
        }

        return true
    }
    
    public func send(data:UnsafeRawPointer?, size:Int) -> Int {
        return handleSocketError(Darwin.send(fd, data, size, 0))
    }
    
    public func recv(buffer:UnsafeMutableRawPointer?, len:Int) -> Int {
        return handleSocketError(Darwin.recv(fd, buffer, len, 0))
    }
    
    public func send(data:UnsafeRawBufferPointer?) -> Int {
        return handleSocketError(Darwin.send(fd, data?.baseAddress ?? nil, data?.count ?? 0, 0))
    }
    
    public func recv(buffer:UnsafeMutableRawBufferPointer?) -> Int {
        return handleSocketError(Darwin.recv(fd, buffer?.baseAddress ?? nil, buffer?.count ?? 0, 0))
    }
    
    public func sendto(addr:UnsafePointer<sockaddr>, data:UnsafeRawPointer, size:Int) -> Int {
        return handleSocketError(Darwin.sendto(fd, data, size, 0, addr, socklen_t(addr.pointee.sa_len)))
    }
    
    public func recvfrom(addr:UnsafeMutablePointer<sockaddr>, buffer:UnsafeMutableRawPointer, len:Int) -> Int {
        var addrLen = socklen_t(addr.pointee.sa_len)
        let ret = handleSocketError(Darwin.recvfrom(fd, buffer, len, 0, addr, &addrLen))
        addr.pointee.sa_len = UInt8(addrLen)
        return ret
    }
    
    public func sendto(addr:UnsafePointer<sockaddr>, data:UnsafeRawBufferPointer) -> Int {
        return handleSocketError(Darwin.sendto(fd, data.baseAddress, data.count, 0, addr, socklen_t(addr.pointee.sa_len)))
    }
    
    public func recvfrom(addr:UnsafeMutablePointer<sockaddr>, buffer:UnsafeMutableRawBufferPointer) -> Int {
        var addrLen = socklen_t(addr.pointee.sa_len)
        let ret = handleSocketError(Darwin.recvfrom(fd, buffer.baseAddress, buffer.count, 0, addr, &addrLen))
        addr.pointee.sa_len = UInt8(addrLen)
        return ret
    }
    
    public func bind(addr:UnsafePointer<sockaddr>) -> Int {
        return handleSocketError(Darwin.bind(fd, addr, socklen_t(addr.pointee.sa_len)))
    }
    
    public func listen(backlogs:Int) -> Int {
        return handleSocketError(Darwin.listen(fd, Int32(backlogs)))
    }
    
    public func connect(addr:UnsafePointer<sockaddr>) -> Int {
        return handleSocketError(Darwin.connect(fd, addr, socklen_t(addr.pointee.sa_len)))
    }
    
    public func connectx(addr:UnsafePointer<sockaddr>, iovecs:UnsafePointer<iovec>? = nil, iovecnt:Int = 0) -> Int {
        var ep = sa_endpoints_t()
        ep.sae_srcif = 0
        ep.sae_srcaddr = nil
        ep.sae_srcaddrlen = 0
        ep.sae_dstaddr = addr
        ep.sae_dstaddrlen = socklen_t(addr.pointee.sa_len)
        var sentlen:Int = 0
        let ret = handleSocketError(Darwin.connectx(fd, &ep,sae_associd_t(SAE_ASSOCID_ANY), UInt32(CONNECT_DATA_IDEMPOTENT|CONNECT_RESUME_ON_READ_WRITE), iovecs, UInt32(iovecnt), &sentlen, nil))
        if ret == 0 {
            if iovecnt > 0 && sentlen > 0 {
                return sentlen
            }
        }
        return ret
    }
    
    public func disconnectx() -> Int {
        return handleSocketError(Darwin.disconnectx(fd, sae_associd_t(SAE_ASSOCID_ANY), sae_connid_t(SAE_CONNID_ANY)))
    }
    
    public func shutdown(how:Int32) -> Int {
        return handleSocketError(Darwin.shutdown(fd, how))
    }
    
    public func getpeername(addr:UnsafeMutablePointer<sockaddr>) -> Int {
        var addrLen:socklen_t = 0
        let ret = handleSocketError(Darwin.getpeername(fd, addr, &addrLen))
        if ret != -1 {
            addr.pointee.sa_len = UInt8(addrLen)
        }
        return ret
    }
}

