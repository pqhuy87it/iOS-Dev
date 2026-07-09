import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - 1. SwiftData Model

/// Sử dụng @Model để lưu trữ đoạn văn bản đã được định dạng
@Model final class RichNote {
    /// Lưu ý: AttributedString chứa các thông tin định dạng (phông chữ, màu sắc) có thể khá lớn,
    /// nên Apple khuyến cáo sử dụng @Attribute(.externalStorage) để tối ưu hiệu suất cơ sở dữ liệu.
    @Attribute(.externalStorage) var content: AttributedString

    init(content: AttributedString = AttributedString("")) {
        self.content = content
    }
}

// MARK: - 2. Transferable Protocol

/// Đóng gói AttributedString để hỗ trợ các thao tác Drag & Drop hoặc Export ra file (ví dụ: RTFD)
struct RichTextDocument: Transferable, Codable {
    var text: AttributedString
    
    static var transferRepresentation: some TransferRepresentation {
        // 1. Hỗ trợ kéo thả nội bộ ứng dụng (giữ nguyên toàn bộ định dạng)
        CodableRepresentation(contentType: .json)
        
        // 2. Hỗ trợ kéo thả sang ứng dụng khác (fallback về dạng văn bản thuần túy)
        ProxyRepresentation(exporting: \.text.description)
    }
}

// MARK: - 3. Trình soạn thảo UI

struct RichTextEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [RichNote]

    /// State quản lý văn bản trực tiếp
    @State private var documentText: AttributedString = {
        var attrString = AttributedString("Hãy bắt đầu nhập văn bản rich text vào đây...\n")
        attrString.font = .headline
        attrString.foregroundColor = .blue
        return attrString
    }()

    var body: some View {
        NavigationStack {
            VStack {
                // TextEditor giờ đây nhận trực tiếp Binding<AttributedString>
                // Người dùng có thể bôi đen chữ để dùng menu định dạng mặc định (In đậm, In nghiêng, v.v.)
                TextEditor(text: $documentText)
                    .padding()
                    // Thêm tính năng Drag & Drop nguyên vẹn định dạng
                    .draggable(RichTextDocument(text: documentText))
                    .dropDestination(for: RichTextDocument.self) { droppedDocs, _ in
                        guard let firstDoc = droppedDocs.first else {
                            return false
                        }
                        // Nối văn bản được thả vào ngay văn bản hiện tại
                        documentText.append(AttributedString("\n"))
                        documentText.append(firstDoc.text)
                        return true
                    }
            }
            .navigationTitle("Soạn thảo Rich Text")
            .toolbar {
                // Ví dụ: Tạo Custom Control để chèn một đoạn văn bản có sẵn định dạng
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        appendCustomStyledText()
                    } label: {
                        Label("Chèn Highlight", systemImage: "highlighter")
                    }

                    Button("Lưu") {
                        saveNote()
                    }
                }
            }
        }
    }

    /// Hàm hỗ trợ chèn văn bản với thao tác (Attribute transformations) tùy chỉnh
    private func appendCustomStyledText() {
        var customString = AttributedString(" [Đoạn mã này được chèn tự động] ")
        customString.font = .body.bold()
        customString.backgroundColor = .yellow
        documentText.append(customString)
    }

    /// Lưu vào SwiftData
    private func saveNote() {
        let newNote = RichNote(content: documentText)
        modelContext.insert(newNote)
    }
}

// MARK: - 4. Preview với In-Memory Database

#Preview {
    RichTextEditorView()
        // Cung cấp container trên bộ nhớ tạm để Preview không bị lỗi SwiftData
        .modelContainer(for: RichNote.self, inMemory: true)
}
