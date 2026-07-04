import SwiftUI

struct HairlineDivider: View {
    var leadingPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(AppColors.hairlineDivider)
            .frame(height: 0.5)
            .padding(.leading, leadingPadding)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        HairlineDivider()
        HairlineDivider(leadingPadding: 44)
    }
}
#endif
