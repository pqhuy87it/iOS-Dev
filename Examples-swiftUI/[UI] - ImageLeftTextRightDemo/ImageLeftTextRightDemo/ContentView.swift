import SwiftUI

struct ContentView: View {
    // Danh sách tin nhắn mẫu với độ dài text khác nhau để bạn thấy view co giãn
    let messages: [String] = [
        "SomeText Here. It will expand the StackView. SomeText Here. It will expand the StackView. SomeText Here. It will expand the StackView. SomeText Here. It will expand the StackView. SomeText Here. It will expand the StackView.",
        "Text ngắn thôi.",
        "Text vừa vừa, đủ để xuống vài dòng cho bạn thấy chấm tròn vẫn dính ở trên cùng nhé."
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(messages, id: \.self) { message in
                    MessageRow(text: message)
                }
            }
            .padding(16)
        }
    }
}

struct MessageRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // View bên trái: kích thước CỐ ĐỊNH bằng đúng ảnh chấm tròn, không giãn
            Circle()
                .fill(.black)
                .frame(width: 60, height: 60)

            // View bên phải: chứa text, TỰ GIÃN chiếm hết phần còn lại
            Text(text)
                .font(.system(size: 22))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading) // nuốt hết chiều ngang còn dư
                .padding(16)
                .background(
                    Color(red: 0.15, green: 0.15, blue: 0.6) // nền xanh đậm view phải
                )
        }
        .padding(16)
        .background(
            Color(red: 0.55, green: 0.35, blue: 1.0) // nền tím view cha
        )
        .clipShape(RoundedRectangle(cornerRadius: 12)) // bo góc như trong ảnh
    }
}

#Preview {
    ContentView()
}
