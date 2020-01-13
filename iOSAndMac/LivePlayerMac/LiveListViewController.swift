//
//  LiveListViewController.swift
//  LivePlayerMac
//
//  Created by voodoo on 2019/12/23.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Cocoa
import VoodooLivePlayer

class LiveListViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, LiveListDownloaderDelegate, URLSessionDownloadDelegate {
    @IBAction func refreshLiveList(_ sender: NSToolbarItem) {
        print("REFRESH")
        

    }
    
    @IBOutlet weak var tableView: NSTableView!
    var urlSession: URLSession!
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let image = NSImage(contentsOf: location) {
            for i in 0..<self.liveList.count {
                
                if self.liveList[i].downloadTask?.isEqual(downloadTask) ?? false {
                    self.liveList[i].coverImage = image
                    //print("set image for", item.title, item.cellIndex)
                    if let cellIndex = self.liveList[i].cellIndex {
                        print("RELOAD ", cellIndex)
                        /*if let cell = self.tableView.cellForRow(at: cellIndex) {
                            cell.imageView?.image = item.coverImage
                            let imageSize = CGSize(width: 100, height: 70)
                            UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
                            let imageRect = CGRect(x: 0, y: 0, width: 100, height: 70)
                            cell.imageView?.image?.draw(in: imageRect)
                            cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
                            UIGraphicsEndImageContext()

                            cell.imageView?.setNeedsLayout()
                        }*/
                        let indexSet:IndexSet = IndexSet(arrayLiteral: cellIndex)
                        let columnSet:IndexSet = IndexSet(arrayLiteral: 0)
                        self.tableView.reloadData(forRowIndexes: indexSet, columnIndexes: columnSet)
//                        self.tableView.reloadRows(at: [cellIndex], with: .none)
                    }
                    break
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("URL SESSION REQUEST ERROR -", error!)
        } else {
            print("URL SESSION REQUEST ERROR WITH NO INFO")
        }
        
    }
    
    
    
    var loaded = false
    var xiguaLiveList: LiveListXiGua!
    //var liveList: Array<LiveListItem>!
    
    
    struct ListListCellData {
        var coverImage: NSImage?
        var title: String
        var flvUrl: String
        var hlsUrl: String
        var rtmpUrl: String
        var coverUrl: String
        var downloadTask: URLSessionDownloadTask?
        var cellIndex: Int?
    }
    
    var liveList: [ListListCellData]!
    
    func handle(downloader: LiveListDownloader?, error: Error?) {
        print("DOWNLOAD ERROR:", error ?? "NONE")
        loaded = false
        DispatchQueue.main.async {
            //self.indicator.stopAnimating()
        }
    }
    
    func handle(downloader: LiveListDownloader?, liveList: Array<LiveListItem>) {
        

        //self.liveList = liveList
        
        self.liveList = [ListListCellData]()
        self.liveList.reserveCapacity(liveList.count)
        
        for item in liveList {
            let downloadTask = urlSession.downloadTask(with: URL(string: item.coverUrl!)!)
            self.liveList.append(LiveListViewController.ListListCellData(coverImage: nil, title: item.title, flvUrl: item.flvUrl!, hlsUrl: item.hlsUrl!, rtmpUrl: "", coverUrl: item.coverUrl!, downloadTask: downloadTask))
            downloadTask.resume()
            
            print(item.title, "LOADED!")
        }
        
        self.liveList.append(LiveListViewController.ListListCellData(title: "本地测试", flvUrl: "http://localhost:10080/live?port=1935&app=myapp&stream=s1", hlsUrl: "", rtmpUrl: "rtmp://192.168.88.11:1935/myapp/s1", coverUrl: ""))
        
        //print(self.liveList)
        loaded = true
        DispatchQueue.main.async {
            //self.indicator.stopAnimating()
            self.tableView.reloadData()
            //(self.view as! UITableView).reloadData()
            //(self.view as UITableView).
        }
        
    }
    
    
    func reloadList() {
         print("RELOAD LIST")
        loaded = false
        liveList = nil
        tableView.reloadData()
        
        xiguaLiveList.load()
    }
    
    
    
    var refreshImage: NSImage?
    
    let liveListCellID = "LiveListCellID"
    override func viewDidLoad() {
        super.viewDidLoad()
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        // Do view setup here.
        refreshImage = NSImage(named: "refresh")
        
        xiguaLiveList = LiveListXiGua(delegate: self)
        xiguaLiveList.load()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.loaded ? self.liveList.count : 0
    }
    
    var preferredLiveType: LiveStreamSource.SourceType = .HTTP_FLV
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        print("TABLE VIEW SELECTION CHANGED:", notification)
        

        if let splitViewControl = self.view.window?.contentViewController as? NSSplitViewController {
            let rowIndex = tableView.selectedRow
            if rowIndex < 0 || rowIndex >= liveList.count {
                return
            }
            
            
            
            //splitViewControl.view as NSSplitView
            let selfItem = splitViewControl.splitViewItem(for: self)
            var playItem: NSSplitViewItem!
            if splitViewControl.splitViewItems[0].isEqual(selfItem) {
                playItem = splitViewControl.splitViewItems[1]
            } else {
                playItem = splitViewControl.splitViewItems[0]
            }
            
            if let liveViewController = playItem.viewController as? LiveViewController {
                let urls:[String?] = [
                    liveList[rowIndex].flvUrl.count == 0 ? nil : liveList[rowIndex].flvUrl,
                    liveList[rowIndex].rtmpUrl.count == 0 ? nil : liveList[rowIndex].rtmpUrl,
                    liveList[rowIndex].hlsUrl.count == 0 ? nil : liveList[rowIndex].hlsUrl,
                ]
                let startIndex = preferredLiveType.rawValue
                var chooseIndex = -1
                for i in 0..<3 {
                    let index = (i+startIndex) % 3
                    if urls[index] != nil {
                        print("CHOOSE INDEX: \(index) VALUE: \(urls[index]!)")
                        chooseIndex = index
                        break
                    }
                }
                if chooseIndex < 0 {
                    print("NO URLS FOR THIS LIVE")
                    liveViewController.source = nil
                } else {
                    if let url = URL(string: urls[chooseIndex]!) {
                        
                        let sourceType = LiveStreamSource.SourceType(rawValue: chooseIndex)!
                        print("INDEX: \(chooseIndex) URL: \(url) TYPE: \(sourceType)")
                        liveViewController.source = LiveStreamSource(title: liveList[rowIndex].title, url: url, type: LiveStreamSource.SourceType(rawValue: chooseIndex)!)
                    }
                    
                }
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let cellView = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: liveListCellID), owner: nil) as? NSTableCellView {
            
            print("ROW:", row)
            if liveList[row].cellIndex == nil {
                liveList[row].cellIndex = row
            }
            cellView.textField?.stringValue = liveList[row].title
            cellView.imageView?.image = liveList[row].coverImage ?? refreshImage
            return cellView
        }
        
        return nil
    }
}
