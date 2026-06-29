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
                Text(OrbixStrings.labelDownloadLimit).foregroundColor(AppColors.secondaryLabel)
                Spacer()
                TextField(OrbixStrings.phNoLimit, text: $dlLimitStr)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text("KB/s").font(.system(size: 12)).foregroundColor(AppColors.tertiaryLabel)
            }
            HStack {
                Text(OrbixStrings.labelUploadLimit).foregroundColor(AppColors.secondaryLabel)
                Spacer()
                TextField(OrbixStrings.phNoLimit, text: $ulLimitStr)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                Text("KB/s").font(.system(size: 12)).foregroundColor(AppColors.tertiaryLabel)
            }
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onApply()
            } label: {
                Text(OrbixStrings.btnApplyLimit)
                    .font(.system(size: 14, weight: .medium))
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.accent))
                    .foregroundColor(AppColors.label)
            }
        } header: {
            Text(sectionTitle)
        } footer: {
            Text(footerText)
        }
    }
}
