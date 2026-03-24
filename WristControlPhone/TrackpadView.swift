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

    private let sensitivity: CGFloat = 2.5

    // Accumulate deltas and send at screen refresh rate
    private var accumulatedDX: CGFloat = 0
    private var accumulatedDY: CGFloat = 0
    private var accumulatedScroll: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var hasMovement = false
    private var hasScroll = false

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

        // Display link for batching sends at 60fps
        displayLink = CADisplayLink(target: self, selector: #selector(flushDeltas))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        accumulatedDX += translation.x * sensitivity
        accumulatedDY += translation.y * sensitivity
        hasMovement = true
    }

    @objc private func handleScroll(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .changed else { return }
        let translation = gesture.translation(in: self)
        gesture.setTranslation(.zero, in: self)
        accumulatedScroll += -translation.y * 0.5
        hasScroll = true
    }

    @objc private func flushDeltas() {
        if hasMovement {
            onMove?(Float(accumulatedDX), Float(accumulatedDY))
            accumulatedDX = 0
            accumulatedDY = 0
            hasMovement = false
        }
        if hasScroll {
            onScroll?(Float(accumulatedScroll))
            accumulatedScroll = 0
            hasScroll = false
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onClick?()
    }

    @objc private func handleRightTap(_ gesture: UITapGestureRecognizer) {
        onRightClick?()
    }
}
