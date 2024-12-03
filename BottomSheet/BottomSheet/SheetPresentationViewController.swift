//
//  SheetPresentationViewController.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 18.09.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit

public protocol SheetPresentationControllerProtocol: AnyObject {
    
    var shouldRecognizePanGestureWithUIControls: Bool { get set }
    
    var dismissOnPull: Bool { get set }
    
    var sizes: [SheetSize] { get set }
    
    var didDismiss: ((SheetPresentationController) -> Void)? { get set }
    
    var completion: (() -> Void)? { get set }
    
    var onDragProgressChange: ((CGFloat) -> Void)? { get set }
    
    func setSizes(_ sizes: [SheetSize], animated: Bool)
    
    func attemptDismiss(animated: Bool, completion: (() -> Void)?)
}

public class SheetPresentationController: UIViewController, SheetPresentationControllerProtocol {
    
    public private(set) var options: SheetOptions
    
    public var onDragProgressChange: ((CGFloat) -> Void)?
    
    /// Default value for autoAdjustToKeyboard. Defaults to true.
    public static var autoAdjustToKeyboard = true
    
    /// Automatically grow/move the sheet to accomidate the keyboard. Defaults to false.
    public var autoAdjustToKeyboard = SheetPresentationController.autoAdjustToKeyboard
    
    /// Default value for allowPullingPastMaxHeight. Defaults to true.
    public static var allowPullingPastMaxHeight = false
    /// Allow pulling past the maximum height and bounce back. Defaults to true.
    public var allowPullingPastMaxHeight = SheetPresentationController.allowPullingPastMaxHeight
    
    /// Default value for allowPullingPastMinHeight. Defaults to true.
    public static var allowPullingPastMinHeight = true
    /// Allow pulling below the minimum height and bounce back. Defaults to true.
    public var allowPullingPastMinHeight = SheetPresentationController.allowPullingPastMinHeight
    
    /// The sizes that the sheet will attempt to pin to. Defaults to intrinsic only.
    public var sizes: [SheetSize] = [.intrinsic] {
        didSet {
            self.updateOrderedSizes()
        }
    }
    public var orderedSizes: [SheetSize] = []
    public private(set) var currentSize: SheetSize = .intrinsic
    /// Allows dismissing of the sheet by pulling down
    public var dismissOnPull: Bool = true {
        didSet {
            self.updateAccessibility()
        }
    }
    /// Dismisses the sheet by tapping on the background overlay
    public var dismissOnOverlayTap: Bool = true {
        didSet {
            self.updateAccessibility()
        }
    }
    /// If true you can pull using UIControls (so you can grab and drag a button to control the sheet)
    public var shouldRecognizePanGestureWithUIControls: Bool = true
    
    /// The view controller being presented by the sheet currently
    public var childViewController: UIViewController {
        return self.contentViewController.childViewController
    }
    
    public override var childForStatusBarStyle: UIViewController? {
        childViewController
    }
    
    public static var hasBlurBackground = false
    public var hasBlurBackground = SheetPresentationController.hasBlurBackground {
        didSet {
            blurView.isHidden = !hasBlurBackground
            overlayView.backgroundColor = hasBlurBackground ? .clear : self.overlayColor
        }
    }
    
    public var minimumSpaceAbovePullBar: CGFloat {
        didSet {
            if self.isViewLoaded {
                self.resize(to: self.currentSize)
            }
        }
    }
    
    private var keyboardShown = false
    
    /// The default color of the overlay background
    public static var overlayColor = UIColor.black.withAlphaComponent(0.5)
    /// The color of the overlay background
    public var overlayColor = SheetPresentationController.overlayColor {
        didSet {
            self.overlayView.backgroundColor = self.hasBlurBackground ? .clear : self.overlayColor
        }
    }
    
    public static var blurEffect: UIBlurEffect = {
        return UIBlurEffect(style: .prominent)
    }()
    
    public var blurEffect = SheetPresentationController.blurEffect {
        didSet {
            self.blurView.effect = blurEffect
        }
    }
    public static var allowGestureThroughOverlay: Bool = false
    public var allowGestureThroughOverlay: Bool = SheetPresentationController.allowGestureThroughOverlay {
        didSet {
            self.overlayTapView.isUserInteractionEnabled = !self.allowGestureThroughOverlay
        }
    }
    
