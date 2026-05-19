import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // 1. Biểu đồ đường (Line Chart)
                    LineChartView(
                        data: [8, 23, 54, 32, 12, 37, 7, 23, 43],
                        title: "Người dùng",
                        legend: "Hàng tháng",
                        style: Styles.lineChartStyleOne,
                        form: ChartForm.large,
                        rateValue: 14,
                        dropShadow: true
                    )
                    
                    // 2. Biểu đồ cột (Bar Chart)
                    // Sử dụng ChartData với tuples để hiển thị tên cột (ví dụ: Q1, Q2) khi nhấn vào
                    BarChartView(
                        data: ChartData(values: [
                            ("Q1", 150),
                            ("Q2", 230),
                            ("Q3", 180),
                            ("Q4", 310)
                        ]),
                        title: "Doanh thu",
                        legend: "Năm 2023",
                        style: Styles.barChartStyleNeonBlueLight,
                        form: ChartForm.large,
                        dropShadow: true,
                        cornerImage: Image(systemName: "dollarsign.circle"),
                        animatedToBack: true
                    )
                    
                    // 3. Biểu đồ tròn (Pie Chart)
                    PieChartView(
                        data: [25, 15, 40, 20],
                        title: "Thị phần",
                        legend: "Theo phần trăm",
                        style: Styles.pieChartStyleOne,
                        form: ChartForm.large,
                        dropShadow: true
                    )
                    
                    // 4. Biểu đồ nhiều đường (Multi-Line Chart)
                    MultiLineChartView(
                        data: [
                            ([8, 23, 54, 32, 12, 37, 7, 23, 43], GradientColors.orngPink),
                            ([12, 30, 24, 42, 22, 17, 37, 13, 23], GradientColors.bluPurpl)
                        ],
                        title: "So sánh",
                        legend: "Sản phẩm A vs B",
                        style: Styles.lineChartStyleOne,
                        form: ChartForm.large,
                        dropShadow: true
                    )
                    
                }
                .padding()
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    ContentView()
}
