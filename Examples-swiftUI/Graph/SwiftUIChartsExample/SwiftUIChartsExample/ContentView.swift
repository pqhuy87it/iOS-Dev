//
//  ContentView.swift
//  SwiftUIChartsExample
//
//  Created by huy on 2026/03/25.
//

import SwiftUI

struct ContentView: View {
    // 1. Tạo các Legend (Chú giải) để phân loại màu sắc và ý nghĩa dữ liệu
    let revenueLegend = Legend(color: .green, label: "Doanh thu", order: 1)
    let expenseLegend = Legend(color: .red, label: "Chi phí", order: 2)
    let profitLegend = Legend(color: .blue, label: "Lợi nhuận", order: 3)

    // 2. Tạo mảng DataPoint (Dữ liệu) chứa các giá trị cho biểu đồ
    var monthlyData: [DataPoint] {
        [
            DataPoint(value: 120, label: "Tháng 1", legend: revenueLegend),
            DataPoint(value: 80,  label: "Tháng 2", legend: expenseLegend),
            DataPoint(value: 150, label: "Tháng 3", legend: revenueLegend),
            DataPoint(value: 60,  label: "Tháng 4", legend: profitLegend),
            DataPoint(value: 200, label: "Tháng 5", legend: revenueLegend),
            DataPoint(value: 110, label: "Tháng 6", legend: expenseLegend)
        ]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 40) {
                    
                    // --- BIỂU ĐỒ CỘT (BAR CHART) ---
                    VStack(alignment: .leading) {
                        Text("Biểu đồ Cột (Bar Chart)")
                            .font(.headline)
                        
                        BarChartView(dataPoints: monthlyData)
                            // Sử dụng modifier .chartStyle để tuỳ chỉnh giao diện biểu đồ
                            .chartStyle(
                                BarChartStyle(
                                    barMinHeight: 100,
                                    showAxis: true,
                                    showLabels: true,
                                    showLegends: true
                                )
                            )
                            .frame(height: 250)
                    }
                    
                    // --- BIỂU ĐỒ ĐƯỜNG (LINE CHART) ---
                    VStack(alignment: .leading) {
                        Text("Biểu đồ Đường (Line Chart)")
                            .font(.headline)
                        
                        LineChartView(dataPoints: monthlyData)
                            .chartStyle(
                                LineChartStyle(
                                    lineMinHeight: 100,
                                    showAxis: true,
                                    showLabels: true,
                                    showLegends: true,
                                    drawing: .stroke(width: 3) // Vẽ dạng đường kẻ thay vì tô kín
                                )
                            )
                            .frame(height: 250)
                    }
                    
                    // --- BIỂU ĐỒ CỘT NGANG XẾP CHỒNG (STACKED HORIZONTAL) ---
                    VStack(alignment: .leading) {
                        Text("Cột ngang xếp chồng")
                            .font(.headline)
                        
                        StackedHorizontalBarChartView(dataPoints: monthlyData)
                            .chartStyle(
                                StackedHorizontalBarChartStyle(
                                    showLegends: true,
                                    cornerRadius: 8,
                                    spacing: 4
                                )
                            )
                            .frame(height: 80)
                    }
                    
                }
                .padding()
            }
            .navigationTitle("Báo cáo Tài chính")
        }
    }
}

// Preview để bạn có thể xem trực tiếp trong Xcode Canvas
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
