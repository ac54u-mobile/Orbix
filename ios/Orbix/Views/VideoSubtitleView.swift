import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct VideoSubtitleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state: PipelineState = .idle
    @State private var showFilePicker = false
    @State private var progressText = ""
    @State private var srtContent: String?
    @State private var exportedFileURL: URL?
    @State private var showExportSheet = false
    @State private var errorMessage: String?

    enum PipelineState {
        case idle
        case extracting
        case uploading
        case processing
        case done
        case error(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.xl) {
                switch state {
                case .idle:
                    idleView
                case .extracting, .uploading, .processing:
                    processingView
                case .done:
                    doneView
                case .error(let msg):
                    errorView(msg)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.gridBackgroundGradient)
            .navigationTitle(String(localized: "提取字幕", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]) { result in
            switch result {
            case .success(let url):
                processVideo(url)
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
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(AppColors.accentPrimary)
            VStack(spacing: AppSpacing.sm) {
                Text(String(localized: "语音转字幕", comment: ""))
                    .font(.system(size: 22, weight: .semibold))
                Text(String(localized: "选择视频文件，服务器将自动提取语音 → 识别 → 翻译为中文 .srt", comment: ""))
                    .descriptionSmall()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            Button {
                AppHaptics.medium()
                showFilePicker = true
            } label: {
                Label(String(localized: "选择视频文件", comment: ""), systemImage: "film")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous).fill(AppColors.accentPrimary))
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
        }
        .padding(AppSpacing.xl)
    }

    private var processingView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.accentPrimary)
            VStack(spacing: AppSpacing.sm) {
                Text(progressText)
                    .font(.system(size: 18, weight: .semibold))
                Text(String(localized: "请耐心等待，2小时视频约需5-10分钟", comment: ""))
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
                Text(String(localized: "字幕生成完成", comment: ""))
                    .font(.system(size: 22, weight: .semibold))
                Text(String(localized: "已自动识别语音并翻译为中文", comment: ""))
                    .descriptionSmall()
            }
            Button {
                AppHaptics.medium()
                exportSRT()
            } label: {
                Label(String(localized: "导出为 .srt 文件", comment: ""), systemImage: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.vertical, AppSpacing.md)
                    .background(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous).fill(AppColors.success))
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
            Button(String(localized: "重试", comment: "")) { state = .idle }
                .buttonStyle(ScaleButtonStyle())
            Spacer()
        }
    }

    private func processVideo(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        Task {
            do {
                await MainActor.run {
                    state = .extracting
                    progressText = String(localized: "提取音频中…", comment: "")
                }

                let audioURL = try await SpeechTranscribeService.extractAudio(from: url)
                url.stopAccessingSecurityScopedResource()

                await MainActor.run {
                    state = .processing
                    progressText = String(localized: "服务器识别 + 翻译中…", comment: "")
                }

                let srt = try await SpeechTranscribeService.shared.transcribeAndTranslate(audioURL: audioURL)
                try? FileManager.default.removeItem(at: audioURL)

                await MainActor.run {
                    srtContent = srt
                    state = .done
                    AppHaptics.success()
                }
            } catch {
                url.stopAccessingSecurityScopedResource()
                await MainActor.run {
                    state = .error(error.localizedDescription)
                    AppHaptics.error()
                }
            }
        }
    }

    private func exportSRT() {
        guard let srt = srtContent else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("subtitles.srt")
        do {
            try srt.write(to: url, atomically: true, encoding: .utf8)
            exportedFileURL = url
            showExportSheet = true
        } catch {}
    }
}

#if DEBUG
#Preview {
    VideoSubtitleView()
}
#endif
