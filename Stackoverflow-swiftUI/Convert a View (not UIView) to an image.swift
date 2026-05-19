https://stackoverflow.com/questions/57200521/how-to-convert-a-view-not-uiview-to-an-image/57206207#57206207

import SwiftUI

extension UIView {
    func asImage(rect: CGRect) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: rect)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

struct ContentView: View {
    @State private var rect1: CGRect = .zero
    @State private var rect2: CGRect = .zero
    @State private var uiimage: UIImage? = nil

    var body: some View {
        VStack {
            HStack {
                VStack {
                    Text("LEFT")
                    Text("VIEW")
                }
                .padding(20)
                .background(Color.green)
                .border(Color.blue, width: 5)
                .background(RectGetter(rect: $rect1))
                .onTapGesture { self.uiimage = UIApplication.shared.windows[0].rootViewController?.view.asImage(rect: self.rect1) }

                VStack {
                    Text("RIGHT")
                    Text("VIEW")
                }
                .padding(40)
                .background(Color.yellow)
                .border(Color.green, width: 5)
                .background(RectGetter(rect: $rect2))
                .onTapGesture { self.uiimage = UIApplication.shared.windows[0].rootViewController?.view.asImage(rect: self.rect2) }

            }

            if uiimage != nil {
                VStack {
                    Text("Captured Image")
                    Image(uiImage: self.uiimage!).padding(20).border(Color.black)
                }.padding(20)
            }

        }

    }
}

struct RectGetter: View {
    @Binding var rect: CGRect

    var body: some View {
        GeometryReader { proxy in
            self.createView(proxy: proxy)
        }
    }

    func createView(proxy: GeometryProxy) -> some View {
        DispatchQueue.main.async {
            self.rect = proxy.frame(in: .global)
        }

        return Rectangle().fill(Color.clear)
    }
}
