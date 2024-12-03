//
//  SheetConstraintsExtension.swift
//  UltiSelf
//
//  Created by Иван Зиныч on 18.09.2022.
//  Copyright © 2022 UltiSelf. All rights reserved.
//

import UIKit

protocol LayoutItem {
    var superview: UIView? { get }
}

extension UIView: LayoutItem {}
extension UILayoutGuide: LayoutItem {
    var superview: UIView? { return self.owningView }
}

extension LayoutItem {
    @nonobjc var al: LayoutProxy<Self> { return LayoutProxy(base: self) }
}

// MARK: - LayoutProxy
struct LayoutProxy<Base> {
    let base: Base
}

extension LayoutProxy where Base: LayoutItem {
    
    // MARK: Anchors
    
    var top: Anchor<AnchorType.Edge, AnchorAxis.Vertical> { return Anchor(base, .top) }
    var bottom: Anchor<AnchorType.Edge, AnchorAxis.Vertical> { return Anchor(base, .bottom) }
    var left: Anchor<AnchorType.Edge, AnchorAxis.Horizontal> { return Anchor(base, .left) }
    var right: Anchor<AnchorType.Edge, AnchorAxis.Horizontal> { return Anchor(base, .right) }
    var leading: Anchor<AnchorType.Edge, AnchorAxis.Horizontal> { return Anchor(base, .leading) }
    var trailing: Anchor<AnchorType.Edge, AnchorAxis.Horizontal> { return Anchor(base, .trailing) }
    
    var centerX: Anchor<AnchorType.Center, AnchorAxis.Horizontal> { return Anchor(base, .centerX) }
    var centerY: Anchor<AnchorType.Center, AnchorAxis.Vertical> { return Anchor(base, .centerY) }
    
    var firstBaseline: Anchor<AnchorType.Baseline, AnchorAxis.Vertical> { return Anchor(base, .firstBaseline) }
    var lastBaseline: Anchor<AnchorType.Baseline, AnchorAxis.Vertical> { return Anchor(base, .lastBaseline) }
    
    var width: Anchor<AnchorType.Dimension, AnchorAxis.Horizontal> { return Anchor(base, .width) }
    var height: Anchor<AnchorType.Dimension, AnchorAxis.Vertical> { return Anchor(base, .height) }
    
    // MARK: Anchor Collections
    
    func edges(_ edges: LayoutEdge...) -> AnchorCollectionEdges { return AnchorCollectionEdges(item: base, edges: edges) }
    var edges: AnchorCollectionEdges { return AnchorCollectionEdges(item: base, edges: [.left, .right, .bottom, .top]) }
    var center: AnchorCollectionCenter { return AnchorCollectionCenter(x: centerX, y: centerY) }
    var size: AnchorCollectionSize { return AnchorCollectionSize(width: width, height: height) }
}

extension LayoutProxy where Base: UIView {
    var margins: LayoutProxy<UILayoutGuide> { return base.layoutMarginsGuide.al }
    
    @available(iOS 11.0, tvOS 11.0, *)
    var safeArea: LayoutProxy<UILayoutGuide> { return base.safeAreaLayoutGuide.al }
}

// MARK: - Anchors

enum AnchorAxis {
    class Horizontal {}
    class Vertical {}
}

enum AnchorType {
    class Dimension {}
    class Alignment {}
    class Center: Alignment {}
    class Edge: Alignment {}
    class Baseline: Alignment {}
}

struct Anchor<Type, Axis> {
    internal let item: LayoutItem
    internal let attribute: NSLayoutConstraint.Attribute
    internal let offset: CGFloat
    internal let multiplier: CGFloat
    
    init(_ item: LayoutItem, _ attribute: NSLayoutConstraint.Attribute, offset: CGFloat = 0, multiplier: CGFloat = 1) {
        self.item = item; self.attribute = attribute; self.offset = offset; self.multiplier = multiplier
    }
    
    internal func offsetting(by offset: CGFloat) -> Anchor<Type, Axis> {
        return Anchor<Type, Axis>(item, attribute, offset: self.offset + offset, multiplier: self.multiplier)
    }
    
    internal func multiplied(by multiplier: CGFloat) -> Anchor<Type, Axis> {
        return Anchor<Type, Axis>(item, attribute, offset: self.offset * multiplier, multiplier: self.multiplier * multiplier)
    }
}

func + <Type, Axis>(anchor: Anchor<Type, Axis>, offset: CGFloat) -> Anchor<Type, Axis> {
    return anchor.offsetting(by: offset)
}

