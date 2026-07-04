import SwiftUI

struct SpeedLimitSection: View {
    let sectionTitle: String
    let footerText: String
    @Binding var dlLimitStr: String
    @Binding var ulLimitStr: String
    let onApply: () -> Void

    var body: some View {
        Section {
            HStack {
                Text(OrbixStrings.labelDownloadLimit).foregroundColor(AppColors.textSecondary)
                Spacer()
                TextField(OrbixStrings.phNoLimit, text: $dlLimitStr)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text("KB/s").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            HStack {
                Text(OrbixStrings.labelUploadLimit).foregroundColor(AppColors.textSecondary)
                Spacer()
                TextField(OrbixStrings.phNoLimit, text: $ulLimitStr)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text("KB/s").font(.system(size: 12)).foregroundColor(AppColors.textTertiary)
            }
            Button {
                AppHaptics.medium()
                onApply()
            } label: {
                Text(OrbixStrings.btnApplyLimit)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: AppRadius.sm).fill(AppColors.accentPrimary))
                    .foregroundColor(AppColors.textPrimary)
            }
        } header: {
            Text(sectionTitle)
        } footer: {
            Text(footerText)
        }
    }
}
