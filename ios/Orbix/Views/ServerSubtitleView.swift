import SwiftUI

/// 长按种子 → 提取字幕：调用服务器字幕服务
/// （ffmpeg 提取音频 → Whisper 识别 → DeepSeek 翻译 → 视频旁生成 .zh.srt，Infuse 可直接加载）
struct ServerSubtitleView: View {
    let torrent: TorrentInfo
    @Environment(\.dismiss) private var dismiss

    private static let videoExtensions: Set<String> = [
        "mkv", "mp4", "avi", "mov", "m4v", "ts", "wmv", "flv", "webm"
    ]

    @State private var isConfigured = SubtitleServiceConfig.load().isConfigured
    @State private var isLoadingFiles = true
    @State private var videoFiles: [TorrentFile] = []
    @State private var startingPath: String?
    @State private var job: SubtitleJob?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if !isConfigured {
                    notConfiguredView
                } else if let job {
                    jobStatusView(job)
                } else if isLoadingFiles {
                    ProgressView(String(localized: "读取文件列表…", comment: "Loading files"))
                } else if videoFiles.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "没有视频文件", comment: "No video files"), systemImage: "film")
                    } description: {
                        Text(String(localized: "该种子内未找到可处理的视频", comment: "No video description"))
                    }
                } else {
                    fileList
                }
            }
            .navigationTitle(String(localized: "提取字幕", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnClose) { dismiss() }
                }
            }
        }
        .task { await prepare() }
        .task(id: job?.id) { await pollJob() }
    }

    // MARK: - Views

    private var notConfiguredView: some View {
        ContentUnavailableView {
            Label(String(localized: "未配置字幕服务", comment: ""), systemImage: "captions.bubble")
        } description: {
            Text(String(localized: "请到 设置 → 字幕服务 填写服务器地址和 API Key", comment: ""))
        }
    }

    private var fileList: some View {
        List {
            Section {
                ForEach(videoFiles) { file in
                    Button {
                        startJob(for: file)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "film")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 3) {
                                Text((file.name as NSString).lastPathComponent)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                Text(formatBytes(file.size))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if startingPath == fullPath(file) {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .disabled(startingPath != nil)
                }
            } header: {
                Text(String(localized: "选择要生成中文字幕的视频", comment: ""))
            } footer: {
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text(String(localized: "字幕生成在服务器上进行，完成后与视频同目录生成 .zh.srt，Infuse 播放时自动识别", comment: ""))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func jobStatusView(_ job: SubtitleJob) -> some View {
        switch job.stage {
        case "done":
            doneView(job)
        case "error":
            failedView(job)
        default:
            runningView(job)
        }
    }

    private func runningView(_ job: SubtitleJob) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: job.overallProgress)
                .progressViewStyle(.linear)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text(job.stageTitle)
                    .font(.headline)
                Text("\(Int(job.overallProgress * 100))%")
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                Text((job.videoPath as NSString).lastPathComponent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 32)
            }

            stageSteps(current: job.stage)

            Spacer()

            Text(String(localized: "可以关闭此页面，任务在服务器上继续运行，重新打开可查看进度", comment: ""))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func stageSteps(current: String) -> some View {
        let steps: [(id: String, title: String, icon: String)] = [
            ("extract", String(localized: "提取音频", comment: ""), "waveform"),
            ("transcribe", String(localized: "语音识别", comment: ""), "text.bubble"),
            ("translate", String(localized: "翻译", comment: ""), "character.bubble"),
            ("write", String(localized: "生成字幕", comment: ""), "captions.bubble"),
        ]
        let currentIndex = steps.firstIndex { $0.id == current } ?? -1

        return HStack(spacing: 18) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                VStack(spacing: 6) {
                    Image(systemName: index < currentIndex ? "checkmark.circle.fill" : step.icon)
                        .font(.body)
                        .foregroundStyle(index < currentIndex ? .green : (index == currentIndex ? .blue : Color(.tertiaryLabel)))
                    Text(step.title)
                        .font(.caption2)
                        .foregroundStyle(index == currentIndex ? .primary : .secondary)
                }
            }
        }
    }

    private func doneView(_ job: SubtitleJob) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            VStack(spacing: 8) {
                Text(String(localized: "字幕生成完成", comment: ""))
                    .font(.title2.weight(.semibold))
                if !job.message.isEmpty {
                    Text(job.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text((job.srtPath as NSString).lastPathComponent)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 32)
            }
            Text(String(localized: "字幕已保存在视频同目录，用 Infuse 播放该视频即可自动加载中文字幕", comment: ""))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func failedView(_ job: SubtitleJob) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(job.error.isEmpty ? String(localized: "处理失败", comment: "") : job.error)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button(String(localized: "重试", comment: "")) {
                self.job = nil
                self.errorMessage = nil
            }
            .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Data

    private func fullPath(_ file: TorrentFile) -> String {
        let base = torrent.savePath.hasSuffix("/") ? String(torrent.savePath.dropLast()) : torrent.savePath
        return "\(base)/\(file.name)"
    }

    private func prepare() async {
        isConfigured = SubtitleServiceConfig.load().isConfigured
        guard isConfigured else { return }

        let files = (try? await QBitApi.shared.getTorrentFiles(torrent.hash)) ?? []
        let videos = files.filter {
            Self.videoExtensions.contains(($0.name as NSString).pathExtension.lowercased())
        }
        await MainActor.run {
            videoFiles = videos.sorted { $0.size > $1.size }
            isLoadingFiles = false
        }

        // 若某个视频已有任务（进行中或已完成），直接续接展示
        for file in videoFiles {
            if let existing = try? await SubtitleServerApi.shared.findJob(videoPath: fullPath(file)) {
                await MainActor.run { job = existing }
                return
            }
        }
    }

    private func startJob(for file: TorrentFile) {
        let path = fullPath(file)
        startingPath = path
        errorMessage = nil
        AppHaptics.medium()
        Task {
            do {
                let created = try await SubtitleServerApi.shared.createJob(videoPath: path)
                await MainActor.run {
                    startingPath = nil
                    job = created
                    AppHaptics.success()
                }
            } catch {
                await MainActor.run {
                    startingPath = nil
                    errorMessage = error.localizedDescription
                    AppHaptics.error()
                }
            }
        }
    }

    private func pollJob() async {
        guard let current = job, !current.isFinished else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let id = job?.id else { return }
            if let updated = try? await SubtitleServerApi.shared.getJob(id: id) {
                await MainActor.run { job = updated }
                if updated.isFinished {
                    await MainActor.run {
                        updated.stage == "done" ? AppHaptics.success() : AppHaptics.error()
                    }
                    return
                }
            }
        }
    }
}
