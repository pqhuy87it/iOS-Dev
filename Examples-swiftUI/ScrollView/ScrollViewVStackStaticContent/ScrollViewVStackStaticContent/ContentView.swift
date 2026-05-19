//
//  ContentView.swift
//  ScrollViewVStackStaticContent
//
//  Created by huy on 2026/04/14.
//

import SwiftUI

struct AboutAppView: View {
    var body: some View {
        // 1. ScrollView cho phép nội dung bên trong có thể cuộn được
        ScrollView {
            
            // 2. VStack bọc toàn bộ nội dung tĩnh.
            // Tất cả các view bên trong VStack này sẽ được load/render CÙNG MỘT LÚC ngay khi màn hình xuất hiện.
            VStack(spacing: 24) {
                
                // --- PHẦN 1: HEADER ---
                VStack(spacing: 8) {
                    Image(systemName: "sparkles.tv")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                        .padding()
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
                    
                    Text("SuperApp 2026")
                        .font(.title)
                        .bold()
                    
                    Text("Phiên bản 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 32)
                
                // --- PHẦN 2: MÔ TẢ TĨNH ---
                Text("SuperApp là ứng dụng tuyệt vời nhất giúp bạn quản lý công việc, kết nối bạn bè và khám phá thế giới xung quanh một cách dễ dàng và nhanh chóng.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Divider()
                
                // --- PHẦN 3: TÍNH NĂNG (Dữ liệu tĩnh, số lượng ít) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tính năng nổi bật:")
                        .font(.headline)
                    
                    FeatureRow(icon: "bolt.fill", title: "Tốc độ siêu nhanh", color: .yellow)
                    FeatureRow(icon: "lock.fill", title: "Bảo mật tuyệt đối", color: .green)
                    FeatureRow(icon: "icloud.fill", title: "Đồng bộ đám mây", color: .blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Divider()
                
                // --- PHẦN 4: LIÊN KẾT ---
                VStack(spacing: 12) {
                    Button(action: {
                        print("Mở trang web")
                    }) {
                        Text("Trang chủ của chúng tôi")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        print("Mở chính sách")
                    }) {
                        Text("Chính sách bảo mật")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
                
            }
            // Mở rộng VStack ra hết chiều ngang màn hình
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Thông tin Ứng dụng")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Subview hỗ trợ vẽ các hàng tính năng
struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .font(.body)
        }
    }
}

#Preview {
    NavigationView {
        AboutAppView()
    }
}
