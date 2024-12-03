//
//  Compatible.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 11.10.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit

extension UIView {
    open var compatibleSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return self.safeAreaInsets
        } else {
            return .zero
        }
    }
}

extension CALayer {
    open var compatibleMaskedCorners: CACornerMask {
        get {
            if #available(iOS 11.0, *) {
                return self.maskedCorners
            } else {
                return []
            }
        }
        set {
            if #available(iOS 11.0, *) {
                self.maskedCorners = newValue
            }
        }
    }
}

extension UIViewController {
    open var compatibleAdditionalSafeAreaInsets: UIEdgeInsets {
        get {
            if #available(iOS 11.0, *) {
                return self.additionalSafeAreaInsets
            } else {
                return .zero
            }
        }
        set {
            if #available(iOS 11.0, *) {
                self.additionalSafeAreaInsets = newValue
            }
        }
    }
}