func - <Type, Axis>(anchor: Anchor<Type, Axis>, offset: CGFloat) -> Anchor<Type, Axis> {
    return anchor.offsetting(by: -offset)
}

func * <Type, Axis>(anchor: Anchor<Type, Axis>, multiplier: CGFloat) -> Anchor<Type, Axis> {
    return anchor.multiplied(by: multiplier)
}

// MARK: - Anchors (AnchorType.Alignment)

extension Anchor where Type: AnchorType.Alignment {
    @discardableResult func align<Type: AnchorType.Alignment>(with anchor: Anchor<Type, Axis>, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return Constraints.constrain(self, anchor, relation: relation)
    }
}

// MARK: - Anchors (AnchorType.Edge)

extension Anchor where Type: AnchorType.Edge {
    @discardableResult func pinToSuperview(inset: CGFloat = 0, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        guard let superview = self.item.superview else {
            preconditionFailure("superview should be set")
        }
        return _pin(to: superview, attribute: attribute, inset: inset, relation: relation)
    }
    
    @discardableResult func pinToSuperviewMargin(inset: CGFloat = 0, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        guard let superview = self.item.superview else {
            preconditionFailure("superview should be set")
        }
        return _pin(to: superview, attribute: attribute.toMargin, inset: inset, relation: relation)
    }
    
    @discardableResult func pin(to container: LayoutItem, inset: CGFloat = 0, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return _pin(to: container, attribute: attribute, inset: inset, relation: relation)
    }

    @discardableResult func pinToSafeArea(of vc: UIViewController, inset: CGFloat = 0, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        let item2: Any, attr2: NSLayoutConstraint.Attribute
        if #available(iOS 11, tvOS 11, *) {
            (item2, attr2) = (vc.view.safeAreaLayoutGuide, self.attribute)
        } else {
            guard let view = vc.view else {
                preconditionFailure("view should be set")
            }

            switch self.attribute {
            case .top:
                (item2, attr2) = (vc.topLayoutGuide, .bottom)
            case .bottom:
                (item2, attr2) = (vc.bottomLayoutGuide, .top)
            default:
                (item2, attr2) = (view, self.attribute)
            }
        }
        return _pin(to: item2, attribute: attr2, inset: inset, relation: relation)
    }
    
    private func _pin(to item2: Any, attribute attr2: NSLayoutConstraint.Attribute, inset: CGFloat, relation: NSLayoutConstraint.Relation) -> NSLayoutConstraint {
        let isInverted = [.trailing, .right, .bottom].contains(attribute)
        return Constraints.constrain(self, toItem: item2, attribute: attr2, offset: (isInverted ? -inset : inset), relation: (isInverted ? relation.inverted : relation))
    }
}

// MARK: - Anchors (AnchorType.Center)

extension Anchor where Type: AnchorType.Center {
    @discardableResult func alignWithSuperview(offset: CGFloat = 0, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        guard let superview = self.item.superview else {
            preconditionFailure("superview should be set")
        }
        return align(with: Anchor<Type, Axis>(superview, self.attribute) + offset, relation: relation)
    }
}

// MARK: - Anchors (AnchorType.Dimension)

extension Anchor where Type: AnchorType.Dimension {
    @discardableResult func set(_ constant: CGFloat, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return Constraints.constrain(item: item, attribute: attribute, relatedBy: relation, constant: constant)
    }
    
    @discardableResult func match<Axis>(_ anchor: Anchor<AnchorType.Dimension, Axis>, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return Constraints.constrain(self, anchor, relation: relation)
    }
}

// MARK: - AnchorCollectionEdges

struct AnchorCollectionEdges {
    internal let item: LayoutItem
    internal let edges: [LayoutEdge]
    private var anchors: [Anchor<AnchorType.Edge, Any>] { return edges.map { Anchor(item, $0.attribute) } }
    
    @discardableResult func pinToSuperview(insets: UIEdgeInsets = .zero, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return anchors.map { $0.pinToSuperview(inset: insets.inset(for: $0.attribute), relation: relation) }
    }

    @discardableResult func pinToSuperviewMargins(insets: UIEdgeInsets = .zero, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return anchors.map { $0.pinToSuperviewMargin(inset: insets.inset(for: $0.attribute), relation: relation) }
    }
    
    @discardableResult func pin(to item2: LayoutItem, insets: UIEdgeInsets = .zero, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return anchors.map { $0.pin(to: item2, inset: insets.inset(for: $0.attribute), relation: relation) }
    }
    
