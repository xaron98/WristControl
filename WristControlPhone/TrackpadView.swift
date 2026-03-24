// WristControlPhone/TrackpadView.swift
import SwiftUI
import UIKit

struct TrackpadView: UIViewRepresentable {
    let onMove: (Float, Float) -> Void
    let onClick: () -> Void
    let onRightClick: () -> Void
    let onScroll: (Float) -> Void

    func makeUIView(context: Context) -> TrackpadUIView {
        let view = TrackpadUIView()
        view.onMove = onMove
        view.onClick = onClick
        view.onRightClick = onRightClick
        view.onScroll = onScroll
        return view
    }

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {}
}

class TrackpadUIView: UIView {
    var onMove: ((Float, Float) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onScroll: ((Float) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.secondarySystemBackground
        layer.cornerRadius = 16

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        addGestureRecognizer(panGesture)

        let scrollGesture = UIPanGestureRecognizer(target: self, action: #selector(handleScroll))
        scrollGesture.minimumNumberOfTouches = 2
        scrollGesture.maximumNumberOfTouches = 2
        addGestureRecognizer(scrollGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTouchesRequired = 1
        addGestureRecognizer(tapGesture)

        let rightTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleRightTap))
        rightTapGesture.numberOfTouchesRequired = 2
        addGestureRecognizer(rightTapGesture)

        tapGesture.require(toFail: rightTapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Cursor acceleration: small deltas = precise, large deltas = fast
    private func accelerate(_ delta: CGFloat) -> Float {
        let abs = abs(delta)
        let speed: CGFloat
        if abs < 2 {
            speed = delta * 1.5       // Precise
        } else if abs < 8 {
            speed = delta * 2.5       // Normal
        } else {
            speed = delta * 4.0       // Fast
        }
        return Float(speed)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        // Send immediately — no batching with UDP
        onMove?(accelerate(translation.x), accelerate(translation.y))
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        onScroll?(Float(-translation.y * 0.8))
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onClick?()
    }

    @objc private func handleRightTap(_ gesture: UITapGestureRecognizer) {
        onRightClick?()
    }
}
