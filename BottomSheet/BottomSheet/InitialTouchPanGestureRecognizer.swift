//
//  InitialTouchPanGestureRecognizer.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 18.09.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit.UIGestureRecognizerSubclass

class InitialTouchPanGestureRecognizer: UIPanGestureRecognizer {
    var initialTouchLocation: CGPoint?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        initialTouchLocation = touches.first?.location(in: view)
    }
}