    @discardableResult func pinToSafeArea(of vc: UIViewController, insets: UIEdgeInsets = .zero, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return anchors.map { $0.pinToSafeArea(of: vc, inset: insets.inset(for: $0.attribute), relation: relation) }
    }
}

// MARK: - AnchorCollectionCenter

struct AnchorCollectionCenter {
    internal let x: Anchor<AnchorType.Center, AnchorAxis.Horizontal>
    internal let y: Anchor<AnchorType.Center, AnchorAxis.Vertical>
    
    @discardableResult func alignWithSuperview() -> [NSLayoutConstraint] {
        return [x.alignWithSuperview(), y.alignWithSuperview()]
    }
    
    @discardableResult func align(with anchors: AnchorCollectionCenter) -> [NSLayoutConstraint] {
        return [x.align(with: anchors.x), y.align(with: anchors.y)]
    }
}


// MARK: - AnchorCollectionSize

struct AnchorCollectionSize {
    internal let width: Anchor<AnchorType.Dimension, AnchorAxis.Horizontal>
    internal let height: Anchor<AnchorType.Dimension, AnchorAxis.Vertical>
    
    @discardableResult func set(_ size: CGSize, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return [width.set(size.width, relation: relation), height.set(size.height, relation: relation)]
    }
    
    @discardableResult func match(_ anchors: AnchorCollectionSize, insets: CGSize = .zero, multiplier: CGFloat = 1, relation: NSLayoutConstraint.Relation = .equal) -> [NSLayoutConstraint] {
        return [width.match(anchors.width * multiplier - insets.width, relation: relation),
                height.match(anchors.height * multiplier - insets.height, relation: relation)]
    }
}

// MARK: - Constraints

final class Constraints {
    var constraints = [NSLayoutConstraint]()

    @discardableResult init(_ closure: () -> Void) {
        Constraints._stack.append(self)
        closure() // create constraints
        Constraints._stack.removeLast()
        NSLayoutConstraint.activate(constraints)
    }
    
    internal static func constrain(item item1: Any, attribute attr1: NSLayoutConstraint.Attribute, relatedBy relation: NSLayoutConstraint.Relation = .equal, toItem item2: Any? = nil, attribute attr2: NSLayoutConstraint.Attribute? = nil, multiplier: CGFloat = 1, constant: CGFloat = 0) -> NSLayoutConstraint {
        precondition(Thread.isMainThread, "Yalta APIs can only be used from the main thread")
        (item1 as? UIView)?.translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint(item: item1, attribute: attr1, relatedBy: relation, toItem: item2, attribute: attr2 ?? .notAnAttribute, multiplier: multiplier, constant: constant)
        _install(constraint)
        return constraint
    }
    
    internal static func constrain<T1, A1, T2, A2>(_ lhs: Anchor<T1, A1>, _ rhs: Anchor<T2, A2>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return constrain(item: lhs.item, attribute: lhs.attribute, relatedBy: relation, toItem: rhs.item, attribute: rhs.attribute, multiplier: (multiplier / lhs.multiplier) * rhs.multiplier, constant: offset - lhs.offset + rhs.offset)
    }

    internal static func constrain<T1, A1>(_ lhs: Anchor<T1, A1>, toItem item2: Any?, attribute attr2: NSLayoutConstraint.Attribute?, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return constrain(item: lhs.item, attribute: lhs.attribute, relatedBy: relation, toItem: item2, attribute: attr2, multiplier: multiplier / lhs.multiplier, constant: offset - lhs.offset)
    }
    
    private static var _stack = [Constraints]()
    
    private static func _install(_ constraint: NSLayoutConstraint) {
        if _stack.isEmpty {
            constraint.isActive = true
        } else {
            guard let stackLast = _stack.last else {
                preconditionFailure("stackLast should be set")
            }
            let group = stackLast
            group.constraints.append(constraint)
        }
    }
}

// MARK: - UIView + Constraints

extension UIView {
    @discardableResult @nonobjc func addSubview(_ a: UIView, constraints: (LayoutProxy<UIView>) -> Void) -> Constraints {
        addSubview(a)
        return Constraints(for: a, constraints)
    }
    
    @discardableResult @nonobjc func addSubview(_ a: UIView, _ b: UIView, constraints: (LayoutProxy<UIView>, LayoutProxy<UIView>) -> Void) -> Constraints {
        [a, b].forEach { addSubview($0) }
        return Constraints(for: a, b, constraints)
    }
    
