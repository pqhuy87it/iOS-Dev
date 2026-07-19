import SwiftUI

// MARK: - Model
// Mỗi dòng trong sheet là 1 mảng các cột (dạng String)
struct SheetRow: Identifiable {
    let id = UUID()
    let cells: [String]
}

// MARK: - ViewModel
@Observable
final class SheetViewModel {
    var headers: [String] = []      // Dòng tiêu đề (row đầu tiên)
    var rows: [SheetRow] = []       // Các dòng dữ liệu còn lại
    var isLoading = false
    var errorMessage: String?

    // ⚠️ THAY URL NÀY bằng link CSV thật của bạn (xem hướng dẫn cuối file)
    // Ví dụ Google Sheets: https://docs.google.com/spreadsheets/d/<ID>/export?format=csv
    private let sheetURL = URL(string: "https://docs.google.com/spreadsheets/d/1bznOj_hn2dK1tGJpf71X4-NR1YaSUi9D/export?format=csv")!
    @MainActor
    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Tải dữ liệu từ URL
            let (data, response) = try await URLSession.shared.data(from: sheetURL)

            // Kiểm tra HTTP status
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                errorMessage = "HTTP \(http.statusCode) — kiểm tra lại quyền share (anyone with link)"
                return
            }

            // Chuyển bytes → String
            guard let csvString = String(data: data, encoding: .utf8) else {
                errorMessage = "Không decode được UTF-8. File có thể là .xlsx chứ không phải CSV."
                return
            }

            // Parse CSV
            let parsed = Self.parseCSV(csvString)
            guard !parsed.isEmpty else {
                errorMessage = "File rỗng hoặc không đúng định dạng CSV."
                return
            }

            headers = parsed.first ?? []
            rows = parsed.dropFirst().map { SheetRow(cells: $0) }

        } catch {
            errorMessage = "Lỗi tải dữ liệu: \(error.localizedDescription)"
        }
    }

    // MARK: - CSV Parser
    // Parser xử lý được: dấu phẩy trong ô (bọc bởi "), xuống dòng trong ô, escape "" -> "
    static func parseCSV(_ text: String) -> [[String]] {
        var result: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        // Chuẩn hóa xuống dòng CRLF -> LF
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")

        var iterator = normalized.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }

        while let ch = next() {
            if insideQuotes {
                if ch == "\"" {
                    // Kiểm tra escape "" (dấu ngoặc kép trong ô)
                    if let peek = iterator.next() {
                        if peek == "\"" {
                            currentField.append("\"")     // "" -> "
                        } else {
                            insideQuotes = false
                            pending = peek                 // đẩy ký tự vừa đọc lại
                        }
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    insideQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    result.append(currentRow)
                    currentRow = []
                    currentField = ""
                default:
                    currentField.append(ch)
                }
            }
        }

        // Dòng cuối (nếu file không kết thúc bằng \n)
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            result.append(currentRow)
        }

        // Loại các dòng hoàn toàn rỗng
        return result.filter { !($0.count == 1 && $0[0].isEmpty) }
    }
}

// MARK: - View
struct SheetViewer: View {
    @State private var viewModel = SheetViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Đang tải dữ liệu…")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Không tải được", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Thử lại") {
                            Task { await viewModel.load() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if viewModel.rows.isEmpty {
                    ContentUnavailableView("Chưa có dữ liệu", systemImage: "tablecells")
                } else {
                    sheetTable
                }
            }
            .navigationTitle("Sheet Viewer")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            // Tự động tải khi mở màn hình
            await viewModel.load()
        }
    }

    // Bảng cuộn 2 chiều (ngang + dọc)
    private var sheetTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(viewModel.rows) { row in
                        HStack(spacing: 0) {
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                Text(cell)
                                    .font(.callout)
                                    .frame(width: 140, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 6)
                            }
                        }
                        Divider()
                    }
                } header: {
                    HStack(spacing: 0) {
                        ForEach(Array(viewModel.headers.enumerated()), id: \.offset) { _, header in
                            Text(header)
                                .font(.subheadline.bold())
                                .frame(width: 140, alignment: .leading)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 6)
                        }
                    }
                    .background(.thinMaterial)   // Header dính khi cuộn
                }
            }
        }
    }
}

#Preview {
    SheetViewer()
}

/*
 ============================ HƯỚNG DẪN LẤY URL CSV ============================

 Link bạn gửi là SharePoint (.xlsx), KHÔNG trả CSV trực tiếp → khó parse trong Swift.
 Chọn 1 trong 2 cách:

 CÁCH A — Dùng Google Sheets (khuyến nghị, đơn giản nhất):
   1. Import file Excel của bạn vào Google Sheets (File → Import).
   2. Share → "Anyone with the link" → Viewer.
   3. Lấy URL export CSV theo format:
        https://docs.google.com/spreadsheets/d/<SHEET_ID>/export?format=csv
      (Nếu có nhiều tab, thêm &gid=<GID> để chọn sheet cụ thể.)
   4. Dán vào biến `sheetURL` ở trên.

 CÁCH B — Giữ SharePoint/Excel Online:
   1. Mở file trên Excel Online → File → Export → Download as CSV.
   2. Upload file .csv đó lên host tĩnh có CORS (GitHub raw, S3 public...).
   3. Dán URL .csv vào `sheetURL`.

 LƯU Ý ATS (App Transport Security):
   - URL trên đều là HTTPS nên chạy được ngay, không cần chỉnh Info.plist.
   - Nếu test với server HTTP local, thêm exception ATS.
 =============================================================================
*/
