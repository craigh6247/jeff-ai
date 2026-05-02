import SwiftUI

struct DeleteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
        }
        .buttonStyle(.borderless)
        .help("Delete")
    }
}
