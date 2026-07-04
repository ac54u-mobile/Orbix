import SwiftUI

struct SRTFilePicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let srtType = UTType(filenameExtension: "srt") ?? .plainText
        let assType = UTType(filenameExtension: "ass") ?? .plainText
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [srtType, assType, .plainText], asCopy: true)
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

struct SubtitleTranslateView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var state: TranslateState = .idle
    @State private var progress: Int = 0
    @State private var total: Int = 0
    @State private var translatedEntries: [SRTEntry] = []
    @State private var errorMessage: String?
    @State private var showFilePicker = false
    @State private var showExportSheet = false
    @State private var exportedFileURL: URL?

    enum TranslateState {
        case idle
        case translating
        case done
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                switch state {
                case .idle:
                    idleView
                case .translating:
                    translatingView
                case .done:
                    doneView
                case .error(let msg):
                    errorView(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.gridBackgroundGradient)
            .navigationTitle(String(localized: "字幕翻译", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.plainText, UTType(filenameExtension: "srt") ?? .plainText, UTType(filenameExtension: "ass") ?? .plainText]) { result in
            switch result {
            case .success(let url):
                startTranslation(url: url)
            case .failure:
                break
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportedFileURL {
                ShareSheet(activityItems: [url])
            }
        }
    }

    private var idleView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "translate")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(AppColors.accentPrimary)

            VStack(spacing: AppSpacing.sm) {
                Text(String(localized: "导入日文字幕文件", comment: ""))
                    .font(.system(size: 22, weight: .semibold))
                Text(String(localized: "支持 .srt / .ass 格式，将逐条翻译为简体中文", comment: ""))
                    .descriptionSmall()
                    .multilineTextAlignment(.center)
            }

            Button {
                AppHaptics.medium()
                showFilePicker = true
            } label: {
                Label(String(localized: "选择字幕文件", comment: ""), systemImage: "doc.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.accentPrimary)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    private var translatingView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            ProgressView(value: Double(progress), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accentPrimary))
                .padding(.horizontal, AppSpacing.xl)

            VStack(spacing: AppSpacing.sm) {
                Text(String(localized: "翻译中…", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                Text("\(progress) / \(total) \(String(localized: "条", comment: ""))")
                    .descriptionSmall()
            }

            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(AppColors.success)

            VStack(spacing: AppSpacing.sm) {
                Text(String(localized: "翻译完成", comment: ""))
                    .font(.system(size: 22, weight: .semibold))
                Text(String(format: String(localized: "共翻译 %d 条字幕", comment: ""), total))
                    .descriptionSmall()
            }

            Button {
                AppHaptics.medium()
                exportTranslatedSRT()
            } label: {
                Label(String(localized: "导出为 .srt 文件", comment: ""), systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                            .fill(AppColors.success)
                    )
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.danger)

            Text(msg)
                .descriptionSmall(AppColors.danger)
                .multilineTextAlignment(.center)

            Button(String(localized: "重试", comment: "")) {
                state = .idle
            }
            .buttonStyle(ScaleButtonStyle())

            Spacer()
        }
    }

    private func startTranslation(url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let entries = SRTParser.parse(content)
            guard !entries.isEmpty else {
                state = .error(String(localized: "未能解析字幕文件，请确认文件格式正确", comment: ""))
                return
            }

            total = entries.count
            progress = 0
            state = .translating
            AppHaptics.medium()

            Task {
                do {
                    let result = try await DeepSeekTranslateService.shared.translateSubtitles(entries) { current, totalCount in
                        await MainActor.run {
                            progress = current
                            total = totalCount
                        }
                    }
                    await MainActor.run {
                        translatedEntries = result
                        state = .done
                        AppHaptics.success()
                    }
                } catch {
                    await MainActor.run {
                        state = .error(error.localizedDescription)
                        AppHaptics.error()
                    }
                }
            }
        } catch {
            state = .error(String(localized: "无法读取文件内容", comment: ""))
        }
    }

    private func exportTranslatedSRT() {
        let srt = SRTParser.generate(from: translatedEntries)
        let fileName = "translated.srt"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try srt.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFileURL = fileURL
            showExportSheet = true
        } catch {}
    }
}

#if DEBUG
#Preview {
    SubtitleTranslateView()
}
#endif
