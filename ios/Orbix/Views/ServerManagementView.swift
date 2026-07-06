import SwiftUI

struct ServerManagementView: View {
    let onSelected: (ServerConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var servers: [ServerConfig] = []
    @State private var showLogin = false
    @State private var editingServer: ServerConfig? = nil

    var body: some View {
        NavigationStack {
            Group {
                if servers.isEmpty {
                    ContentUnavailableView {
                        Label(OrbixStrings.msgNoServer, systemImage: "server.rack")
                    } actions: {
                        Button(OrbixStrings.navAddServer) {
                            showLogin = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(servers) { server in
                            ServerRow(server: server)
                                .onTapGesture {
                                    onSelected(server)
                                    dismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        delete(server)
                                    } label: {
                                        Label(OrbixStrings.btnDelete, systemImage: "trash")
                                    }

                                    Button {
                                        showLoginWith(server)
                                    } label: {
                                        Label(OrbixStrings.btnEdit, systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        onSelected(server)
                                        dismiss()
                                    } label: {
                                        Label(OrbixStrings.btnConnect, systemImage: "link")
                                    }
                                    .tint(.green)
                                }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                Task { await QBitApi.shared.removeServer(servers[idx]) }
                            }
                            servers.remove(atOffsets: indexSet)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(OrbixStrings.navServerManagement)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(OrbixStrings.btnDone) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLoginWith(nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .onAppear { loadServers() }
        .sheet(isPresented: $showLogin) {
            LoginView(server: editingServer) { config in
                loadServers()
            }
        }
    }

    private func loadServers() {
        Task {
            let loaded = await QBitApi.shared.loadServers()
            await MainActor.run { servers = loaded }
        }
    }

    private func delete(_ server: ServerConfig) {
        Task { await QBitApi.shared.removeServer(server) }
        servers.removeAll { $0 == server }
    }

    private func showLoginWith(_ server: ServerConfig?) {
        editingServer = server
        showLogin = true
    }
}

#if DEBUG
#Preview {
    ServerManagementView(onSelected: { _ in })
}
#endif
