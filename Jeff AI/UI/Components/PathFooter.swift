import SwiftUI

struct PathFooter: View {
    let path: String
    let icon: String

    init(path: String, icon: String = "doc.text") {
        self.path = path
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
                .font(.caption)
            Text(path)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}
