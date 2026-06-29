import SwiftUI

struct SwipeableTorrentCard: View {
    let torrent: TorrentInfo
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var navigateToDetail = false
    @State private var isDragging = false
    @State private var autoDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .trailing) {
            NavigationLink(destination: TorrentDetailView(hash: torrent.hash), isActive: $navigateToDetail) {
                EmptyView()
            }
            .hidden()

            if offset < 0 {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.danger)
                    .frame(width: 72)
                    .padding(.vertical, 4)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.trailing, 16)
                            .scaleEffect(offset < -50 ? 1.2 : 0.9)
                            .opacity(offset < -20 ? 1 : 0)
                            .animation(.easeOut(duration: 0.2), value: offset)
                    }
                    .onTapGesture {
                        autoDismissTask?.cancel()
                        guard !isDeleting else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            offset = -UIScreen.main.bounds.width
                            isDeleting = true
                            let impact = UIImpactFeedbackGenerator(style: .heavy)
                            impact.impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                onDelete()
                            }
                        }
                    }
            }

            Button {
                autoDismissTask?.cancel()
                guard !isDragging else { return }
                if offset < 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                } else {
                    navigateToDetail = true
                }
            } label: {
                TorrentRow(torrent: torrent)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppColors.card)
                    )
            }
            .buttonStyle(SolidCardButtonStyle())
            .offset(x: offset)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard !isDeleting else { return }
                    isDragging = true
                    if value.translation.width < 0 && abs(value.translation.width) > abs(value.translation.height) {
                        offset = value.translation.width * 0.8
                    }
                }
                .onEnded { value in
                    guard !isDeleting else { return }
                    guard abs(value.translation.width) > abs(value.translation.height) else {
                        offset = 0
                        isDragging = false
                        return
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if value.translation.width < -50 {
                            offset = -72
                        } else {
                            offset = 0
                        }
                    }
                    DispatchQueue.main.async {
                        isDragging = false
                    }
                }
        )
        .onChange(of: offset) { _, newValue in
            autoDismissTask?.cancel()
            guard newValue < 0, !isDeleting else { return }
            autoDismissTask = Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, !isDeleting else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = 0
                    }
                }
            }
        }
    }
}
