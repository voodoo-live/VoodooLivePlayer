//
//  RTMPError.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2020/1/9.
//  Copyright © 2020 Voodoo-Live. All rights reserved.
//

import Foundation

enum RTMPError : Error {
    
    case none
    case warpedError(Error)
    case versionNotMatch
    case handShakeWrongResponseSize
}