    @discardableResult @nonobjc func addSubview(_ a: UIView, _ b: UIView, _ c: UIView, constraints: (LayoutProxy<UIView>, LayoutProxy<UIView>, LayoutProxy<UIView>) -> Void) -> Constraints {
        [a, b, c].forEach { addSubview($0) }
        return Constraints(for: a, b, c, constraints)
    }
    
    @discardableResult @nonobjc func addSubview(_ a: UIView, _ b: UIView, _ c: UIView, _ d: UIView, constraints: (LayoutProxy<UIView>, LayoutProxy<UIView>, LayoutProxy<UIView>, LayoutProxy<UIView>) -> Void) -> Constraints {
        [a, b, c, d].forEach { addSubview($0) }
        return Constraints(for: a, b, c, d, constraints)
    }
}

// MARK: - Constraints (Arity)

extension Constraints {
    @discardableResult convenience init<A: LayoutItem>(for a: A, _ closure: (LayoutProxy<A>) -> Void) {
        self.init { closure(a.al) }
    }
    
    @discardableResult convenience init<A: LayoutItem, B: LayoutItem>(for a: A, _ b: B, _ closure: (LayoutProxy<A>, LayoutProxy<B>) -> Void) {
        self.init { closure(a.al, b.al) }
    }
    
    @discardableResult convenience init<A: LayoutItem, B: LayoutItem, C: LayoutItem>(for a: A, _ b: B, _ c: C, _ closure: (LayoutProxy<A>, LayoutProxy<B>, LayoutProxy<C>) -> Void) {
        self.init { closure(a.al, b.al, c.al) }
    }
    
    @discardableResult convenience init<A: LayoutItem, B: LayoutItem, C: LayoutItem, D: LayoutItem>(for a: A, _ b: B, _ c: C, _ d: D, _ closure: (LayoutProxy<A>, LayoutProxy<B>, LayoutProxy<C>, LayoutProxy<D>) -> Void) {
        self.init { closure(a.al, b.al, c.al, d.al) }
    }
}

// MARK: - Misc

enum LayoutEdge {
    case top, bottom, leading, trailing, left, right
    
    internal var attribute: NSLayoutConstraint.Attribute {
        switch self {
        case .top: return .top;          case .bottom: return .bottom
        case .leading: return .leading;  case .trailing: return .trailing
        case .left: return .left;        case .right: return .right
        }
    }
}

internal extension NSLayoutConstraint.Attribute {
    var toMargin: NSLayoutConstraint.Attribute {
        switch self {
        case .top: return .topMargin;           case .bottom: return .bottomMargin
        case .leading: return .leadingMargin;   case .trailing: return .trailingMargin
        case .left: return .leftMargin          case .right: return .rightMargin
        default: return self
        }
    }
}

internal extension NSLayoutConstraint.Relation {
    var inverted: NSLayoutConstraint.Relation {
        switch self {
        case .greaterThanOrEqual: return .lessThanOrEqual
        case .lessThanOrEqual: return .greaterThanOrEqual
        case .equal: return self
        @unknown default:
            return self
        }
    }
}

internal extension UIEdgeInsets {
    func inset(for attribute: NSLayoutConstraint.Attribute) -> CGFloat {
        switch attribute {
        case .top: return top; case .bottom: return bottom
        case .left, .leading: return left
        case .right, .trailing: return right
        default: return 0
        }
    }
}

// MARK: - Deprecated
extension Anchor where Type: AnchorType.Alignment {
    @available(*, deprecated, message: "Please use operators instead, e.g. `view.top.align(with: view.bottom * 2 + 10)`.")
    @discardableResult func align<Type: AnchorType.Alignment>(with anchor: Anchor<Type, Axis>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return Constraints.constrain(self, anchor, offset: offset, multiplier: multiplier, relation: relation)
    }
}

extension Anchor where Type: AnchorType.Dimension {
    @available(*, deprecated, message: "Please use operators instead, e.g. `view.width.match(view.height * 2 + 10)`.")
    @discardableResult func match<Axis>(_ anchor: Anchor<AnchorType.Dimension, Axis>, offset: CGFloat = 0, multiplier: CGFloat = 1, relation: NSLayoutConstraint.Relation = .equal) -> NSLayoutConstraint {
        return Constraints.constrain(self, anchor, offset: offset, multiplier: multiplier, relation: relation)
    }
}
