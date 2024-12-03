//
//  SelfSizedTableView.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 11.10.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit

class SelfSizedTableView: UITableView {
    
    static let heightUpdatedNotification = Notification.Name(rawValue: "table_view_height_updated")
    
    private var oldHeight: CGFloat = .leastNonzeroMagnitude
    
    private var updateHeightNotificationTimer: Timer?
    
    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
    
    override var contentSize: CGSize {
        didSet {
            invalidateIntrinsicContentSize()
            if oldHeight != contentSize.height {
                sendUpdateHeightNotification()
                oldHeight = contentSize.height
            }
        }
    }
    
    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        if #available(iOS 15.0, *) {
            self.sectionHeaderTopPadding = 0
        }
        self.sectionHeaderHeight = 0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if let footerView = self.tableFooterView, let sizedView = sizing(subview: footerView) {
            self.tableFooterView = sizedView
        }
        if let headerView = self.tableHeaderView, let sizedView = sizing(subview: headerView) {
            self.tableHeaderView = sizedView
        }
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        contentSize
    }
    
    override func reloadData() {
        super.reloadData()
        invalidateIntrinsicContentSize()
    }
    
    private func sendUpdateHeightNotification() {
        updateHeightNotificationTimer?.invalidate()
        updateHeightNotificationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false, block: { _ in
            NotificationCenter.default.post(name: Self.heightUpdatedNotification, object: nil, userInfo: nil)
        })
    }
    
    private func sizing(subview: UIView) -> UIView? {
        let width = self.bounds.size.width
        let size = subview.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height))
        if subview.frame.size.height != size.height {
            subview.frame.size.height = size.height
            return subview
        }
        return nil
    }
}
