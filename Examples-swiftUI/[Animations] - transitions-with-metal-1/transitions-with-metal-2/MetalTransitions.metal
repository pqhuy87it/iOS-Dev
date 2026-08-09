#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ============================================================
// 1. rippleDistortion — dùng cho "Initial approach"
//    (kèm CircularRevealShape + removal .opacity ở Swift)
// ============================================================
[[ stitchable ]]
float2 rippleDistortion(float2 position, float2 size, float progress, float2 tapLocation) {
    float2 toCenter = position - tapLocation;
    float dist = length(toCenter);

    float maxDist = length(size);
    float waveFront = progress * maxDist * 1.4;

    float thickness = 60.0;
    float amplitude = 18.0;

    float d = dist - waveFront;
    float ring = smoothstep(thickness, 0.0, abs(d));
    float ripple = sin(d * 0.15) * amplitude * ring;

    float2 dir = dist > 0.0 ? normalize(toCenter) : float2(0.0, 0.0);
    return position + dir * ripple;
}

// ============================================================
// 2. slideAwayRipple — "A better approach" (theo Pavel)
//    Mỗi pixel bị "nén" về tâm rồi trượt trở ra vị trí gốc.
//    Không cần clipShape/masking.
// ============================================================
[[ stitchable ]]
float2 slideAwayRipple(float2 position, float2 size, float progress, float direction) {
    float2 c = size / 2.0;
    float2 v = position - c;

    // f = thời điểm (0..1) pixel này "được phép" bắt đầu di chuyển.
    // direction đảo chiều quét trái->phải hoặc phải->trái.
    float f = (direction > 0 ? position.x : (size.x - position.x)) / size.x;

    if (progress > f) {
        // ánh xạ [f .. 1] về [0 .. 1]
        float mul = (progress - f) / (1.0 - f);
        return c + v * mul;   // c + v*0 = tâm; c + v*1 = vị trí gốc
    } else {
        // pixel chưa xuất hiện -> sample ngoài layer -> trong suốt
        return float2(-1.0, -1.0);
    }
}

// ============================================================
// 3. liquidWave — "Improving my ripples"
//    Kết hợp ngưỡng theo khoảng cách tới tâm + gợn sóng sin.
//    progress: 0.0 -> 1.0 (ở đây tính từ tâm, không dùng tap location)
// ============================================================
[[ stitchable ]]
float2 liquidWave(float2 position, float2 size, float progress, float direction) {
    float2 center = size / 2.0;
    float2 fromCenter = position - center;

    float dist = length(fromCenter) / length(center);
    float f = direction > 0 ? dist : (1.0 - dist);

    if (progress > f) {
        float revealAmount = (progress - f) / (1.0 - f);

        float wave1 = sin(position.x * 0.02 + progress * 8.0) * 15.0;
        float wave2 = sin(position.y * 0.03 + progress * 6.0) * 10.0;
        float wave3 = sin(dist * 20.0 - progress * 12.0) * 8.0;

        // gợn mạnh lúc mới hiện, phẳng dần khi lộ hoàn toàn
        float2 waveOffset = float2(wave1 + wave3, wave2 + wave3) * (1.0 - revealAmount);
        return position + waveOffset;
    } else {
        return float2(-1.0, -1.0);
    }
}
