//
//  LiveListDownloader.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/13.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public struct LiveListItem {
    public var flvUrl:String?
    public var hlsUrl:String?
    public var coverUrl:String?
    public var title:String
    public var name:String
}


public protocol LiveListDownloaderDelegate : class {
    func handle(downloader:LiveListDownloader?,error:Error?)
    func handle(downloader:LiveListDownloader?,liveList:Array<LiveListItem>)
}


public class LiveListDownloader {
    public weak var delegate:LiveListDownloaderDelegate?
    public var urlSession:URLSession
    init() {
        urlSession = URLSession(configuration: .default)
    }
    public func load() {}
    public func handle(downloadContent:String?, error:Error?) {}
    public func download(url:String) {
        if let httpURL = URL(string: url) {
            let task = urlSession.dataTask(with: httpURL) { (data:Data?, res:URLResponse?, error:Error?) in
                if error != nil {
                    self.handle(downloadContent: nil, error: error)
                } else {
                    if let contentData = data, let content = String(bytes: contentData, encoding: .utf8) {
                        self.handle(downloadContent: content, error: nil)
                    } else {
                        self.handle(downloadContent: nil, error: URLError(URLError.cannotParseResponse))
                    }
                }
            }
            task.resume()
        } else {
            handle(downloadContent: nil, error: URLError(URLError.cannotLoadFromNetwork))
        }
    }
}
