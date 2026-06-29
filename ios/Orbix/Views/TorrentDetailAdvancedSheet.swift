import SwiftUI

struct TorrentDetailAdvancedSheet: View {
    let hash: String
    @Binding var newLocation: String
    @Binding var newName: String
    @Binding var dlLimitStr: String
    @Binding var ulLimitStr: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("修改保存路径")
                            .font(.system(size: 13))
                            .foregroundColor(AppColors.secondaryLabel)
                        TextField("输入新的保存路径", text: $newLocation)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(AppColors.label)
                    }
                    .padding(.vertical, 4)

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            try? await QBitApi.shared.setTorrentLocation(hash, location: newLocation)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Text("应用路径")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newLocation.isEmpty ? AppColors.elevated : AppColors.accent)
                            )
                            .foregroundColor(newLocation.isEmpty ? AppColors.secondaryLabel : .white)
                    }
                    .disabled(newLocation.isEmpty)
                } header: {
                    Text("位置")
                }

                Section {
                    TextField("重命名", text: $newName)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.label)

                    Button {
                        Task {
                            try? await QBitApi.shared.renameTorrent(hash, name: newName)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            dismiss()
                        }
                    } label: {
                        Text("应用名称")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(newName.isEmpty ? AppColors.elevated : AppColors.accent)
                            )
                            .foregroundColor(newName.isEmpty ? AppColors.secondaryLabel : .white)
                    }
                    .disabled(newName.isEmpty)
                } header: {
                    Text("重命名")
                }

                Section {
                    HStack {
                        Text("下载限速")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("不限速", text: $dlLimitStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                        Text("KB/s")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }

                    HStack {
                        Text("上传限速")
                            .foregroundColor(AppColors.secondaryLabel)
                        Spacer()
                        TextField("不限速", text: $ulLimitStr)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppColors.label)
                        Text("KB/s")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.tertiaryLabel)
                    }

                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            let dl = (Int64(dlLimitStr) ?? -1)
                            let ul = (Int64(ulLimitStr) ?? -1)
                            if dl > 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: dl * 1024) }
                            else if dl == 0 { try? await QBitApi.shared.setTorrentDownloadLimit(hash, limit: 0) }
                            if ul > 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: ul * 1024) }
                            else if ul == 0 { try? await QBitApi.shared.setTorrentUploadLimit(hash, limit: 0) }
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        Text("应用限速")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(AppColors.accent)
                            )
                            .foregroundColor(.white)
                    }
                } header: {
                    Text("速度限制")
                } footer: {
                    Text("留空或填 0 表示不限速")
                }

                Section {
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        Task {
                            try? await QBitApi.shared.toggleSequentialDownload(hash)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    } label: {
                        HStack {
                            Label("切换顺序下载", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                                .foregroundColor(AppColors.label)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(AppColors.tertiaryLabel)
                        }
                    }
                } header: {
                    Text("下载模式")
                } footer: {
                    Text("按文件顺序下载，适合预览媒体文件")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppColors.mainBg)
            .navigationTitle("高级控制")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}
