//
//  XiguaLive.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/13.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import Network

struct XiGuaStreamURL : Codable {
    var FlvUrl:String?
    var HlsUrl:String?
    var Name:String?
    var Resolution:String?
}

struct XiGuaRoomItem : Codable {
    var title:String?
    var cover_url:String?
    var room_id:String?
    var user_id:Int64?
    var stream_url:Array<XiGuaStreamURL>?
    var short_id:Int32?
}


public class LiveListXiGua : LiveListDownloader {
    //static let startLabel = "id=\"SSR_HYDRATED_DATA\">"
    public init(delegate:LiveListDownloaderDelegate?) {
        super.init()
        self.delegate = delegate
    }
    public override func load() {
        self.download(url: "https://live.ixigua.com")
    }
    static let startLabel = ",\"banners\":"
    static let endLabel = "},\"youQingLinks\":"
    func replaceHttpToHttps(url:String) -> String {
        if url.starts(with: "http://") {
            if let endIndex = url.firstIndex(of: "/") {
                return url.replacingCharacters(in: url.startIndex..<endIndex, with: "https:")
            }
        }
        return url
    }
    func parseList(content:String) -> Bool {
        if let startRange = content.range(of: LiveListXiGua.startLabel) {
            if let endRange = content.range(of: LiveListXiGua.endLabel) {
                //let subRange = startRange.upperBound..<endRange.lowerBound
                let jsonString = content[startRange.upperBound..<endRange.lowerBound]
                let decoder = JSONDecoder()
                
                if let data = jsonString.data(using: String.Encoding.utf8) {
                    if let list = try? decoder.decode(Array<XiGuaRoomItem>.self, from: data) {

                        //print(list)
                        var liveList = Array<LiveListItem>()
                        for room in list {
                            if let urls = room.stream_url, urls.count > 0 {
                                if let title = room.title {
                                    let flvUrl = replaceHttpToHttps(url: urls[0].FlvUrl!)
                                    let hlsUrl = replaceHttpToHttps(url: urls[0].HlsUrl!)
                                    let coverUrl = replaceHttpToHttps(url: room.cover_url!)
                                    
                                    
                                    liveList.append(LiveListItem(flvUrl: flvUrl, hlsUrl: hlsUrl, coverUrl: coverUrl, title: title, name: title))
                                }
                            }
                        }
                        self.delegate?.handle(downloader: self, liveList: liveList)
                        return true
                    }
                }
            }
        }
        
        return false
    }
    public override func handle(downloadContent: String?, error: Error?) {
        if error != nil {
            print(error!)
            self.delegate?.handle(downloader:self, error: error)
        } else {
            if !parseList(content: downloadContent!) {
                self.delegate?.handle(downloader:self, error: URLError(URLError.cannotParseResponse))
            }
            //self.delegate?.handle(liveList: T##Array<LiveListItem>)
        }
    }
}
