import SwiftUI

struct ContentView: View {
    @State private var text: String = ""

    var body: some View {
        ZStack {
            BlurView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
                .allowsHitTesting(false) // keep the glass visual while letting the text editor receive clicks

            VStack(alignment: .leading, spacing: 14) {
                Text("Liquid Glass Note")
                    .font(.system(.title2, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.system(.body, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .padding(24)
        }
        .background(Color.clear)
    }
}