    public static var cornerRadius: CGFloat = 20
    
    public var cornerRadius: CGFloat {
        get { return self.contentViewController.cornerRadius }
        set { self.contentViewController.cornerRadius = newValue }
    }
    
    public static var gripSize: CGSize = CGSize (width: 40, height: 3)
    public var gripSize: CGSize {
        get { return self.contentViewController.gripSize }
        set { self.contentViewController.gripSize = newValue }
    }
    
    public static var gripColor: UIColor = UIColor.clear
    public var gripColor: UIColor? {
        get { return self.contentViewController.gripColor }
        set { self.contentViewController.gripColor = newValue }
    }
    
    public static var pullBarBackgroundColor: UIColor = UIColor.clear
    public var pullBarBackgroundColor: UIColor? {
        get { return self.contentViewController.pullBarBackgroundColor }
        set { self.contentViewController.pullBarBackgroundColor = newValue }
    }
    
    public static var treatPullBarAsClear: Bool = false
    public var treatPullBarAsClear: Bool {
        get { return self.contentViewController.treatPullBarAsClear }
        set { self.contentViewController.treatPullBarAsClear = newValue }
    }
    
    let transition: SheetTransition
    
    public var shouldDismiss: ((SheetPresentationController) -> Bool)?
    public var didDismiss: ((SheetPresentationController) -> Void)?
    public var completion: (() -> Void)?
    public var sizeChanged: ((SheetPresentationController, SheetSize, CGFloat) -> Void)?
    public var panGestureShouldBegin: ((UIPanGestureRecognizer) -> Bool?)?
    
    public private(set) var contentViewController: SheetContentViewController
    var overlayView = UIView()
    var blurView = UIVisualEffectView()
    var overlayTapView = UIView()
    var overflowView = UIView()
    var overlayTapGesture: UITapGestureRecognizer?
    private var contentViewHeightConstraint: NSLayoutConstraint!
    
    /// The child view controller's scroll view we are watching so we can override the pull down/up to work on the sheet when needed
    private weak var childScrollView: UIScrollView?
    
    private var keyboardHeight: CGFloat = 0
    private var firstPanPoint: CGPoint = CGPoint.zero
    private var panOffset: CGFloat = 0
    private var panGestureRecognizer: InitialTouchPanGestureRecognizer!
    private var prePanHeight: CGFloat = 0
    private var isPanning: Bool = false
    
    public var contentBackgroundColor: UIColor? {
        get { self.contentViewController.contentBackgroundColor }
        set { self.contentViewController.contentBackgroundColor = newValue }
    }
    
