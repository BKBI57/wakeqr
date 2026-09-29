import SwiftUI
import UIKit

/// The ringing screen. No stop button, no snooze, no way out.
/// The ONLY exit is scanning the QR code whose payload equals AppModel.qrPayload.
struct RingingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var pulse = false
    @State private var wrongCode = false

    private var title: String {
        if let from = model.buddyRingFrom { return "\(AppModel.buddyName(from)) عم يصحّيك! 🔔" }
        return model.isFollowUpRing ? "رجعت نمت! 🔔" : "استيقظ! 🔔"
    }

    private var subtitle: String {
        if let from = model.buddyRingFrom {
            return "امسح رمز QR لإيقافه\nوبيوصل لـ\(AppModel.buddyName(from)) إنك صحيت"
        }
        return model.isFollowUpRing
            ? "ما أكّدت إنك صاحي خلال ٥ دقائق.\nامسح الرمز مرة أخرى"
            : "الطريقة الوحيدة للإيقاف:\nامسح رمز QR المطبوع"
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)

            Text(subtitle)
                .font(.title3.bold())
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            QRScannerView { code in
                if !model.handleScannedCode(code) {
                    wrongCode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { wrongCode = false }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(wrongCode ? Color.yellow : Color.white.opacity(0.6), lineWidth: 4)
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .padding(.horizontal, 28)

            Text(wrongCode ? "❌ رمز خاطئ! هذا ليس رمز WakeQR" : "وجّه الكاميرا نحو الرمز")
                .font(.headline)
                .foregroundStyle(wrongCode ? .yellow : .white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 0.75, green: 0.05, blue: 0.05), Color(red: 0.4, green: 0, blue: 0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear {
            pulse = true
            UIScreen.main.brightness = 1.0
        }
    }
}
