import SwiftUI

/// 字幕任务列表：展示服务器上全部任务的实时进度
struct SubtitleJobsListView: View {
    @State private var jobs: [SubtitleJob] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

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
    }

    private func jobRow(_ job: SubtitleJob) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text((job.videoPath as NSString).lastPathComponent)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)

            switch job.stage {
            case "done":
                Label(job.message.isEmpty ? String(localized: "已完成", comment: "") : job.message,
                      systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            case "error":
                Label(job.error.isEmpty ? String(localized: "失败", comment: "") : job.error,
                      systemImage: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
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
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            do {
                let list = try await SubtitleServerApi.shared.listJobs()
                await MainActor.run {
                    jobs = list
                    isLoading = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if jobs.isEmpty { errorMessage = error.localizedDescription }
                }
            }
            // 有进行中的任务时 3 秒刷新，否则不再轮询
            guard jobs.contains(where: { !$0.isFinished }) else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
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