    public init(controller: UIViewController, sizes: [SheetSize] = [.intrinsic], options: SheetOptions? = nil) {
        let options = options ?? SheetOptions.default
        self.contentViewController = SheetContentViewController(childViewController: controller, options: options)
        if #available(iOS 13.0, *) {
            self.contentViewController.contentBackgroundColor = UIColor.systemBackground
        } else {
            self.contentViewController.contentBackgroundColor = UIColor.white
        }
        self.sizes = sizes.count > 0 ? sizes : [.intrinsic]
        self.options = options
        self.transition = SheetTransition(options: options)
        self.minimumSpaceAbovePullBar = options.minimumSpaceAbovePullBar
        super.init(nibName: nil, bundle: nil)
        self.autoAdjustToKeyboard = options.autoAdjustToKeyboard
        self.dismissOnPull = options.dismissOnPull
        self.dismissOnOverlayTap = options.dismissOnOverlayTap
        self.cornerRadius = options.presentingViewCornerRadius
        self.gripColor = SheetPresentationController.gripColor
        self.gripSize = SheetPresentationController.gripSize
        self.pullBarBackgroundColor = SheetPresentationController.pullBarBackgroundColor
        self.cornerRadius = SheetPresentationController.cornerRadius
        self.updateOrderedSizes()
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public override func loadView() {
        if self.options.useInlineMode {
            let sheetView = SheetView()
            sheetView.delegate = self
            self.view = sheetView
        } else {
            super.loadView()
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.compatibleAdditionalSafeAreaInsets = UIEdgeInsets(top: -self.options.pullBarHeight, left: 0, bottom: 0, right: 0)
        
        self.view.backgroundColor = UIColor.clear
        if options.pullDownEnabled {
            self.addPanGestureRecognizer()
        }
        if options.hasOverlay {
            self.addOverlay()
        }
        self.addBlurBackground()
        self.addContentView()
        self.addOverlayTapView()
        self.registerKeyboardObservers()
        self.resize(to: self.sizes.first ?? .intrinsic, animated: false)
        self.handleScrollViewIfDetected()
        self.setupContentHeightObserver()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.contentViewController.updatePreferredHeight()
        self.updateOrderedSizes()
        self.resize(to: self.currentSize, animated: false)
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let presenter = self.transition.presenter, self.options.shrinkPresentingViewController {
            self.transition.restorePresentor(presenter, completion: { _ in
                self.completion?()
                self.didDismiss?(self)
            })
        } else if !self.options.useInlineMode {
            self.completion?()
            self.didDismiss?(self)
        }
    }
    
    /// Handle a scroll view in the child view controller by watching for the offset for the scrollview and taking priority when at the top (so pulling up/down can grow/shrink the sheet instead of bouncing the child's scroll view)
    public func handleScrollView(_ scrollView: UIScrollView) {
        if options.pullDownEnabled {
            scrollView.panGestureRecognizer.require(toFail: panGestureRecognizer)
            self.childScrollView = scrollView
        }
    }
    
    /// Change the sizes the sheet should try to pin to
    public func setSizes(_ sizes: [SheetSize], animated: Bool = true) {
        guard sizes.count > 0 else {
            return
        }
        self.sizes = sizes
        
        self.resize(to: sizes[0], animated: animated)
    }
    
    func updateOrderedSizes() {
        var concreteSizes: [(SheetSize, CGFloat)] = self.sizes.map {
            return ($0, self.height(for: $0))
        }
        concreteSizes.sort { $0.1 < $1.1 }
        self.orderedSizes = concreteSizes.map({ size, _ in size })
        self.updateAccessibility()
    }
    
    private func handleScrollViewIfDetected() {
        guard let scrollView = contentViewController.detectedScrollView else { return }
        handleScrollView(scrollView)
    }
    
    private func updateAccessibility() {
        let isOverlayAccessable = !self.allowGestureThroughOverlay && (self.dismissOnOverlayTap || self.dismissOnPull)
        self.overlayTapView.isAccessibilityElement = isOverlayAccessable
        
        var pullBarLabel = ""
        if !isOverlayAccessable && (self.dismissOnOverlayTap || self.dismissOnPull) {
            pullBarLabel = "Tap to Dismiss Presentation"
        } else if self.orderedSizes.count > 1 {
            pullBarLabel = "Tap to switch between presentation sizes"
        }
        
        self.contentViewController.pullBarView.isAccessibilityElement = !pullBarLabel.isEmpty
        self.contentViewController.pullBarView.accessibilityLabel = pullBarLabel
    }
    
    private func addOverlay() {
        self.view.addSubview(self.overlayView)
        Constraints(for: self.overlayView) {
            $0.edges(.top, .left, .right, .bottom).pinToSuperview()
        }
        self.overlayView.isUserInteractionEnabled = false
        self.overlayView.backgroundColor = self.hasBlurBackground ? .clear : self.overlayColor
    }
    
    private func addBlurBackground() {
        self.overlayView.addSubview(self.blurView)
        blurView.effect = blurEffect
        Constraints(for: self.blurView) {
            $0.edges(.top, .left, .right, .bottom).pinToSuperview()
        }
        self.blurView.isUserInteractionEnabled = false
        self.blurView.isHidden = !self.hasBlurBackground
    }
    
    private func addOverlayTapView() {
        let overlayTapView = self.overlayTapView
        overlayTapView.backgroundColor = .clear
        overlayTapView.isUserInteractionEnabled = !self.allowGestureThroughOverlay
        self.view.addSubview(overlayTapView)
        self.overlayTapView.accessibilityLabel = "Tap to Dismiss Presentation"
        Constraints(for: overlayTapView, self.contentViewController.view) {
            $0.top.pinToSuperview()
            $0.left.pinToSuperview()
            $0.right.pinToSuperview()
            $0.bottom.align(with: $1.top)
        }
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        self.overlayTapGesture = tapGestureRecognizer
        overlayTapView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func overlayTapped(_ gesture: UITapGestureRecognizer) {
        guard self.dismissOnOverlayTap else { return }
        self.attemptDismiss(animated: true)
    }
    
    private func addContentView() {
        self.contentViewController.willMove(toParent: self)
        self.addChild(self.contentViewController)
        self.view.addSubview(self.contentViewController.view)
        self.contentViewController.didMove(toParent: self)
        self.contentViewController.delegate = self
        Constraints(for: self.contentViewController.view) {
            $0.left.pinToSuperview().priority = UILayoutPriority(999)
            $0.left.pinToSuperview(inset: self.options.horizontalPadding, relation: .greaterThanOrEqual)
            if let maxWidth = self.options.maxWidth {
                $0.width.set(maxWidth, relation: .lessThanOrEqual)
            }
            
            $0.centerX.alignWithSuperview()
            self.contentViewHeightConstraint = $0.height.set(self.height(for: self.currentSize))
            
            let top: CGFloat
            if (self.options.useFullScreenMode) {
                top = 0
            } else {
                top = max(12, UIApplication.shared.windows.first(where:  { $0.isKeyWindow })?.compatibleSafeAreaInsets.top ?? 12)
            }
            $0.bottom.pinToSuperview()
            $0.top.pinToSuperview(inset: top, relation: .greaterThanOrEqual).priority = UILayoutPriority(999)
        }
    }
    
    private func addPanGestureRecognizer() {
        let panGestureRecognizer = InitialTouchPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        self.view.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
        self.panGestureRecognizer = panGestureRecognizer
    }
    
    @objc func panned(_ gesture: UIPanGestureRecognizer) {
        let point = gesture.translation(in: gesture.view?.superview)
        if gesture.state == .began {
            self.firstPanPoint = point
            self.prePanHeight = self.contentViewController.view.bounds.height
            self.isPanning = true
        }
        
        let minHeight: CGFloat = self.height(for: self.orderedSizes.first)
        let maxHeight: CGFloat
        if self.allowPullingPastMaxHeight {
            maxHeight = self.height(for: .fullscreen) // self.view.bounds.height
        } else {
            maxHeight = max(self.height(for: self.orderedSizes.last), self.prePanHeight)
        }
        
        var newHeight = max(0, self.prePanHeight + (self.firstPanPoint.y - point.y))
        var offset: CGFloat = 0
        if newHeight < minHeight {
            if self.allowPullingPastMinHeight {
                offset = minHeight - newHeight
            }
            newHeight = minHeight
        }
        if newHeight > maxHeight {
            newHeight = maxHeight
        }
        
        switch gesture.state {
            case .cancelled, .failed:
                UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                    self.contentViewController.view.transform = CGAffineTransform.identity
                    self.contentViewHeightConstraint.constant = self.height(for: self.currentSize)
                    self.transition.setPresentor(percentComplete: 0)
                    self.overlayView.alpha = 1
                }, completion: { _ in
                    self.isPanning = false
                })
            
            case .began, .changed:
                self.contentViewHeightConstraint.constant = newHeight
                
                if offset > 0 {
                    let percent = max(0, min(1, offset / max(1, newHeight)))
                    self.transition.setPresentor(percentComplete: percent)
                    self.overlayView.alpha = 1 - percent
                    self.contentViewController.view.transform = CGAffineTransform(translationX: 0, y: offset)
                    self.onDragProgressChange?(percent)
                } else {
                    self.contentViewController.view.transform = CGAffineTransform.identity
                    self.onDragProgressChange?(0)
                }
            case .ended:
            let velocity = (0.2 * gesture.velocity(in: self.view).y)
            var finalHeight = newHeight - offset - velocity
            if velocity > options.pullDismissThreshod {
                // They swiped hard, always just close the sheet when they do
                finalHeight = -1
            }
            
            let animationDuration = TimeInterval(abs(velocity*0.0002) + 0.2)
            
            if point.y > (newHeight - keyboardHeight) / 2 && self.dismissOnPull {
                dismiss(animationDuration: max(0.37, animationDuration))
                return
            }
            
            guard finalHeight > 0 || !self.dismissOnPull else {
                dismiss(animationDuration: animationDuration)
                return
            }
            
            var newSize = self.currentSize
            if point.y < 0 {
                // We need to move to the next larger one
                newSize = self.orderedSizes.last ?? self.currentSize
                for size in self.orderedSizes.reversed() {
                    if finalHeight < self.height(for: size) {
                        newSize = size
                    } else {
                        break
                    }
                }
            } else {
                // We need to move to the next smaller one
                newSize = self.orderedSizes.first ?? self.currentSize
                for size in self.orderedSizes {
                    if finalHeight > self.height(for: size) {
                        newSize = size
                    } else {
                        break
                    }
                }
            }
            let previousSize = self.currentSize
            self.currentSize = newSize
            
            let newContentHeight = self.height(for: newSize)
            UIView.animate(withDuration: animationDuration,
                           delay: 0,
                           usingSpringWithDamping: self.options.transitionDampening,
                           initialSpringVelocity: self.options.transitionVelocity,
                           options: self.options.transitionAnimationOptions,
                           animations: {
                self.contentViewController.view.transform = CGAffineTransform.identity
                self.contentViewHeightConstraint.constant = newContentHeight
                self.transition.setPresentor(percentComplete: 0)
                self.overlayView.alpha = 1
                self.view.layoutIfNeeded()
            }, completion: { complete in
                self.isPanning = false
                if previousSize != newSize {
                    self.sizeChanged?(self, newSize, newContentHeight)
                }
            })
        case .possible:
            break
        @unknown default:
            break // Do nothing
        }
    }
    
