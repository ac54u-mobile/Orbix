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
            ZStack {
                AppColors.mainBg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        modePicker

                        Group {
                            if mode == .link {
                                linkInputSection
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            } else {
                                fileInputSection
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }
                        }

                        optionsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(OrbixStrings.navAddTorrent)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showFilePicker) {
                DocumentPickerView { url in
                    if let data = try? Data(contentsOf: url) {
                        withAnimation(AppMotion.mediumAnim()) {
                            selectedFileURL = url
                            selectedFileData = data
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
                                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        } else {
                            Text(OrbixStrings.btnAdd)
                                .font(.system(size: 16, weight: .bold))
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
        Picker(OrbixStrings.sectionAddMethod, selection: $mode.animation(AppMotion.mediumAnim())) {
            ForEach(AddMode.allCases, id: \.self) { m in
                Text(m.displayName).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }

    private var linkInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(OrbixStrings.labelMagnetURL)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $linkText)
                    .font(.system(size: 15, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 160)

                if linkText.isEmpty {
                    Text(OrbixStrings.phMagnet)
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.placeholder)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private var fileInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(OrbixStrings.sectionTorrentFile)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            if let url = selectedFileURL {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                            .lineLimit(1)
                        Text(OrbixStrings.msgReadyToUpload)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.success)
                    }

                    Spacer()

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        withAnimation(AppMotion.mediumAnim()) {
                            selectedFileURL = nil
                            selectedFileData = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AppColors.success.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                Button {
                    pickFile()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.accent)
                        Text(OrbixStrings.msgClickSelectTorrent)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.label)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.card.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                                )
                                .foregroundColor(AppColors.tertiaryLabel)
                        )
                )
                .contentShape(Rectangle())
            }
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(OrbixStrings.sectionAdvancedOptions)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.secondaryLabel)
                .textCase(.uppercase)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                IconTextFieldRow(icon: "square.grid.2x2.fill", placeholder: OrbixStrings.phCategoryPlaceholder, text: $category)
                Divider().padding(.leading, 44)
                IconTextFieldRow(icon: "tag.fill", placeholder: OrbixStrings.phTagsPlaceholder, text: $tags)
                Divider().padding(.leading, 44)
                IconTextFieldRow(icon: "folder.fill", placeholder: OrbixStrings.phSavePathPlaceholder, text: $savePath, disableAutocap: true)
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.card)
            )
        }
    }

    private var canSubmit: Bool {
        switch mode {
        case .link: return !linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .file: return selectedFileData != nil
        }
    }

    private func submit() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
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

                let successImpact = UINotificationFeedbackGenerator()
                successImpact.notificationOccurred(.success)

                await MainActor.run { dismiss() }
            } catch {
                let errorImpact = UINotificationFeedbackGenerator()
                errorImpact.notificationOccurred(.error)

                await MainActor.run {
                    isSubmitting = false
                    lastError = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func pickFile() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
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


