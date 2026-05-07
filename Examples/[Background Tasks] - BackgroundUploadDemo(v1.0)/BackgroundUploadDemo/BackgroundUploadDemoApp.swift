//
//  BackgroundUploadDemoApp.swift
//  BackgroundUploadDemo
//
//  Created by huy on 2026/05/06.
//

import SwiftUI

@main
struct BackgroundUploadDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Lắng nghe sự kiện hệ điều hành báo cáo Session ngầm đã hoàn tất.
        // ID ở đây phải khớp 100% với identifier khi tạo URLSessionConfiguration.
        .backgroundTask(.urlSession("com.myapp.backgroundUpload")) {
            print("🔄 Ứng dụng được OS đánh thức để xử lý Background URL Session!")
            
            // Ở đây, bạn chỉ cần gọi lại cấu hình Session (nếu manager chưa được khởi tạo)
            // Vì chúng ta dùng Singleton (BackgroundUploadManager.shared),
            // instance này sẽ tự động khởi tạo lại và nối lại (re-attach) với Session cũ của OS,
            // từ đó kích hoạt các hàm delegate (didCompleteWithError).
            let _ = await BackgroundUploadManager.shared
        }
    }
}
