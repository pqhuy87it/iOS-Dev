//
//  MorphingGlassMenu.swift
//  UIGlassEffectExample2
//
//  Created by huy on 2026/02/11.
//

import SwiftUI

struct MorphingGlassMenu: View {
    @Namespace private var namespace
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            // Container giúp các thành phần kính hòa trộn vào nhau
            GlassEffectContainer {
                HStack(spacing: 15) {
                    ForEach(0..<4) { index in
                        Image(systemName: "circle.grid.2x2.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                            .frame(width: 60, height: 60)
                            // Áp dụng kính cho từng item
                            .glassEffect(.regular, in: .rect(cornerRadius: 20))
                    }
                }
                .padding()
                // Bản thân container background cũng là một lớp kính nền
                .glassEffect(.regular, in: .capsule)
            }
            .padding(.bottom, 50)
        }
    }
}

#Preview {
    MorphingGlassMenu()
}
