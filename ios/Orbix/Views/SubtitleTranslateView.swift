import SwiftUI
import UniformTypeIdentifiers

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
            VStack(spacing: 24) {
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
            .background(Color(.systemGroupedBackground))
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
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "translate")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text(String(localized: "导入日文字幕文件", comment: ""))
                    .font(.title2.weight(.semibold))
                Text(String(localized: "支持 .srt / .ass 格式，将逐条翻译为简体中文", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                AppHaptics.medium()
                showFilePicker = true
            } label: {
                Label(String(localized: "选择字幕文件", comment: ""), systemImage: "doc.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding(24)
    }

    private var translatingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: Double(progress), total: Double(total))
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Text(String(localized: "翻译中…", comment: ""))
                    .font(.headline)
                Text("\(progress) / \(total) \(String(localized: "条", comment: ""))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var doneView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text(String(localized: "翻译完成", comment: ""))
                    .font(.title2.weight(.semibold))
                Text(String(format: String(localized: "共翻译 %d 条字幕", comment: ""), total))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button {
                AppHaptics.medium()
                exportTranslatedSRT()
            } label: {
                Label(String(localized: "导出为 .srt 文件", comment: ""), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)

            Spacer()
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text(msg)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)

            Button(String(localized: "重试", comment: "")) {
                state = .idle
            }
            .buttonStyle(.bordered)

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
