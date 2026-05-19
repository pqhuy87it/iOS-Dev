import SwiftUI
import Combine

// MARK: - Main Lock Screen View
struct iOS26LockScreen: View {
    @State private var currentTime = Date()
    @State private var starPositions: [StarData] = []
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background - Night sky gradient
                nightSkyBackground
                
                // Stars
                StarsFieldView(stars: starPositions)
                
                // Content
                VStack(spacing: 0) {
                    // Status bar
                    statusBar
                        .padding(.top, 12)
                    
                    // Lock icon
                    lockIcon
                        .padding(.top, 8)
                    
                    // Date & Location
                    dateLocationRow
                        .padding(.top, 4)
                    
                    // Large Glass Time
                    glassTimeDisplay(size: geo.size)
                        .padding(.top, -20)
                    
                    Spacer()
                    
                    // Bottom widgets
                    bottomWidgets
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)
                    
                    // Flashlight & Camera
                    bottomActions
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    
                    // Home indicator
                    homeIndicator
                        .padding(.bottom, 8)
                }
            }
            .onAppear {
                starPositions = generateStars(in: geo.size)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // MARK: - Night Sky Background
    private var nightSkyBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.08, blue: 0.18),
                Color(red: 0.08, green: 0.10, blue: 0.22),
                Color(red: 0.10, green: 0.14, blue: 0.28),
                Color(red: 0.14, green: 0.18, blue: 0.32),
                Color(red: 0.16, green: 0.20, blue: 0.34)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            Text("Viettel")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
            
            HStack(spacing: 4) {
                // Signal bars
                signalBars
                // WiFi
                Image(systemName: "wifi")
                    .font(.system(size: 13, weight: .semibold))
                // Battery
                batteryView
            }
            .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
    }
    
    private var signalBars: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(i < 2 ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 3, height: CGFloat(4 + i * 2))
            }
        }
    }
    
    private var batteryView: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .frame(width: 24, height: 12)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.yellow)
                    .frame(width: 24 * 0.34, height: 8)
                    .padding(.leading, 2)
            }
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.5))
                .frame(width: 1.5, height: 5)
            Text("34")
                .font(.system(size: 12, weight: .semibold))
        }
    }
    
    // MARK: - Lock Icon
    private var lockIcon: some View {
        Image(systemName: "lock.open.fill")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
    }
    
    // MARK: - Date & Location
    private var dateLocationRow: some View {
        HStack(spacing: 6) {
            Text(dayOfWeekAbbrev)
                .font(.system(size: 19, weight: .medium))
            Text(dayNumber)
                .font(.system(size: 19, weight: .medium))
            
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
            
            Text("Hanoi")
                .font(.system(size: 19, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.9))
    }
    
    // MARK: - Glass Time Display (Core Effect)
    private func glassTimeDisplay(size: CGSize) -> some View {
        let timeString = formattedTime
        let fontSize: CGFloat = size.width * 0.42
        
        return ZStack {
            // Layer 1: Deep shadow for 3D depth
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(
                    Color.black.opacity(0.5)
                )
                .offset(y: 6)
                .blur(radius: 4)
            
            // Layer 2: Dark base with slight transparency
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.28, blue: 0.38).opacity(0.6),
                            Color(red: 0.18, green: 0.20, blue: 0.30).opacity(0.5),
                            Color(red: 0.22, green: 0.25, blue: 0.35).opacity(0.55)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            
            // Layer 3: Glass highlight - top edge light reflection
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            
            // Layer 4: Subtle inner glow / frosted glass effect
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.58, blue: 0.70).opacity(0.3),
                            Color(red: 0.40, green: 0.43, blue: 0.55).opacity(0.15),
                            Color(red: 0.50, green: 0.53, blue: 0.65).opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Layer 5: Stroke outline for glass edge
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(Color.clear)
                .overlay(
                    timeText(timeString, fontSize: fontSize)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .mask(
                            timeText(timeString, fontSize: fontSize)
                                .foregroundStyle(Color.white)
                                .overlay(
                                    timeText(timeString, fontSize: fontSize)
                                        .foregroundStyle(Color.black)
                                        .padding(1.5)
                                )
                                .compositingGroup()
                                .luminanceToAlpha()
                        )
                )
            
            // Layer 6: Bottom reflection / ambient light
            timeText(timeString, fontSize: fontSize)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.clear,
                            Color(red: 0.45, green: 0.48, blue: 0.60).opacity(0.15),
                            Color(red: 0.50, green: 0.55, blue: 0.70).opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func timeText(_ text: String, fontSize: CGFloat) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .kerning(-fontSize * 0.02)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
    
    // MARK: - Bottom Widgets
    private var bottomWidgets: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // Weather widget
            weatherWidget
            
            Spacer()
            
            // Rain forecast
            circleWidget(
                icon: "cloud.rain.fill",
                label: "THU",
                iconSize: 16
            )
            
            // UV Index
            uvIndexWidget
        }
    }
    
    private var weatherWidget: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                Text("28°")
                    .font(.system(size: 20, weight: .medium))
            }
            Text("Clear")
                .font(.system(size: 14, weight: .regular))
            HStack(spacing: 2) {
                Text("↑37°")
                    .font(.system(size: 13, weight: .regular))
                Text("↓25°")
                    .font(.system(size: 13, weight: .regular))
            }
            .foregroundColor(.white.opacity(0.7))
        }
        .foregroundColor(.white.opacity(0.9))
    }
    
    private func circleWidget(icon: String, label: String, iconSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 52, height: 52)
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: iconSize))
                        .foregroundColor(.white.opacity(0.9))
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
    
    private var uvIndexWidget: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.15))
                .frame(width: 52, height: 52)
            
            // UV gauge arc
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(0))
            
            Circle()
                .trim(from: 0.15, to: 0.15)
                .stroke(Color.white.opacity(0.6), lineWidth: 3)
                .frame(width: 40, height: 40)
            
            VStack(spacing: 0) {
                Text("0")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 3, height: 3)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                    Circle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 3, height: 3)
                }
            }
        }
    }
    
    // MARK: - Bottom Actions
    private var bottomActions: some View {
        HStack {
            actionButton(icon: "flashlight.off.fill")
            Spacer()
            actionButton(icon: "camera.fill")
        }
    }
    
    private func actionButton(icon: String) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 52, height: 52)
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 52, height: 52)
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Home Indicator
    private var homeIndicator: some View {
        Capsule()
            .fill(Color.white.opacity(0.5))
            .frame(width: 135, height: 5)
    }
    
    // MARK: - Time Formatting
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: currentTime)
    }
    
    private var dayOfWeekAbbrev: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: currentTime)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: currentTime)
    }
    
    // MARK: - Star Generation
    private func generateStars(in size: CGSize) -> [StarData] {
        (0..<120).map { _ in
            StarData(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height * 0.75),
                size: CGFloat.random(in: 0.5...2.5),
                opacity: Double.random(in: 0.2...0.8)
            )
        }
    }
}

// MARK: - Star Data Model
struct StarData: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
}

// MARK: - Stars Field View
struct StarsFieldView: View {
    let stars: [StarData]
    @State private var twinkle = false
    
    var body: some View {
        Canvas { context, _ in
            for star in stars {
                let rect = CGRect(
                    x: star.x - star.size / 2,
                    y: star.y - star.size / 2,
                    width: star.size,
                    height: star.size
                )
                context.opacity = star.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(.white)
                )
                
                // Glow effect for brighter stars
                if star.size > 1.8 {
                    let glowRect = CGRect(
                        x: star.x - star.size,
                        y: star.y - star.size,
                        width: star.size * 2,
                        height: star.size * 2
                    )
                    context.opacity = star.opacity * 0.3
                    context.fill(
                        Circle().path(in: glowRect),
                        with: .color(.white)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview
#Preview {
    iOS26LockScreen()
}
