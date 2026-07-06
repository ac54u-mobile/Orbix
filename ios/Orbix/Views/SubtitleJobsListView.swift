import SwiftUI

/// 字幕任务列表：展示服务器上全部任务的实时进度
struct SubtitleJobsListView: View {
    @State private var jobs: [SubtitleJob] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var exportingJobId: String?
    @State private var pendingDeleteJob: SubtitleJob?

    var body: some View {
        Group {
            if isLoading && jobs.isEmpty {
                ProgressView()
            } else if let errorMessage, jobs.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "加载失败", comment: ""), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if jobs.isEmpty {
                ContentUnavailableView {
                    Label(String(localized: "暂无字幕任务", comment: ""), systemImage: "captions.bubble")
                } description: {
                    Text(String(localized: "长按种子 → 提取字幕 发起任务", comment: ""))
                }
            } else {
                List {
                    ForEach(jobs) { job in
                        jobRow(job)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(String(localized: "字幕任务", comment: "Subtitle jobs"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshLoop() }
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .confirmationDialog(
            String(localized: "删除字幕任务", comment: "Delete subtitle job"),
            isPresented: Binding(
                get: { pendingDeleteJob != nil },
                set: { if !$0 { pendingDeleteJob = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let job = pendingDeleteJob {
                Button(String(localized: "仅删除任务记录", comment: ""), role: .destructive) {
                    deleteJob(job, deleteFile: false)
                }
                if job.stage == "done" {
                    Button(String(localized: "同时删除服务器上的字幕文件", comment: ""), role: .destructive) {
                        deleteJob(job, deleteFile: true)
                    }
                }
            }
        }
    }

    private func jobRow(_ job: SubtitleJob) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((job.videoPath as NSString).lastPathComponent)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            switch job.stage {
            case "done":
                HStack {
                    Label(job.message.isEmpty ? String(localized: "已完成", comment: "") : job.message,
                          systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Spacer()

                    Button {
                        exportSrt(job)
                    } label: {
                        if exportingJobId == job.id {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.body)
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(exportingJobId != nil)
                    .accessibilityLabel(String(localized: "导出字幕文件", comment: "Export subtitle"))
                }
            case "error":
                Label(job.error.isEmpty ? String(localized: "失败", comment: "") : job.error,
                      systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            case "paused":
                Label(String(localized: "已暂停，左滑可继续", comment: "Paused hint"),
                      systemImage: "pause.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            default:
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: job.overallProgress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text(job.stageTitle)
                        Spacer()
                        Text("\(Int(job.overallProgress * 100))%")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingDeleteJob = job
            } label: {
                Label(String(localized: "删除", comment: "Delete"), systemImage: "trash")
            }

            if job.isRunningOrQueued {
                Button {
                    pauseJob(job)
                } label: {
                    Label(String(localized: "暂停", comment: "Pause"), systemImage: "pause.fill")
                }
                .tint(.orange)
            } else if job.stage == "paused" {
                Button {
                    resumeJob(job)
                } label: {
                    Label(String(localized: "继续", comment: "Resume"), systemImage: "play.fill")
                }
                .tint(.green)
            }
        }
    }

    private func pauseJob(_ job: SubtitleJob) {
        AppHaptics.light()
        Task {
            try? await SubtitleServerApi.shared.pauseJob(id: job.id)
            await refreshOnce()
        }
    }

    private func resumeJob(_ job: SubtitleJob) {
        AppHaptics.light()
        Task {
            try? await SubtitleServerApi.shared.resumeJob(id: job.id)
            await refreshOnce()
        }
    }

    private func deleteJob(_ job: SubtitleJob, deleteFile: Bool) {
        AppHaptics.medium()
        Task {
            try? await SubtitleServerApi.shared.deleteJob(id: job.id, deleteFile: deleteFile)
            await refreshOnce()
        }
    }

    private func exportSrt(_ job: SubtitleJob) {
        exportingJobId = job.id
        AppHaptics.medium()
        Task {
            defer { Task { @MainActor in exportingJobId = nil } }
            if let url = try? await SubtitleExporter.export(job) {
                await MainActor.run {
                    exportURL = url
                    showExportSheet = true
                }
            } else {
                await MainActor.run { AppHaptics.error() }
            }
        }
    }

    private func refreshOnce() async {
        do {
            let list = try await SubtitleServerApi.shared.listJobs()
            await MainActor.run {
                jobs = list
                isLoading = false
                errorMessage = nil
                SubtitleBadgeStore.shared.sync(with: list)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                if jobs.isEmpty { errorMessage = error.localizedDescription }
            }
        }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            await refreshOnce()
            // 有进行中的任务时 3 秒刷新；空闲时放慢，便于暂停/继续后仍能更新
            let hasActive = jobs.contains { $0.isRunningOrQueued }
            try? await Task.sleep(nanoseconds: hasActive ? 3_000_000_000 : 10_000_000_000)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SubtitleJobsListView()
    }
}
#endif
