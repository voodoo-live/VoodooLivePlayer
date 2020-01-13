//
//  LiveListViewController.swift
//  LivePlayeriOS
//
//  Created by voodoo on 2019/12/22.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation
import UIKit
import CoreGraphics
import VoodooLivePlayer

class LiveListViewController : UITableViewController, LiveListDownloaderDelegate, URLSessionDownloadDelegate {
    
    var urlSession: URLSession!
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let fileData = try? Data(contentsOf: location), let image = UIImage(data: fileData) {
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
                        self.tableView.reloadRows(at: [cellIndex], with: .none)
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
        var coverImage: UIImage?
        var title: String
        var flvUrl: String
        var hlsUrl: String
        var coverUrl: String
        var downloadTask: URLSessionDownloadTask?
        var cellIndex: IndexPath?
    }
    
    var liveList: [ListListCellData]!
    
    func handle(downloader: LiveListDownloader?, error: Error?) {
        loaded = false
        DispatchQueue.main.async {
            self.indicator.stopAnimating()
        }
    }
    
    func handle(downloader: LiveListDownloader?, liveList: Array<LiveListItem>) {
        

        //self.liveList = liveList
        
        self.liveList = [ListListCellData]()
        self.liveList.reserveCapacity(liveList.count)
        
        for item in liveList {
            let downloadTask = urlSession.downloadTask(with: URL(string: item.coverUrl!)!)
            self.liveList.append(LiveListViewController.ListListCellData(coverImage: nil, title: item.title, flvUrl: item.flvUrl!, hlsUrl: item.hlsUrl!, coverUrl: item.coverUrl!, downloadTask: downloadTask))
            downloadTask.resume()
            
            print(item.title, "LOADED!")
        }
                self.liveList.append(LiveListViewController.ListListCellData(title: "本地测试", flvUrl: "http://localhost:10080/live?port=1935&app=myapp&stream=s1", hlsUrl: "", coverUrl: ""))
        //print(self.liveList)
        loaded = true
        DispatchQueue.main.async {
            self.indicator.stopAnimating()
            (self.view as! UITableView).reloadData()
            //(self.view as UITableView).
        }
        
    }
    
    var indicator = UIActivityIndicatorView()
    func activityIndicator() {
        
        indicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        //indicator.style = .medium
        indicator.center = self.view.center
        indicator.hidesWhenStopped = true
        //indicator.backgroundColor = UIColor.darkGray
        //indicator.color = UIColor.white
        self.view.addSubview(indicator)
    }
    
    var refreshImage: UIImage!
    
    override func viewDidLoad() {
        
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        activityIndicator()
        
        xiguaLiveList = LiveListXiGua(delegate: self)
        
        xiguaLiveList.load()
        
        indicator.startAnimating()
        /*
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()+DispatchTimeInterval.seconds(5)) {
            self.indicator.stopAnimating()
            print("stop")
        }
        */
        
        refreshImage = UIImage(imageLiteralResourceName: "refresh")
        
        

    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.loaded ? liveList.count : 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var resultCell = tableView.dequeueReusableCell(withIdentifier: "liveListCell")
        if resultCell == nil {
            resultCell = UITableViewCell(style: .default, reuseIdentifier: "liveListCell")
        }
        
        let cell = resultCell!

        let index = indexPath.item
        liveList[index].cellIndex = indexPath
        cell.textLabel?.text = liveList[index].title
        
        if liveList[index].coverImage != nil {
            print("CELL \(index) HAS COVER IAMGE")
            cell.imageView?.image = liveList[index].coverImage
            let imageSize = CGSize(width: 100, height: 70)
            UIGraphicsBeginImageContextWithOptions(imageSize, false, UIScreen.main.scale)
            let imageRect = CGRect(x: 0, y: 0, width: 100, height: 70)
            cell.imageView?.image?.draw(in: imageRect)
            cell.imageView?.image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
        } else {
            print("CELL \(index) HAS NO COVER IAMGE")
            cell.imageView?.image = self.refreshImage
        }
    //        cell.textLabel?.text = liveList[indexPath.row].title
        
    //        cell.accessoryType = .disclosureIndicator
        //cell.imageView = UIImageView(self.refreshImage)
        
        return cell

    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
/*
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedIndex = indexPath.item
        let liveInfo = liveList[selectedIndex]
        let liveViewController = LiveViewController()
        let source = LiveStreamSource(title: liveInfo.title, url: liveInfo.flvUrl, type: .HTTP_FLV)
        liveViewController.source = source
        
        navigationController?.pushViewController(liveViewController, animated: true)
    }*/
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showLive" {
            if let liveViewController = segue.destination as? LiveViewController, let selectedIndexPath = tableView.indexPathForSelectedRow {
                let selectedIndex = selectedIndexPath.item
                let liveInfo = liveList[selectedIndex]
                if let url = URL(string: liveInfo.flvUrl) {
                    let source = LiveStreamSource(title: liveInfo.title, url: url, type: .HTTP_FLV)
                    liveViewController.source = source
                }
            }
        }
    }
}
