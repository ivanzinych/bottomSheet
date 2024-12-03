//
//  RootViewController.swift
//  BottomSheet
//
//  Created by Иван Зиныч on 03.12.2024.
//

import UIKit

class RootViewController: UIViewController {
    
    private let button: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("открыть bottom sheet", for: [])
        
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        button.addTarget(self, action: #selector(buttonTap), for: .touchUpInside)
        view.addSubview(button)
        
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    @objc
    private func buttonTap() {
        let controller = ViewController()
        let viewController = SheetPresentationController(controller: controller,
                                                        // sizes: [.intrinsic],
                                                         sizes: [.percent(0.5)],
                                                         options: SheetOptions())
        present(viewController, animated: true, completion: nil)
    }
}
