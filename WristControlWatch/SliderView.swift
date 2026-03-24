// WristControlWatch/SliderView.swift
import SwiftUI

enum ActiveControl: String {
    case none
    case brightness
    case volume
    case scroll
}

struct SliderView: View {
    @Binding var value: Double
    let controlType: ActiveControl
    let onChanged: (Double) -> Void

    @State private var lastSentTime: Date = .distantPast
    private let throttleInterval: TimeInterval = 0.1

    private var icon: String {
        controlType == .brightness ? "sun.max.fill" : "speaker.wave.2.fill"
    }

    private var color: Color {
        controlType == .brightness ? .yellow : .blue
    }

    private var percentage: Int {
        Int(value * 100)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text("\(percentage)%")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.6), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(value)),
                            height: 12
                        )
                }
            }
            .frame(height: 12)

            HStack {
                Image(systemName: controlType == .brightness ? "sun.min" : "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: controlType == .brightness ? "sun.max.fill" : "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .focusable(true)
        .digitalCrownRotation(
            $value,
            from: 0.0,
            through: 1.0,
            by: 0.02,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: value) { oldValue, newValue in
            let clampedValue = min(max(newValue, 0.0), 1.0)
            if clampedValue != newValue {
                value = clampedValue
            }
            throttledSend(clampedValue)
        }
    }

    private func throttledSend(_ newValue: Double) {
        let now = Date()
        guard now.timeIntervalSince(lastSentTime) >= throttleInterval else { return }
        lastSentTime = now
        onChanged(newValue)
    }
}
