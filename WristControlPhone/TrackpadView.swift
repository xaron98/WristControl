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

    func updateUIView(_ uiView: TrackpadUIView, context: Context) {
        uiView.onMove = onMove
        uiView.onClick = onClick
        uiView.onRightClick = onRightClick
        uiView.onScroll = onScroll
    }
}

class TrackpadUIView: UIView {
    var onMove: ((Float, Float) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onScroll: ((Float) -> Void)?

    // Track last touch position for delta calculation
    private var lastTouchLocation: CGPoint?
    private var activeTouchCount: Int = 0
    private var touchStartTime: TimeInterval = 0
    private var touchMoved: Bool = false

    // Two-finger scroll tracking
    private var lastScrollY: CGFloat = 0
    private var isScrolling: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.secondarySystemBackground
        layer.cornerRadius = 16
        isMultipleTouchEnabled = true

        // Tap gestures for clicks (these don't interfere with raw touch tracking)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.cancelsTouchesInView = false
        addGestureRecognizer(tapGesture)

        let rightTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleRightTap))
        rightTapGesture.numberOfTouchesRequired = 2
        rightTapGesture.cancelsTouchesInView = false
        addGestureRecognizer(rightTapGesture)

        tapGesture.require(toFail: rightTapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Raw touch handling (bypasses gesture recognizer, full hardware rate)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouchCount = event?.allTouches?.count ?? touches.count
        touchStartTime = CACurrentMediaTime()
        touchMoved = false

        if activeTouchCount == 1, let touch = touches.first {
            lastTouchLocation = touch.location(in: self)
        } else if activeTouchCount == 2 {
            // Start scrolling
            isScrolling = true
            if let allTouches = event?.allTouches {
                lastScrollY = averageY(of: allTouches)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchMoved = true

        if activeTouchCount == 1, let touch = touches.first {
            let current = touch.location(in: self)

            // Process coalesced touches for maximum granularity
            let coalescedTouches = event?.coalescedTouches(for: touch) ?? [touch]

            for coalesced in coalescedTouches {
                let pos = coalesced.location(in: self)
                if let last = lastTouchLocation {
                    let rawDX = pos.x - last.x
                    let rawDY = pos.y - last.y
                    let dx = accelerate(rawDX)
                    let dy = accelerate(rawDY)
                    if abs(dx) > 0.01 || abs(dy) > 0.01 {
                        onMove?(dx, dy)
                    }
                }
                lastTouchLocation = pos
            }
        } else if activeTouchCount >= 2, isScrolling {
            if let allTouches = event?.allTouches {
                let currentY = averageY(of: allTouches)
                let delta = lastScrollY - currentY
                if abs(delta) > 0.5 {
                    onScroll?(Float(delta * 0.8))
                    lastScrollY = currentY
                }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
        isScrolling = false
        activeTouchCount = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        lastTouchLocation = nil
        isScrolling = false
        activeTouchCount = 0
    }

    // MARK: - Smooth acceleration curve

    private func accelerate(_ delta: CGFloat) -> Float {
        let magnitude = abs(delta)
        // Smooth exponential curve: f(x) = sign(x) * x * (base + scale * |x|^power)
        let base: CGFloat = 1.2
        let scale: CGFloat = 0.15
        let power: CGFloat = 0.8
        let multiplier = base + scale * pow(magnitude, power)
        return Float(delta * multiplier)
    }

    // MARK: - Helpers

    private func averageY(of touches: Set<UITouch>) -> CGFloat {
        let sum = touches.reduce(CGFloat(0)) { $0 + $1.location(in: self).y }
        return sum / CGFloat(touches.count)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        onClick?()
    }

    @objc private func handleRightTap(_ gesture: UITapGestureRecognizer) {
        onRightClick?()
    }
}
