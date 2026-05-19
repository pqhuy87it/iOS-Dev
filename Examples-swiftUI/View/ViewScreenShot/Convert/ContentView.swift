//
//  ContentView.swift
//  Convert
//
//  Created by Pham Quang Huy on 2021/02/14.
//

import SwiftUI

import SwiftUI
struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack {
                Text("GeometryReader Get Grobal Origin")
                GeometryRectangle(color: Color.pink)
                GeometryRectangle(color: Color.red)
                    .offset(x: 10, y: 0)
                ZStack {
                    GeometryRectangle(color: Color.blue)
                        .offset(x: 30, y: 0)
                }
            }
        }
    }
}
struct GeometryRectangle: View {
    var color: Color
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Button(action: {
                    let image = self.takeScreenshot(origin: geometry.frame(in: .global).origin, size: geometry.size)
                    print(image)
                }) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(self.color)
                        .overlay(
                            VStack {
                                Text("X: \(Int(geometry.frame(in: .global).origin.x)) Y: \(Int(geometry.frame(in: .global).origin.y)) width: \(Int(geometry.frame(in: .global).width)) height: \(Int(geometry.frame(in: .global).height))")
                                    .foregroundColor(.white)
                                Text("size: \(geometry.size.debugDescription)")
                                    .foregroundColor(.white)
                            })}
            }
        }.frame(height: 100)
    }
}
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
extension UIView {
    var renderedImage: UIImage {
        // rect of capure
        let rect = self.bounds
        // create the context of bitmap
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        let context: CGContext = UIGraphicsGetCurrentContext()!
        self.layer.render(in: context)
        // get a image from current context bitmap
        let capturedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return capturedImage
    }
}
extension View {
    func takeScreenshot(origin: CGPoint, size: CGSize) -> UIImage {
        let window = UIWindow(frame: CGRect(origin: origin, size: size))
        let hosting = UIHostingController(rootView: self)
        hosting.view.frame = window.frame
        window.addSubview(hosting.view)
        window.makeKeyAndVisible()
        return hosting.view.renderedImage
    }
}
