//
//  NWNetworkConfiguration.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/2.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation
import SystemConfiguration

class NWNetworkConfiguration {

    class ProxyConfiguration {
        enum ExceptionItem {
            case host(String)
            case hostSuffix(String)
            case hostPrefix(String)
            case ipv4(IPv4Address)                  //  192.168.1.99
            case ipv4Filter(IPv4Address,Int)        //  192.168.0.0/16
            case ipv6(IPv6Address)                  //  fe80::1
            case ipv6Filter(IPv6Address,Int)        //  fe80::/16
        }
        var isSocksEnabled:Bool = false
        var isHttpEnabled:Bool = false
        var isHttpsEnabled:Bool = false
        var socksAddr:String!
        var socksPort:UInt16!
        var socksUsername:String!
        var socksPassword:String!
        var httpAddr:String!
        var httpPort:UInt16!
        var httpsAddr:String!
        var httpsPort:UInt16!
        var exceptionList:[ExceptionItem] = []
        
        init?() {
            if !ProxyConfiguration.readConfiguration(self) {
                return nil
            }
        }
        
        private func checkHostNameInException(hostName:String) -> Bool {
            for exceptionItem in exceptionList {
                switch exceptionItem {
                case let .host(host):
                    if host == hostName { return true }
                case let.hostPrefix(prefix):
                    if hostName.hasPrefix(prefix) { return true }
                case let.hostSuffix(suffix):
                    if hostName.hasSuffix(suffix) { return true }
                default:
                    break
                }
            }
            return false
        }
        
        private func checkIPv4InException(addr:IPv4Address) -> Bool {
            for exceptionItem in exceptionList {
                switch exceptionItem {
                case let .ipv4(v4Addr) where v4Addr == addr:
                    return true
                case let .host(localhost) where localhost == "localhost" && addr.isLoopback:
                    return true
                case let .ipv4Filter(v4Addr, mask) where v4Addr.withMask(maskBits: mask) == addr:
                    return true
                default:
                    break
                }
            }
            return false
        }
        
        private func checkIPv6InException(addr:IPv6Address) -> Bool {
            for exceptionItem in exceptionList {
                switch exceptionItem {
                case let .host(localhost) where localhost == "localhost" && addr.isLoopback:
                    return true
                case let .ipv6(v6Addr) where v6Addr == addr:
                    return true
                case let .ipv6Filter(v6Addr, mask) where v6Addr.withMask(maskBits: mask) == addr:
                    return true
                default:
                    break
                }
            }
            return false
        }
        
        func checkInExceptionList(host:NWEndpoint.Host) -> Bool {
            switch host {
            case let .name(hostName, _):
                return checkHostNameInException(hostName: hostName)
            case let .ipv4(v4Addr):
                return checkIPv4InException(addr: v4Addr)
            case let .ipv6(v6Addr):
                return checkIPv6InException(addr: v6Addr)
            }
        }
        
        func checkInExceptionList(endpoint:NWEndpoint) -> Bool {
            switch endpoint {
            case let .hostPort(host, _):
                return checkInExceptionList(host: host)
            default:
                return false
            }
        }

        class func readConfiguration(_ configuration:ProxyConfiguration) -> Bool {
            #if os(iOS)
            let dictResult = CFNetworkCopySystemProxySettings()
            guard dictResult != nil else { return false }
            let dict = dictResult!.takeUnretainedValue()
            #elseif os(OSX)
            let dictResult = SCDynamicStoreCopyProxies(nil)
            guard dictResult != nil else { return false }
            let dict = dictResult!
            #endif
            
            let nsdict = dict as NSDictionary
            let swdict = nsdict as Dictionary
            /*
            swdict.forEach { (tup:(key: NSObject, value: AnyObject)) in
                let strKey = tup.key as! String
                
                let strValue = tup.value as? String
                var intValue: Int
                if strValue == nil {
                    intValue = tup.value as? Int ?? -1
                } else {
                    intValue = 0
                }
                
                print(strKey, strValue ?? intValue)
                
            }
            */
            let exceptionsList = (swdict["ExceptionsList" as NSString] as? Array<String>) ?? []
            
