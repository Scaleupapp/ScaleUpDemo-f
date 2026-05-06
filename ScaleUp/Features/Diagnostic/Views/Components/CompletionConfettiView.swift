import SwiftUI

struct CompletionConfettiView: View {
    @State private var emit = false

    var body: some View {
        ZStack {
            ForEach(0..<20, id: \.self) { i in
                Capsule()
                    .fill(ColorTokens.gold)
                    .frame(width: 4, height: 12)
                    .offset(y: emit ? CGFloat.random(in: 200...500) : -50)
                    .offset(x: CGFloat.random(in: -150...150))
                    .opacity(emit ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.5).delay(Double(i) * 0.02),
                        value: emit
                    )
            }
        }
        .onAppear { emit = true }
        .allowsHitTesting(false)
    }
}
