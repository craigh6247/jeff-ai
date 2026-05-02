import SwiftUI

struct ModelsSettingsView: View {
    @EnvironmentObject var models: ModelsStore
    @State private var newRepoID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            installedSection
            Divider()
            downloadSection
            Spacer()
            footer
        }
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader("Installed Models")
            if models.installed.isEmpty {
                Text("No models installed yet. Download one below to get started.")
                    .foregroundStyle(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(models.installed) { model in
                            ModelRow(model: model)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Download from Hugging Face")
            HStack {
                TextField("e.g. mlx-community/Llama-3.2-3B-Instruct-4bit", text: $newRepoID)
                    .textFieldStyle(.roundedBorder)
                    .disabled(models.isDownloading)
                    .onSubmit(triggerDownload)
                Button(models.isDownloading ? "Downloading…" : "Download") {
                    triggerDownload()
                }
                .disabled(trimmedNewID.isEmpty || models.isDownloading)
            }
            .padding(.horizontal, 16)

            if models.isDownloading {
                VStack(alignment: .leading, spacing: 4) {
                    if let id = models.downloadingRepoID {
                        Text(id)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    if !models.downloadStatus.isEmpty {
                        Text(models.downloadStatus)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    ProgressView(value: models.downloadProgress)
                }
                .padding(.horizontal, 16)
            }

            if let err = models.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
            }

            Text("Use any MLX-compatible repo. Models from the mlx-community org are the safest bet.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    private var footer: some View {
        PathFooter(path: models.modelsDirectory.path, icon: "folder")
    }

    private var trimmedNewID: String {
        newRepoID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func triggerDownload() {
        let id = trimmedNewID
        guard !id.isEmpty else { return }
        Task {
            await models.download(repoID: id)
            if models.lastError == nil {
                newRepoID = ""
            }
        }
    }
}

private struct ModelRow: View {
    @EnvironmentObject var models: ModelsStore
    let model: ModelsStore.InstalledModel

    var isDefault: Bool { models.defaultRepoID == model.repoID }

    var body: some View {
        ListRow {
            Button {
                models.setDefault(isDefault ? nil : model.repoID)
            } label: {
                Image(systemName: isDefault ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDefault ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help(isDefault ? "Unset default" : "Make default")
        } content: {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.repoID)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }
        } trailing: {
            DeleteButton { models.delete(model) }
        }
    }
}
