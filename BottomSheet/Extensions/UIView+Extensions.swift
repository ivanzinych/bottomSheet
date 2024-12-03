//
//  UIView+Extensions.swift
//  BottomSheet
//
//  Created by Иван Зиныч on 03.12.2024.
//

import UIKit

extension UIView {
    var safeAreaBottomHeight: CGFloat {
        if #available(iOS 11.0, *) {
            return window?.safeAreaInsets.bottom ?? UIApplication.shared.rootViewController?.view.safeAreaInsets.bottom ?? 0
        }
        
        return 0
    }
}
