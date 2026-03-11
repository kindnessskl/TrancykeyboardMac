import SwiftUI

struct TranslationResultView: View {
    let text: String
    let fontSize: CGFloat
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                        .padding(10)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()

                Image("keyboardicon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .padding(2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
                    .padding(10)
            }
            .frame(height: 40)

            // Content
            Button(action: onSelect) {
                ScrollView {
                    Text(text)
                        .font(.system(size: fontSize))
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(width: 320, height: 180)
        .glassEffectIfAvailable()
    }
}

extension View {
    @ViewBuilder
    func glassEffectIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18))
        } else {
            self.background(VisualEffectView(material: .popover, cornerRadius: 18))
        }
    }
}
