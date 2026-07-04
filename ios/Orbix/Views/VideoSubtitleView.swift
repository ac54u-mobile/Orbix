import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct VideoSubtitleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var state: PipelineState = .idle
    @State private var showFilePicker = false
    @State private var phaseText = ""
    @State private var progress = 0
    @State private var total = 0
    @State private var elapsedSeconds = 0
    @State private var isTimerRunning = false
    @State private var srtContent: String?
    @State private var exportedFileURL: URL?
    @State private var showExportSheet = false
    @State private var errorMessage: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum PipelineState {
        case idle
        case extracting
        case recognizing
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
                case .extracting, .recognizing:
                    singleProgressView
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
            .navigationTitle(String(localized: "提取字幕", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
            }
        }
        .onReceive(timer) { _ in
            if isTimerRunning { elapsedSeconds += 1 }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]) { result in
            if case .success(let url) = result { processVideo(url) }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportedFileURL { ShareSheet(activityItems: [url]) }
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
                Text(String(localized: "选择视频 → 提取音频 → Whisper 识别 → DeepSeek 翻译 → 中文 .srt", comment: ""))
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

    private var singleProgressView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .tint(AppColors.accentPrimary)
            VStack(spacing: AppSpacing.sm) {
                Text(phaseText)
                    .font(.system(size: 18, weight: .semibold))
                Text(String(format: String(localized: "已运行 %d 秒", comment: ""), elapsedSeconds))
                    .descriptionSmall()
            }
            Spacer()
        }
    }

    private var translatingView: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            ProgressView(value: Double(progress), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accentPrimary))
                .padding(.horizontal, AppSpacing.xxl)
            VStack(spacing: AppSpacing.sm) {
                Text(String(localized: "翻译中…", comment: ""))
                    .font(.system(size: 18, weight: .semibold))
                Text("\(progress) / \(total) \(String(localized: "条", comment: ""))")
                    .descriptionSmall()
                Text(String(format: String(localized: "耗时 %d 秒", comment: ""), elapsedSeconds))
                    .caption()
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
                Text(String(format: String(localized: "共 %d 条字幕，耗时 %d 秒", comment: ""), total, elapsedSeconds))
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
            Button(String(localized: "重试", comment: "")) {
                state = .idle
                elapsedSeconds = 0
                isTimerRunning = false
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
        }
    }

    private func processVideo(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        elapsedSeconds = 0
        Task {
            do {
                await MainActor.run {
                    state = .extracting
                    phaseText = String(localized: "提取音频中…", comment: "")
                }

                let audioURL = try await SpeechTranscribeService.extractAudio(from: url)
                url.stopAccessingSecurityScopedResource()

                let segments = try await SpeechTranscribeService.shared.transcribe(audioURL: audioURL) { phase in
                    await MainActor.run {
                        switch phase {
                        case .extracting:
                            phaseText = String(localized: "提取音频中…", comment: "")
                        case .recognizing:
                            state = .recognizing
                            phaseText = String(localized: "Whisper 语音识别中…", comment: "")
                        case .translating:
                            break
                        }
                    }
                }
                try? FileManager.default.removeItem(at: audioURL)

                guard !segments.isEmpty else {
                    await MainActor.run { state = .error(String(localized: "未识别到语音内容", comment: "")) }
                    return
                }

                let srtEntries = segments.enumerated().map { idx, seg in
                    SRTEntry(index: idx + 1, start: seg.start, end: seg.end, text: seg.text)
                }

                await MainActor.run {
                    state = .translating
                    progress = 0
                    total = srtEntries.count
                }

                let translated = try await DeepSeekTranslateService.shared.translateSubtitles(
                    srtEntries, batchSize: 25, maxConcurrent: 5
                ) { current, totalCount in
                    await MainActor.run {
                        progress = current
                        total = totalCount
                    }
                }

                let srt = await SpeechTranscribeService.shared.segmentsToSRT(
                    segments,
                    with: translated.map { $0.text }
                )

                await MainActor.run {
                    srtContent = srt
                    state = .done
                    isTimerRunning = false
                    AppHaptics.success()
                }
            } catch {
                url.stopAccessingSecurityScopedResource()
                await MainActor.run {
                    state = .error(error.localizedDescription)
                    isTimerRunning = false
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
