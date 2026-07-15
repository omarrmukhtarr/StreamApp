import SwiftUI

struct AddPlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model = AddPlaylistViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Source Type", selection: $model.kind) {
                        ForEach(PlaylistKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section("Details") {
                    TextField("Name (e.g. My IPTV)", text: $model.name)
                        .textInputAutocapitalization(.words)

                    TextField(
                        model.kind == .m3u
                            ? "Playlist URL (http://…/playlist.m3u)"
                            : "Server URL (http://host:port)",
                        text: $model.urlString
                    )
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    if model.kind == .xtream {
                        TextField("Username", text: $model.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $model.password)
                    } else {
                        TextField("EPG URL (optional, XMLTV)", text: $model.epgURLString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                if let error = model.errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    Button {
                        Task {
                            if await model.validateAndSave(context: modelContext) {
                                dismiss()
                            }
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isValidating {
                                ProgressView()
                                    .padding(.trailing, 6)
                                Text("Connecting…")
                            } else {
                                Label("Connect & Save", systemImage: "checkmark.circle.fill")
                            }
                            Spacer()
                        }
                        .font(.headline)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.brandPrimary)
                    .disabled(!model.canSubmit || model.isValidating)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Add Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .interactiveDismissDisabled(model.isValidating)
        }
    }
}
