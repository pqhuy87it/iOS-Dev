//
//  GlassEffectCorrected.swift
//  UIGlassEffectExample2
//
//  Created by huy on 2026/02/11.
//

import SwiftUI

struct GlassEffectCorrected: View {
    var body: some View {
        ZStack {
            // Hình nền
            Image("abstract_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                
                // CASE 1: Dùng .regular (Mặc định, thay thế cho việc không cần chỉnh độ dày)
                // Hệ thống tự tính toán độ mờ để nội dung dễ đọc
                VStack {
                    Text("Regular Glass")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Auto-adjusts legibility")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(width: 200, height: 100)
                // ✅ Sử dụng .regular có sẵn
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
                
                // CASE 2: Giả lập ".thin" bằng cách dùng .clear + Background
                // Trong định nghĩa code bạn gửi có gợi ý: "add a dimming layer... beneath the glass"
                VStack {
                    Text("Custom Thin Glass")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Clear + Opacity 0.2")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding()
                .frame(width: 200, height: 100)
                // ✅ Bước 1: Dùng .clear (trong suốt)
                .glassEffect(.clear, in: .rect(cornerRadius: 20))
                // ✅ Bước 2: Tự chỉnh độ "mỏng" bằng background opacity
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.black.opacity(0.2)) // Opacity thấp = Thin, Cao = Thick
                )
                
                // CASE 3: Kết hợp .tint và .interactive (Có trong định nghĩa)
                Button(action: { print("Tapped") }) {
                    Image(systemName: "hand.tap.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        // ✅ Dùng hàm .tint() và .interactive() có trong struct
                        .glassEffect(.regular.tint(.blue).interactive(true), in: .circle)
                }
            }
        }
    }
}

#Preview {
    GlassEffectCorrected()
}
