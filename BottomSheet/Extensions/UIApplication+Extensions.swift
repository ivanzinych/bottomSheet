//
//  UIApplication+Extensions.swift
//  BottomSheet
//
//  Created by Иван Зиныч on 03.12.2024.
//

import UIKit

extension UIApplication {
    
    var rootViewController: UIViewController? {
        return UIApplication.shared.keyWindow?.rootViewController
    }
}
