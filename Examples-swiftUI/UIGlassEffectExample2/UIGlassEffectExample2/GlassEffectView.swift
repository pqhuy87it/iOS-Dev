//
//  GlassEffectView.swift
//  UIGlassEffectExample2
//
//  Created by huy on 2026/02/11.
//

import SwiftUI

struct GlassEffectExample: View {
    var body: some View {
        ZStack {
            // 1. Hình nền rực rỡ để thấy rõ hiệu ứng khúc xạ (lensing) của kính
            Image("abstract_background") // Hãy thay bằng tên ảnh có trong Assets của bạn
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Ví dụ 1: Hiệu ứng kính cơ bản trên Text
                Text("Liquid Glass")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 20)
                    // Áp dụng hiệu ứng kính style .regular, hình dạng Capsule
                    .glassEffect(.regular, in: .capsule)
                
                // Ví dụ 2: Hiệu ứng kính có tương tác (Interactive) và ám màu (Tint)
                HStack(spacing: 20) {
                    Button(action: {
                        print("Play tapped")
                    }) {
                        Image(systemName: "play.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            // Kính trong suốt (.regular), ám màu xanh nhẹ, có tương tác chạm
                            .glassEffect(.regular.tint(.blue).interactive(), in: .circle)
                    }
                    
                    Button(action: {
                        print("Pause tapped")
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 80, height: 80)
                            .glassEffect(.regular)
                            // Style .thick cho kính dày hơn/đục hơn
//                            .glassEffect(.thick.interactive(), in: .circle)
                    }
                }
            }
        }
    }
}

#Preview {
    GlassEffectExample()
}
