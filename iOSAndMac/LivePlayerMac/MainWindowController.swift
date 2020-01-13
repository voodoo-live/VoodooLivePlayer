//
//  MainWindowController.swift
//  LivePlayerMac
//
//  Created by voodoo on 2019/12/26.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Cocoa

class MainWindowController: NSWindowController {

    @IBOutlet weak var stopToolbarItem: NSToolbarItem!
    @IBAction func stopPlay(_ sender: NSToolbarItem) {
        if let splitViewController = contentViewController as? NSSplitViewController {
            if let liveViewController = splitViewController.splitViewItems[1].viewController as? LiveViewController {
                liveViewController.stopLivePlayback()
            }
        }
    }
    
    @IBAction func refreshLiveList(_ sender: Any) {
        if let splitViewController = contentViewController as? NSSplitViewController {
            if let liveListViewController = splitViewController.splitViewItems[0].viewController as? LiveListViewController {
                liveListViewController.reloadList()
            }
        }
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
    
        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    }

}
