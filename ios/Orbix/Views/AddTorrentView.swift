import SwiftUI
import UniformTypeIdentifiers

struct AddTorrentView: View {
    @Environment(\.dismiss) private var dismiss

    enum AddMode: CaseIterable {
        case link
        case file

        var displayName: String {
            switch self {
            case .link: return OrbixStrings.miscAddModeLink
            case .file: return OrbixStrings.miscAddModeFile
            }
        }
    }

    @State private var mode: AddMode = .link
    @State private var linkText = ""
    @State private var selectedFileURL: URL?
    @State private var selectedFileData: Data?
    @State private var category = ""
    @State private var tags = ""
    @State private var savePath = ""
    @State private var isSubmitting = false
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var lastError = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    modePicker
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }

                if mode == .link {
                    linkInputSection
                } else {
                    fileInputSection
                }

                optionsSection
            }
            .formStyle(.grouped)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(OrbixStrings.navAddTorrent)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in
                    if let data = try? Data(contentsOf: url) {
                        withAnimation(.default) {
                            selectedFileURL = url
                            selectedFileData = data
                        }
                        AppHaptics.success()
                    }
                    showFilePicker = false
                } onDismiss: {
                    showFilePicker = false
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text(OrbixStrings.btnAdd)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    ConnectingDialog(message: OrbixStrings.msgAdding)
                }
            }
            .toast(isPresented: $showError, type: .error, message: lastError)
        }
    }

    private var modePicker: some View {
        Picker(OrbixStrings.sectionAddMethod, selection: $mode.animation(.default)) {
            ForEach(AddMode.allCases, id: \.self) { m in
                Text(m.displayName).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    private var linkInputSection: some View {
        Section(OrbixStrings.labelMagnetURL) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $linkText)
                    .font(.system(.subheadline, design: .monospaced))
                    .frame(minHeight: 160)

                if linkText.isEmpty {
                    Text(OrbixStrings.phMagnet)
                        .font(.subheadline)
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var fileInputSection: some View {
        Section(OrbixStrings.sectionTorrentFile) {
            if let url = selectedFileURL {
                HStack(spacing: 16) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                        Text(OrbixStrings.msgReadyToUpload)
                            .font(.caption)
                            .foregroundStyle(.green)
                    }

                    Spacer()

                    Button {
                        AppHaptics.light()
                        withAnimation(.default) {
                            selectedFileURL = nil
                            selectedFileData = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button {
                    pickFile()
                } label: {
                    Label(OrbixStrings.msgClickSelectTorrent, systemImage: "doc.badge.plus")
                }
            }
        }
    }

    private var optionsSection: some View {
        Section(OrbixStrings.sectionAdvancedOptions) {
            TextField(OrbixStrings.phCategoryPlaceholder, text: $category)
            TextField(OrbixStrings.phTagsPlaceholder, text: $tags)
            TextField(OrbixStrings.phSavePathPlaceholder, text: $savePath)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .link: return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return selectedFileData != nil
        }
    }

    private func submit() {
        AppHaptics.medium()
        isSubmitting = true

        Task {
            do {
                switch mode {
                case .link:
                    let urls = linkText
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    let _ = try await QBitApi.shared.addMagnet(
                        urls,
                        category: category.isEmpty ? nil : category,
                        tags: tags.isEmpty ? nil : tags,
                        savePath: savePath.isEmpty ? nil : savePath
                    )
                case .file:
                    if let data = selectedFileData, let url = selectedFileURL {
                        let _ = try await QBitApi.shared.addTorrent(
                            bytes: data,
                            filename: url.lastPathComponent,
                            category: category.isEmpty ? nil : category,
                            tags: tags.isEmpty ? nil : tags,
                            savePath: savePath.isEmpty ? nil : savePath
                        )
                    }
                }

                AppHaptics.success()

                await MainActor.run { dismiss() }
            } catch {
                AppHaptics.error()

                await MainActor.run {
                    isSubmitting = false
                    lastError = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func pickFile() {
        AppHaptics.light()
        showFilePicker = true
    }
}

#if DEBUG
#Preview {
    AddTorrentView()
}
#endif

import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let torrentType = UTType(filenameExtension: "torrent") ?? .data
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [torrentType], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onDismiss: onDismiss) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onDismiss: () -> Void

        init(onPick: @escaping (URL) -> Void, onDismiss: @escaping () -> Void) {
            self.onPick = onPick
            self.onDismiss = onDismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            DispatchQueue.main.async { self.onPick(url) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DispatchQueue.main.async { self.onDismiss() }
        }
    }
}


