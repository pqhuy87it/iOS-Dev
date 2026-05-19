https://stackoverflow.com/questions/57034383/how-to-draw-an-arc-with-swiftui/57034585#57034585

import SwiftUI

struct ContentView : View {
    var body: some View {
        MyShape()
    }
}

struct MyShape : Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        p.addArc(center: CGPoint(x: 100, y:100), radius: 50, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: true)

        return p.strokedPath(.init(lineWidth: 3, dash: [5, 3], dashPhase: 10))
    }    
}
