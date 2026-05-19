https://stackoverflow.com/questions/56879693/how-to-animate-path-in-swiftui/56885066#56885066

import SwiftUI

struct ContentView : View {
    var body: some View {
        RingSpinner().padding(20)
    }
}

struct RingSpinner : View {
    @State var pct: Double = 0.0

    var animation: Animation {
        Animation.basic(duration: 1.5).repeatForever(autoreverses: false)
    }

    var body: some View {

        GeometryReader { geometry in
            ZStack {
                Path { path in

                    path.addArc(center: CGPoint(x: geometry.size.width/2, y: geometry.size.width/2),
                                radius: geometry.size.width/2,
                                startAngle: Angle(degrees: 0),
                                endAngle: Angle(degrees: 360),
                                clockwise: true)
                }
                .stroke(Color.green, lineWidth: 40)

                InnerRing(pct: self.pct).stroke(Color.yellow, lineWidth: 20)
            }
        }
        .aspectRatio(1, contentMode: .fit)
            .padding(20)
            .onAppear() {
                withAnimation(self.animation) {
                    self.pct = 1.0
                }
        }
    }

}

struct InnerRing : Shape {
    var lagAmmount = 0.35
    var pct: Double

    func path(in rect: CGRect) -> Path {

        let end = pct * 360
        var start: Double

        if pct > (1 - lagAmmount) {
            start = 360 * (2 * pct - 1.0)
        } else if pct > lagAmmount {
            start = 360 * (pct - lagAmmount)
        } else {
            start = 0
        }

        var p = Path()

        p.addArc(center: CGPoint(x: rect.size.width/2, y: rect.size.width/2),
                 radius: rect.size.width/2,
                 startAngle: Angle(degrees: start),
                 endAngle: Angle(degrees: end),
                 clockwise: false)

        return p
    }

    var animatableData: Double {
        get { return pct }
        set { pct = newValue }
    }
}
