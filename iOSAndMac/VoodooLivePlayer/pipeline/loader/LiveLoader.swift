//
//  LiveLoader.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/4.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

protocol LiveLoaderDelegate : class {
    func handle(loaderData data: Data, withType type: LivePipelineDataType)
    func handle(loaderError error: Error?)
}

protocol LiveLoaderProtocol : LivePlayerComponent {
    var delegate: LiveLoaderDelegate? { get set }
    var delegateQueue: DispatchQueue? { get set }
}
