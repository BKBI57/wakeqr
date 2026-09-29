import SwiftUI

/// One named button per person. Pressing someone's button rings their phone until they scan
/// their QR code; pressing your own rings this phone (a quick way to test that it works).
struct BuddyPanel: View {
    @EnvironmentObject private var model: AppModel
    @State private var target: String?

    var body: some View {
        VStack(spacing: 10) {
            if let me = model.buddyMe {
                Text("صحّي صاحبك 🔔")
                    .font(.subheadline.bold())

                HStack(spacing: 12) {
                    ForEach(AppModel.buddies, id: \.id) { buddy in
                        Button {
                            target = buddy.id
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "bell.and.waves.left.and.right.fill")
                                    .font(.title2)
                                Text(buddy.name)
                                    .font(.headline.bold())
                                Text(buddy.id == me ? "أنت (تجربة)" : "صحّيه")
                                    .font(.caption2)
                                    .opacity(0.75)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(buddy.id == me ? 0.08 : 0.2)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let status = model.buddyStatus {
                    Text(status)
                        .font(.footnote.bold())
                        .multilineTextAlignment(.center)
                }

                Button("مش \(AppModel.buddyName(me))؟ غيّر") {
                    model.buddyMe = nil
                }
                .font(.caption2)
                .opacity(0.55)
            } else {
                Text("مين أنت على هالتلفون؟")
                    .font(.subheadline.bold())
                HStack(spacing: 12) {
                    ForEach(AppModel.buddies, id: \.id) { buddy in
                        Button(buddy.name) {
                            model.buddyMe = buddy.id
                        }
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.2)))
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        // A confirm step, so a button bumped by accident at night doesn't wake anyone.
        .confirmationDialog(
            "متأكد؟",
            isPresented: Binding(get: { target != nil }, set: { if !$0 { target = nil } }),
            presenting: target
        ) { id in
            Button("صحّي \(AppModel.buddyName(id)) الآن 🔔") {
                model.sendBuddyRing(to: id)
            }
            Button("إلغاء", role: .cancel) {}
        } message: { id in
            Text("تلفون \(AppModel.buddyName(id)) رح يرن وما بيسكت إلا بمسح رمز QR")
        }
    }
}
