//
//  LiveHLSLoader.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/9.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

class LiveHLSLoader : LiveLoaderProtocol {
    var delegate: LiveLoaderDelegate?
    
    var delegateQueue: DispatchQueue?
    
    func start() -> Bool {
        true
    }
    
    func stop() {
        
    }
    
}
