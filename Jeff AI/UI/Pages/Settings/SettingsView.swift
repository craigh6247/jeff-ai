import SwiftUI

struct SettingsView: View {
    enum Tab: String, CaseIterable, Identifiable, Hashable {
        case models = "Models"
        case advanced = "Advanced"

        var id: Self { self }
        var icon: String {
            switch self {
            case .models: return "cube.box"
            case .advanced: return "slider.horizontal.3"
            }
        }
    }

    @State private var selection: Tab = .models

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, selection: $selection) { tab in
                Label(tab.rawValue, systemImage: tab.icon).tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            switch selection {
            case .models:
                ModelsSettingsView()
            case .advanced:
                AdvancedSettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 760, minHeight: 520)
    }
}

struct AdvancedSettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var newKey: String = ""
    @State private var newValue: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Capabilities")
            list
            Divider()
            addRow
            PathFooter(path: settings.path)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                if settings.entries.isEmpty {
                    Text("No settings yet. Add a capability below.")
                        .foregroundStyle(.secondary)
                        .padding(32)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(settings.entries.keys.sorted(), id: \.self) { key in
                        SettingRow(key: key, value: settings.entries[key] ?? "")
                        Divider()
                    }
                }
            }
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            TextField("capability", text: $newKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
            TextField("setting", text: $newValue)
                .textFieldStyle(.roundedBorder)
                .onSubmit(commitNew)
            Button("Add", action: commitNew)
                .disabled(trimmedNewKey.isEmpty)
        }
        .padding(12)
    }

    private var trimmedNewKey: String {
        newKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitNew() {
        let k = trimmedNewKey
        guard !k.isEmpty else { return }
        settings.set(k, to: newValue)
        newKey = ""
        newValue = ""
    }
}

private struct SettingRow: View {
    @EnvironmentObject var settings: SettingsStore
    let key: String
    let value: String

    @State private var draft: String = ""
    @State private var editing: Bool = false

    var body: some View {
        ListRow {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .frame(width: 180, alignment: .leading)
                .lineLimit(1)
                .truncationMode(.tail)
        } content: {
            if editing {
                HStack(spacing: 8) {
                    TextField("", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(commit)
                    Button("Save", action: commit)
                }
            } else {
                HStack(spacing: 8) {
                    Text(value)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                    Button("Edit") {
                        draft = value
                        editing = true
                    }
                }
            }
        } trailing: {
            DeleteButton { settings.remove(key) }
        }
    }

    private func commit() {
        settings.set(key, to: draft)
        editing = false
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore())
        .environmentObject(ModelsStore(settings: SettingsStore()))
}