            let ipv4FilterPattern = #"^((2(5[0-5]|4\d)|[0-1]?\d\d?)\.){3}(2(5[0-5]|4\d)|[0-1]?\d\d?)/([0-2]?\d|3[0-2])$"#
            let ipv4Pattern = #"^((2(5[0-5]|4\d)|[0-1]?\d\d?)\.){3}(2(5[0-5]|4\d)|[0-1]?\d\d?)$"#
            let ipv6Pattern = #"^((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?$"#
            let ipv6FilterPattern = #"^((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?/(12[0-8]|1[0-1]\d|\d\d?)$"#
            
            exceptionsList.forEach { (itemString) in
                print("EXCEPTION ITEM:", itemString)
                    
                if let _ = itemString.range(of: ipv4Pattern, options: .regularExpression) {
                    if let v4Addr = IPv4Address(itemString) {
                        configuration.exceptionList.append(.ipv4(v4Addr))
                    }
                } else if let _ = itemString.range(of: ipv4FilterPattern, options: .regularExpression) {
                    if let index = itemString.lastIndex(of: "/") {
                        let ipPart = String(itemString[itemString.startIndex..<index])
                        let maskPart = itemString[itemString.index(index, offsetBy: 1)..<itemString.endIndex]
                        if let v4Addr = IPv4Address(ipPart) {
                            configuration.exceptionList.append(.ipv4Filter(v4Addr, Int(maskPart)!))
                        }
                    }
                } else if let _ = itemString.range(of: ipv6Pattern, options: .regularExpression) {
                    if let v6Addr = IPv6Address(itemString) {
                        configuration.exceptionList.append(.ipv6(v6Addr))
                    }
                } else if let _ = itemString.range(of: ipv6FilterPattern, options: .regularExpression) {
                    if let index = itemString.lastIndex(of: "/") {
                        let ipPart = String(itemString[itemString.startIndex..<index])
                        let maskPart = itemString[itemString.index(index, offsetBy: 1)..<itemString.endIndex]
                        if let v6Addr = IPv6Address(ipPart) {
                            configuration.exceptionList.append(.ipv6Filter(v6Addr, Int(maskPart)!))
                        }
                    }
                } else if itemString.hasPrefix("*.") {
                    configuration.exceptionList.append(.hostSuffix(String(itemString.suffix(itemString.count-2))))
                } else if itemString.hasSuffix(".*") {
                    configuration.exceptionList.append(.hostPrefix(String(itemString.prefix(itemString.count-2))))
                } else {
                    configuration.exceptionList.append(.host(itemString))
                }
            }
            
            configuration.isSocksEnabled = ((swdict["SOCKSEnable" as NSString] as? Int) ?? 0) == 1
            if configuration.isSocksEnabled {
                configuration.socksAddr = swdict["SOCKSProxy" as NSString] as? String
                configuration.socksPort = swdict["SOCKSPort" as NSString] as? UInt16
                configuration.socksUsername = swdict["SOCKSUsername" as NSString] as? String
                configuration.socksPassword = swdict["SOCKSPassword" as NSString] as? String
            }
            configuration.isHttpEnabled = ((swdict["HTTPEnable" as NSString] as? Int) ?? 0) == 1
            if configuration.isHttpEnabled {
                configuration.httpAddr = swdict["HTTPProxy" as NSString] as? String
                configuration.httpPort = swdict["HTTPPort" as NSString] as? UInt16
            }
            configuration.isHttpsEnabled = ((swdict["HTTPSEnable" as NSString] as? Int) ?? 0) == 1
            if configuration.isHttpsEnabled {
                configuration.httpsAddr = swdict["HTTPSProxy" as NSString] as? String
                configuration.httpsPort = swdict["HTTPSPort" as NSString] as? UInt16
            }
            
            return true
        }
    }


    let proxyConfiguration = ProxyConfiguration()
    
    
    static var shared: NWNetworkConfiguration = {
        return NWNetworkConfiguration()
    }()
}
