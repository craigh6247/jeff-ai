import SwiftUI

struct ContentView: View {
    @EnvironmentObject var chat: ChatViewModel
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            transcript
            Divider()
            inputBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { inputFocused = true }
        .alert("Error", isPresented: .constant(chat.errorMessage != nil), actions: {
            Button("OK") { chat.errorMessage = nil }
        }, message: {
            Text(chat.errorMessage ?? "")
        })
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chat.messages.isEmpty {
                        emptyState
                            .padding(.top, 80)
                    }
                    ForEach(chat.messages) { msg in
                        MessageRow(message: msg)
                            .id(msg.id)
                    }
                    if chat.isGenerating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Thinking…").foregroundStyle(.secondary).font(.callout)
                        }
                        .padding(.horizontal, 16)
                        .id("generating")
                    }
                }
                .padding(.vertical, 16)
            }
            .onChange(of: chat.messages.count) { _, _ in
                if let last = chat.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: chat.streamingTick) { _, _ in
                if let last = chat.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("Jeff AI").font(.title2).fontWeight(.semibold)
            Text("Local MLX chat. Type below to start.")
                .foregroundStyle(.secondary)
                .font(.callout)
            if let modelID = chat.activeModelID {
                Text("Model: \(modelID)")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .padding(.top, 4)
            } else {
                Text("No model selected — open Settings → Models (⌘,)")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("Message Jeff…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($inputFocused)
                .onSubmit(submit)

            Button(action: submit) {
                Image(systemName: chat.isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(chat.isGenerating ? false : draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
    }

    private func submit() {
        if chat.isGenerating {
            chat.cancel()
            return
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        Task { await chat.send(text) }
    }
}

private struct MessageRow: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(message.role == .user ? "You" : "Jeff")
                .font(.caption).fontWeight(.semibold)
                .foregroundStyle(message.role == .user ? .blue : .purple)
                .frame(width: 36, alignment: .leading)
            Text(message.content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    let s = SettingsStore()
    let m = ModelsStore(settings: s)
    return ContentView()
        .environmentObject(ChatViewModel())
        .environmentObject(s)
        .environmentObject(m)
        .frame(width: 600, height: 500)
}
