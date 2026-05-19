import SwiftUI

struct ContentView: View {
    @StateObject private var uploadManager = BackgroundUploadManager.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 60))
                .foregroundColor(uploadManager.isUploading ? .blue : .gray)
            
            Text("Background Upload Test")
                .font(.title2).bold()
            
            VStack(spacing: 10) {
                ProgressView(value: uploadManager.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .padding(.horizontal, 40)
                
                Text(uploadManager.statusMessage)
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.0f%%", uploadManager.progress * 100))
                    .font(.caption)
                    .bold()
            }
            
            Button(action: {
                uploadManager.startHeavyUpload()
            }) {
                Text("Bắt đầu Upload")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: 200)
                    .background(uploadManager.isUploading ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(uploadManager.isUploading)
            
            Spacer()
        }
        .padding(.top, 50)
    }
}

#Preview {
    ContentView()
}