    private func dismiss(animationDuration: TimeInterval) {
        UIView.animate(withDuration: animationDuration,
                       delay: 0,
                       usingSpringWithDamping: self.options.transitionDampening,
                       initialSpringVelocity: self.options.transitionVelocity,
                       options: self.options.transitionAnimationOptions,
                       animations: {
            self.contentViewController.view.transform = CGAffineTransform(translationX: 0, y: self.contentViewController.view.bounds.height)
            self.view.backgroundColor = UIColor.clear
            self.transition.setPresentor(percentComplete: 1)
            self.overlayView.alpha = 0
        }, completion: { complete in
            self.attemptDismiss(animated: false)
        })
    }
    
    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardShown(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDismissed(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func setupContentHeightObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contentViewHeightUpdated(_:)),
            name: SelfSizedTableView.heightUpdatedNotification,
            object: nil
        )
    }
    
    @objc
    func keyboardShown(_ notification: Notification) {
        guard !keyboardShown else { return }
        guard let info:[AnyHashable: Any] = notification.userInfo, let keyboardRect:CGRect = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        keyboardShown = true
        let windowRect = self.view.convert(self.view.bounds, to: nil)
        let actualHeight = windowRect.maxY - keyboardRect.origin.y
        contentViewController.updatePreferredHeight(keyboardIsHidden: false)
        self.adjustForKeyboard(height: actualHeight, from: notification)
    }
    
    @objc
    func keyboardDismissed(_ notification: Notification) {
        keyboardShown = false
        contentViewController.updatePreferredHeight()
        self.adjustForKeyboard(height: 0, from: notification)
    }
    
    @objc
    private func contentViewHeightUpdated(_ notification: Notification) {
        contentViewController.updatePreferredHeight()
        updateOrderedSizes()
    }
    
    private func adjustForKeyboard(height: CGFloat, from notification: Notification) {
        guard self.autoAdjustToKeyboard, let info:[AnyHashable: Any] = notification.userInfo else { return }
        self.keyboardHeight = height
        
        let duration:TimeInterval = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
        let animationCurveRawNSN = info[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        let animationCurve:UIView.AnimationOptions = UIView.AnimationOptions(rawValue: animationCurveRaw)
        
        self.contentViewController.adjustForKeyboard(height: self.keyboardHeight)
        self.resize(to: self.currentSize, duration: duration, options: animationCurve, animated: true, complete: {
            self.resize(to: self.currentSize)
        })
    }
    
    private func height(for size: SheetSize?) -> CGFloat {
        guard let size = size else { return 0 }
        let contentHeight: CGFloat
        let fullscreenHeight: CGFloat
        if self.options.useFullScreenMode {
            fullscreenHeight = self.view.bounds.height - self.minimumSpaceAbovePullBar
        } else {
            fullscreenHeight = self.view.bounds.height - self.view.compatibleSafeAreaInsets.top - self.minimumSpaceAbovePullBar
        }
        switch (size) {
            case .fixed(let height):
                contentHeight = height + self.keyboardHeight
            case .fullscreen:
                contentHeight = fullscreenHeight
            case .intrinsic:
                contentHeight = self.contentViewController.preferredHeight + self.keyboardHeight
            case .percent(let percent):
                contentHeight = (self.view.bounds.height) * CGFloat(percent) + self.keyboardHeight
            case .marginFromTop(let margin):
                contentHeight = (self.view.bounds.height) - margin + self.keyboardHeight
        }
        return min(fullscreenHeight, contentHeight)
    }
    
    public func resize(to size: SheetSize,
                       duration: TimeInterval = 0.2,
                       options: UIView.AnimationOptions = [.curveEaseOut],
                       animated: Bool = true,
                       complete: (() -> Void)? = nil) {
        
        let previousSize = self.currentSize
        self.currentSize = size
        
        let oldConstraintHeight = self.contentViewHeightConstraint.constant
        
        let newHeight = self.height(for: size)
        
        guard oldConstraintHeight != newHeight else {
            return
        }
        
        if animated {
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: { [weak self] in
                guard let self = self, let constraint = self.contentViewHeightConstraint else { return }
                constraint.constant = newHeight
                self.contentViewController.view.layoutIfNeeded()
            }, completion: { _ in
                if previousSize != size {
                    self.sizeChanged?(self, size, newHeight)
                }
                self.contentViewController.updateAfterLayout()
                complete?()
            })
        } else {
            UIView.performWithoutAnimation {
                self.contentViewHeightConstraint?.constant = self.height(for: size)
                self.contentViewController.view.layoutIfNeeded()
            }
            complete?()
        }
    }
    
    public func attemptDismiss(animated: Bool, completion: (() -> Void)? = nil) {
        if self.shouldDismiss?(self) != false {
            if self.options.useInlineMode {
                if animated {
                    self.animateOut {
                        self.completion?()
                        completion?()
                        self.didDismiss?(self)
                    }
                } else {
                    self.view.removeFromSuperview()
                    self.removeFromParent()
                    self.completion?()
                    completion?()
                    self.didDismiss?(self)
                }
            } else {
                self.dismiss(animated: animated) {
                    self.completion?()
                    completion?()
                }
            }
        }
    }
    
    /// Recalculates the intrinsic height of the sheet based on the content, and updates the sheet height to match.
    ///
    /// **Note:** Only meant for use with `.intrinsic` sheet size
    public func updateIntrinsicHeight() {
        contentViewController.updatePreferredHeight()
    }
    
    /// Animates the sheet in, but only if presenting using the inline mode
    public func animateIn(to view: UIView, in parent: UIViewController, size: SheetSize? = nil, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        
        self.willMove(toParent: parent)
        parent.addChild(self)
        view.addSubview(self.view)
        self.didMove(toParent: parent)
        
        self.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.view.topAnchor.constraint(equalTo: view.topAnchor),
            self.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            self.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            self.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        self.animateIn(size: size, duration: duration, completion: completion)
    }
    
    public func animateIn(size: SheetSize? = nil, duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        guard self.options.useInlineMode else { return }
        guard self.view.superview != nil else {
            print("It appears your sheet is not set as a subview of another view. Make sure to add this view as a subview before trying to animate it in.")
            return
        }
        self.view.superview?.layoutIfNeeded()
        self.contentViewController.updatePreferredHeight()
        self.resize(to: size ?? self.sizes.first ?? self.currentSize, animated: false)
        guard let contentView = self.contentViewController.view else {
            return
        }
        contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
        self.overlayView.alpha = 0
        self.updateOrderedSizes()
        
        UIView.animate(
            withDuration: duration,
            animations: {
                contentView.transform = .identity
                self.overlayView.alpha = 1
            },
            completion: { _ in
                completion?()
            }
        )
    }
    
    /// Animates the sheet out, but only if presenting using the inline mode
    public func animateOut(duration: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
        guard self.options.useInlineMode else { return }
        guard let contentView = self.contentViewController.view else {
            return
        }
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: self.options.transitionDampening,
            initialSpringVelocity: self.options.transitionVelocity,
            options: self.options.transitionAnimationOptions,
            animations: {
                self.view.isUserInteractionEnabled = false
                contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
                self.overlayView.alpha = 0
            },
            completion: { _ in
                self.view.isUserInteractionEnabled = true
                self.view.removeFromSuperview()
                self.removeFromParent()
                completion?()
            }
        )
    }
}

