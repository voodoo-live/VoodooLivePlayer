//
//  LiveFLVLoader.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/4.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation


class LiveFLVLoader : NSObject, LiveLoaderProtocol, URLSessionDataDelegate {
    
    
    var delegate: LiveLoaderDelegate?
    
    var delegateQueue: DispatchQueue?
    
    let source: LiveStreamSource
    var session : URLSession?
    var task : URLSessionDataTask?
    var totalSize: Int64 = 0
    
    init(source: LiveStreamSource) {
        self.source = source
    }
    
    func start() -> Bool {
        if self.session == nil {
            let queue = OperationQueue()
            queue.underlyingQueue = delegateQueue
            queue.maxConcurrentOperationCount = 1
            self.session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: queue)
        }
        
        if let session = self.session {
            let request = URLRequest(url: source.url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
            print(">> URL \(self.source.url) REQUESTED")
            task = session.dataTask(with: request)
            totalSize = 0
            task!.resume()
            return true
        }
        return false
    }
    
    func stop() {
        if let loaderTask = task {
            loaderTask.cancel()
            task = nil
        }
    }
    
    @available(iOS 7.0, *)
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        totalSize += Int64(data.count)
        delegate?.handle(loaderData: data, withType: .rawData)
    }
    
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            if let urlError = error as? URLError {
                if urlError.code == URLError.Code.cancelled {
                    print(">> URL \(self.source.url) CANCELLED")
                    return
                }
            }
            print("URL SESSION REQUEST ERROR -", error!)
            task.cancel()
        } else {
            print("URL SESSION REQUEST ERROR WITH NO INFO")
        }
        if task == self.task {
            self.task = nil
        }
        
        delegate?.handle(loaderError: error)
    }
}


