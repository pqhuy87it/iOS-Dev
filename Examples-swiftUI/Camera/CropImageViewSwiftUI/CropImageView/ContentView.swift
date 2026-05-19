//
//  ContentView.swift
//  CropImageView
//
//  Created by Pham Quang Huy on 2021/02/15.
//

import SwiftUI

struct ContentView: View {
    var currentImage: Image
    
    @State private var currentPositionTopLeft: CGPoint = .zero
    @State private var newPositionTopLeft: CGPoint = .zero
    
    @State private var currentPositionTopRight: CGPoint = .zero
    @State private var newPositionTopRight: CGPoint = .zero
    
    @State private var currentPositionBottomLeft: CGPoint = .zero
    @State private var newPositionBottomLeft: CGPoint = .zero
    
    @State private var currentPositionBottomRight: CGPoint = .zero
    @State private var newPositionBottomRight: CGPoint = .zero
    
    var body: some View {
        ZStack {
            VStack {
                Text("Top left: \(currentPositionTopLeft.x) | \(currentPositionTopLeft.y)")
                Text("Top right: \(currentPositionTopRight.x) | \(currentPositionTopRight.y)")
                Text("Bottom left: \(currentPositionBottomLeft.x) | \(currentPositionBottomLeft.y)")
                Text("Bottom right: \(currentPositionBottomRight.x) | \(currentPositionBottomRight.y)")
                Spacer()
                currentImage
                    .resizable()
                    .aspectRatio(1 , contentMode: .fit)
                    .overlay(getCorners())
                Spacer()
                Group {
                    Button(action: {
                        // TODO: Crop it
                    }) {
                        Image(systemName: "checkmark").resizable().frame(width: 24, height: 24)
                            .padding(20)
                            .background(Color.blue)
                            .foregroundColor(Color.white)
                    }.clipShape(Circle())
                    .shadow(radius: 4)
                }
            }
        }
    }
    
    private func getCorners() -> some View{
        
        return
            HStack {
                VStack {
                    ZStack {
                        CropImageViewRectangle(
                            currentPositionTopLeft: self.$currentPositionTopLeft,
                            currentPositionTopRight: self.$currentPositionTopRight,
                            currentPositionBottomLeft: self.$currentPositionBottomLeft,
                            currentPositionBottomRight: self.$currentPositionBottomRight
                        )
                        
                        GeometryReader { geometry in
                            CropImageViewRectangleCorner(
                                currentPosition: self.$currentPositionTopLeft,
                                newPosition: self.$newPositionTopLeft,
                                displacementX: 0,
                                displacementY: 0
                            )
                            
                            CropImageViewRectangleCorner(
                                currentPosition: self.$currentPositionTopRight,
                                newPosition: self.$newPositionTopRight,
                                displacementX: geometry.size.width,
                                displacementY: 0
                            )
                            
                            CropImageViewRectangleCorner(
                                currentPosition: self.$currentPositionBottomLeft,
                                newPosition: self.$newPositionBottomLeft,
                                displacementX: 0,
                                displacementY: geometry.size.height
                            )
                            
                            CropImageViewRectangleCorner(
                                currentPosition: self.$currentPositionBottomRight,
                                newPosition: self.$newPositionBottomRight,
                                displacementX: geometry.size.width,
                                displacementY: geometry.size.height
                            )
                        }
                    }
                    
                    Spacer()
                }
                Spacer()
            }
    }
}