extension SheetPresentationController: SheetViewDelegate {
    func sheetPoint(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let isInOverlay = self.overlayTapView.bounds.contains(point)
        if self.allowGestureThroughOverlay, isInOverlay {
            return false
        } else {
            return true
        }
    }
}

extension SheetPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Allowing gesture recognition on a UIControl seems to prevent its events from firing properly sometimes
        if !shouldRecognizePanGestureWithUIControls {
            if let view = touch.view {
                return !(view is UIControl)
            }
        }
        return true
    }
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGestureRecognizer = gestureRecognizer as? InitialTouchPanGestureRecognizer, let childScrollView = self.childScrollView, let point = panGestureRecognizer.initialTouchLocation else { return true }
        
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, let closure = panGestureShouldBegin, let should = closure(pan) {
            return should
        }
        
        let pointInChildScrollView = self.view.convert(point, to: childScrollView).y - childScrollView.contentOffset.y
        
        let velocity = panGestureRecognizer.velocity(in: panGestureRecognizer.view?.superview)
        guard pointInChildScrollView > 0, pointInChildScrollView < childScrollView.bounds.height else {
            return true
        }
        let topInset = childScrollView.contentInset.top
        
        guard abs(velocity.y) > abs(velocity.x), childScrollView.contentOffset.y <= -topInset else { return false }
        
        if velocity.y < 0 {
            let containerHeight = height(for: self.currentSize)
            return height(for: self.orderedSizes.last) > containerHeight && containerHeight < height(for: SheetSize.fullscreen)
        } else {
            return true
        }
    }
}

extension SheetPresentationController: SheetContentViewDelegate {
    func pullBarTapped() {
        // Tapping the pull bar is just for accessibility
        guard UIAccessibility.isVoiceOverRunning else { return }
        let shouldDismiss = self.allowGestureThroughOverlay && (self.dismissOnOverlayTap || self.dismissOnPull)
        guard !shouldDismiss else {
            self.attemptDismiss(animated: true)
            return
        }
        
        if self.sizes.count > 1 {
            let index = (self.sizes.firstIndex(of: self.currentSize) ?? 0) + 1
            if index >= self.sizes.count {
                self.resize(to: self.sizes[0])
            } else {
                self.resize(to: self.sizes[index])
            }
        }
    }
    
    func preferredHeightChanged(oldHeight: CGFloat, newSize: CGFloat) {
        if self.sizes.contains(.intrinsic) {
            self.updateOrderedSizes()
        }
        // If our intrinsic size changed and that is what we are sized to currently, use that
        if self.currentSize == .intrinsic, !self.isPanning {
            self.resize(to: .intrinsic)
        }
    }
}

extension SheetPresentationController: UIViewControllerTransitioningDelegate {
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.presenting = true
        return transition
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transition.presenting = false
        return transition
    }
}