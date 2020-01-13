//
//  NWProtocolLayer.swift
//  VoodooNetwork
//
//  Created by voodoo on 2020/1/2.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation



public protocol NWProtocolLayer : class {
    var name: String { get }
    var prevLayer: NWProtocolLayer? { get set }
    var nextLayer: NWProtocolLayer? { get set }
    var error: NWError { get }
    /**
     control flow
     */
    func open(endpoint: NWEndpoint, in queue:DispatchQueue, using: NWParameters) -> Bool
    func close()
    func read(buffer:UnsafeMutableRawBufferPointer?) -> Int
    func write(data:UnsafeRawBufferPointer?) -> Int
    func pong(state: NWAsyncObjectState)
    /**
     event flow
     */
    func dismissed(layer: NWProtocolLayer)
    func ping()
    func markReady()    
    func markFailed(_ error: NWError)
    func handleWrite(_ len: Int)
    func handleRead(_ len: Int)
    func handleEOF(_ error: Int32)
}

