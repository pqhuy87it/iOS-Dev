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
        // Identifier phải khớp với trong URLSessionConfiguration
        .backgroundTask(.urlSession("com.myapp.heavyBackgroundUpload")) {
            print("🚀 HỆ THỐNG ĐÃ ĐÁNH THỨC APP VÌ UPLOAD XONG!")
            
            // Khởi tạo lại Singleton để hứng delegate callback
            let _ = await BackgroundUploadManager.shared
        }
    }
}
