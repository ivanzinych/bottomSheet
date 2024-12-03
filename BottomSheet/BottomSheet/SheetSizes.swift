//
//  SheetSizes.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 18.09.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import CoreGraphics

public enum SheetSize: Equatable {
    case intrinsic
    case fixed(CGFloat)
    case fullscreen
    case percent(Float)
    case marginFromTop(CGFloat)
}
