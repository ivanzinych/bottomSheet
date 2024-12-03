//
//  SheetView.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 18.09.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit

protocol SheetViewDelegate: AnyObject {
    func sheetPoint(inside point: CGPoint, with event: UIEvent?) -> Bool
}

class SheetView: UIView {

    weak var delegate: SheetViewDelegate?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return self.delegate?.sheetPoint(inside: point, with: event) ?? true
    }
}
