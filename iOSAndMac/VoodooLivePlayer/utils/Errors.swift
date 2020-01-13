//
//  Errors.swift
//  VoodooLivePlayer
//
//  Created by voodoo on 2019/12/10.
//  Copyright © 2019 Voodoo-Live. All rights reserved.
//

import Foundation

public final class FormatError : Error {
    
}

enum PipelineErrors : Error {
    case create_renderers_failed
}
