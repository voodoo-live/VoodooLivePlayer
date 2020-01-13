//
//  LiveStreamSource.swift
//  live_common
//
//  Created by voodoo on 2019/12/18.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation



public struct LiveStreamSource {
    public enum SourceType : Int {
        case HTTP_FLV
        case RTMP
        case HLS
        case UNKNOWN
    }
    public var title: String = ""
    public var url: URL
    public var type: SourceType = .UNKNOWN

    
    public init(title:String, url:URL, type:SourceType) {
        self.title = title
        self.url = url
        self.type = type
    }
    
    private struct SourceScheme {
        var leadingString:String
        var isHttp:Bool
        var isRtmp:Bool
        var isSecure:Bool
    }
    
    public static func parse(url:String, title:String = "") -> LiveStreamSource? {
        if let urlObj = URL(string: url) {
            var sourceType: SourceType = .UNKNOWN
            switch urlObj.scheme {
            case "https", "http":
                if urlObj.pathExtension == "m3u8" {
                    sourceType = .HLS
                } else if urlObj.pathExtension == "flv" {
                    sourceType = .HTTP_FLV
                } else {
                    return nil
                }
            case "rtmps", "rtmp":
                sourceType = .RTMP
            default:
                return nil
            }
            return LiveStreamSource(title: title, url: urlObj, type: sourceType)
        } else {
            return nil
        }
    }
}

