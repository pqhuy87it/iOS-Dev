//
//  OpencodeTypingPlayground.swift
//  Thực hành PhaseAnimator với chuỗi nhiều phase (hiệu ứng gõ chữ)
//
//  Cách dùng: tạo iOS App (SwiftUI), dán toàn bộ file này vào,
//  rồi đổi body của app thành:
//
//      var body: some View { OpencodeTypingPlayground() }
//
//  Yêu cầu: iOS 17+ (PhaseAnimator).
//
//  Ý tưởng: PhaseAnimator nhận MỘT MẢNG phase và chạy tuần tự qua chúng,
//  lặp lại vô hạn. Với mỗi phase, closure content dựng lại view theo trạng
//  thái của phase đó, và closure animation quyết định curve/timing của bước
//  chuyển sang phase kế tiếp. Bằng cách chia nhỏ thành RẤT NHIỀU phase
//  (mỗi ký tự gõ/xóa + mỗi lần nhấp nháy con trỏ là một phase riêng),
//  ta mô phỏng được hiệu ứng gõ máy "Open|code" -> "X|code" -> "Open|code".
//

import SwiftUI

// =====================================================================
// MARK: - View chính (giữ nguyên logic đề bài)
// =====================================================================

struct OpencodeInXcode: View {
    var body: some View {
        PhaseAnimator(OpencodeTypingPhase.allCases) { phase in
            ZStack(alignment: .leading) {
                // "Opencode" ẩn (opacity 0) làm KHUNG GIỮ CHỖ: giữ chiều rộng
                // cố định để chữ không nhảy layout khi phần prefix đổi độ dài.
                Text("Opencode")
                    .opacity(0)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    // Phần đầu thay đổi theo phase: "Open" -> "Ope" -> ... -> "X" ...
                    Text(phase.prefix)

                    // Con trỏ nhấp nháy.
                    RoundedRectangle(cornerRadius: 1.5)
                        .foregroundStyle(.cyan)
                        .frame(width: 5, height: 62)
                        .opacity(phase.showsCursor ? 1 : 0)
                        // Căn con trỏ theo baseline chữ: lấy tâm dọc rồi đẩy
                        // xuống 18pt cho khớp với đáy chữ hoa cỡ 64.
                        .alignmentGuide(.firstTextBaseline) { context in
                            context[VerticalAlignment.center] + 18
                        }

                    // Phần đuôi "code" luôn cố định.
                    Text("code")
                }
            }
            .font(.system(size: 64, weight: .bold, design: .monospaced))
        } animation: { phase in
            // Mỗi phase tự khai báo curve riêng: gõ/xóa nhanh, nhấp nháy chậm hơn.
            phase.animation
        }
    }
}

// =====================================================================
// MARK: - Định nghĩa các phase
// =====================================================================
//
// Đọc tên phase như một "kịch bản" tuần tự:
//   Open|code (nháy) -> xóa dần về rỗng -> gõ X -> Xcode (nháy)
//   -> xóa X -> gõ lại O, p, e, n -> Open|code -> (lặp)
//
// Mỗi bước gõ/xóa đi kèm một phase "...CursorOff" để con trỏ tắt một nhịp,
// tạo cảm giác nhấp nháy tự nhiên.

private enum OpencodeTypingPhase: CaseIterable {
    case opencodeCursorOn
    case opencodeCursorOff
    case opencodeCursorOnAgain
    case eraseToOpe
    case eraseToOpeCursorOff
    case eraseToOp
    case eraseToOpCursorOff
    case eraseToO
    case eraseToOCursorOff
    case eraseToCode
    case eraseToCodeCursorOff
    case writeX
    case xcodeCursorOff
    case xcodeCursorOn
    case xcodeCursorOffAgain
    case eraseXToCode
    case eraseXToCodeCursorOff
    case writeO
    case writeOCursorOff
    case writeOp
    case writeOpCursorOff
    case writeOpe
    case writeOpeCursorOff
    case writeOpen
    case writeOpenCursorOff

    /// Phần chữ đứng TRƯỚC con trỏ ở mỗi phase.
    var prefix: String {
        switch self {
        case .opencodeCursorOn, .opencodeCursorOff, .opencodeCursorOnAgain:
            "Open"
        case .eraseToOpe, .eraseToOpeCursorOff, .writeOpe, .writeOpeCursorOff:
            "Ope"
        case .eraseToOp, .eraseToOpCursorOff, .writeOp, .writeOpCursorOff:
            "Op"
        case .eraseToO, .eraseToOCursorOff, .writeO, .writeOCursorOff:
            "O"
        case .eraseToCode, .eraseToCodeCursorOff, .eraseXToCode, .eraseXToCodeCursorOff:
            ""
        case .writeX, .xcodeCursorOff, .xcodeCursorOn, .xcodeCursorOffAgain:
            "X"
        case .writeOpen, .writeOpenCursorOff:
            "Open"
        }
    }

    /// Con trỏ có hiện ở phase này không.
    var showsCursor: Bool {
        switch self {
        case .opencodeCursorOff, .eraseToOpeCursorOff, .eraseToOpCursorOff,
             .eraseToOCursorOff, .eraseToCodeCursorOff, .xcodeCursorOff,
             .xcodeCursorOffAgain, .eraseXToCodeCursorOff, .writeOCursorOff,
             .writeOpCursorOff, .writeOpeCursorOff, .writeOpenCursorOff:
            false
        case .opencodeCursorOn, .opencodeCursorOnAgain, .eraseToOpe, .eraseToOp,
             .eraseToO, .eraseToCode, .writeX, .xcodeCursorOn, .eraseXToCode,
             .writeO, .writeOp, .writeOpe, .writeOpen:
            true
        }
    }

    /// Curve/timing cho bước chuyển sang phase kế tiếp.
    var animation: Animation {
        switch self {
        // Nhấp nháy con trỏ ở trạng thái đầy đủ: chậm hơn một chút.
        case .opencodeCursorOn, .opencodeCursorOff, .opencodeCursorOnAgain,
             .xcodeCursorOff, .xcodeCursorOn, .xcodeCursorOffAgain:
            .easeInOut(duration: 0.32)
        // Gõ hoặc xóa một ký tự: nhanh vừa.
        case .eraseToOpe, .eraseToOp, .eraseToO, .eraseToCode, .writeX,
             .eraseXToCode, .writeO, .writeOp, .writeOpe, .writeOpen:
            .easeInOut(duration: 0.22)
        // Nhịp tắt con trỏ ngắn giữa các lần gõ/xóa: rất nhanh.
        case .eraseToOpeCursorOff, .eraseToOpCursorOff, .eraseToOCursorOff,
             .eraseToCodeCursorOff, .eraseXToCodeCursorOff, .writeOCursorOff,
             .writeOpCursorOff, .writeOpeCursorOff, .writeOpenCursorOff:
            .easeInOut(duration: 0.12)
        }
    }
}

// =====================================================================
// MARK: - View cha bọc thêm nền + nút restart để dễ thực hành
// =====================================================================

struct OpencodeTypingPlayground: View {
    // Đổi id để "khởi động lại" toàn bộ chu trình PhaseAnimator.
    @State private var runID = UUID()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 48) {
                OpencodeInXcode()
                    .id(runID)   // gán lại id -> SwiftUI dựng lại view -> phase chạy từ đầu

                Button {
                    runID = UUID()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    OpencodeTypingPlayground()
}
