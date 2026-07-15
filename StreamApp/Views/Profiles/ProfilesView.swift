import SwiftData
import SwiftUI

/// Reusable circular profile avatar.
struct ProfileAvatar: View {
    let profile: ProfileEntity
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: profile.symbol)
            .font(.system(size: size * 0.42))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [profile.color, profile.color.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
            .overlay {
                if profile.isKids {
                    Image(systemName: "figure.child")
                        .font(.system(size: size * 0.2))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(.black.opacity(0.35), in: .circle)
                        .offset(x: size * 0.32, y: size * 0.32)
                }
            }
    }
}

/// "Who's watching?" — switch, add, edit and delete profiles.
struct ProfilesView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProfileEntity.createdAt) private var allProfiles: [ProfileEntity]

    @State private var editing: ProfileEntity?
    @State private var showAdd = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(allProfiles) { profile in
                        profileCell(profile)
                    }
                    addCell
                }
                .padding()
            }
            .appBackground()
            .navigationTitle("Who's Watching?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddEditProfileView()
            }
            .sheet(item: $editing) { profile in
                AddEditProfileView(profile: profile)
            }
        }
    }

    private func profileCell(_ profile: ProfileEntity) -> some View {
        let isCurrent = profile.id == profiles.currentID
        return VStack(spacing: 10) {
            ProfileAvatar(profile: profile, size: 88)
                .overlay {
                    if isCurrent {
                        Circle().strokeBorder(LinearGradient.brand, lineWidth: 3)
                    }
                }
            Text(profile.name)
                .font(.subheadline.weight(isCurrent ? .bold : .medium))
                .lineLimit(1)
        }
        .contentShape(.rect)
        .onTapGesture {
            profiles.select(profile)
            dismiss()
        }
        .contextMenu {
            Button { editing = profile } label: { Label("Edit", systemImage: "pencil") }
            if allProfiles.count > 1 {
                Button(role: .destructive) { delete(profile) } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private var addCell: some View {
        Button {
            showAdd = true
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 34))
                    .foregroundStyle(.secondary)
                    .frame(width: 88, height: 88)
                    .glassEffect(.regular, in: .circle)
                Text("Add Profile")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func delete(_ profile: ProfileEntity) {
        // Reassign the active profile if we're deleting the current one.
        if profile.id == profiles.currentID,
           let other = allProfiles.first(where: { $0.id != profile.id }) {
            profiles.select(other)
        }
        context.delete(profile)
        try? context.save()
    }
}

/// Create or edit a profile: name, icon, color and a kids flag.
struct AddEditProfileView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let existing: ProfileEntity?
    @State private var name: String
    @State private var symbol: String
    @State private var colorIndex: Int
    @State private var isKids: Bool

    private let symbols = ["person.fill", "person.crop.circle", "face.smiling", "gamecontroller.fill",
                           "star.fill", "heart.fill", "bolt.fill", "leaf.fill", "figure.child", "pawprint.fill"]
    private let gridColumns = [GridItem(.adaptive(minimum: 54), spacing: 12)]

    init(profile: ProfileEntity? = nil) {
        self.existing = profile
        _name = State(initialValue: profile?.name ?? "")
        _symbol = State(initialValue: profile?.symbol ?? "person.fill")
        _colorIndex = State(initialValue: profile?.colorIndex ?? 0)
        _isKids = State(initialValue: profile?.isKids ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        previewAvatar
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Name") {
                    TextField("Profile name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Icon") {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(symbols, id: \.self) { option in
                            Image(systemName: option)
                                .font(.title2)
                                .frame(width: 50, height: 50)
                                .foregroundStyle(symbol == option ? .white : .primary)
                                .background(
                                    symbol == option ? AnyShapeStyle(ProfileEntity.palette[colorIndex]) : AnyShapeStyle(.clear),
                                    in: .circle
                                )
                                .glassEffect(.regular, in: .circle)
                                .onTapGesture { symbol = option }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(ProfileEntity.palette.indices, id: \.self) { index in
                            Circle()
                                .fill(ProfileEntity.palette[index])
                                .frame(width: 34, height: 34)
                                .overlay {
                                    if colorIndex == index {
                                        Circle().strokeBorder(.white, lineWidth: 2)
                                    }
                                }
                                .onTapGesture { colorIndex = index }
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    Toggle("Kids Profile", isOn: $isKids)
                } footer: {
                    Text("Kids profiles get their own favorites, downloads and watch history.")
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle(existing == nil ? "New Profile" : "Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var previewAvatar: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .frame(width: 100, height: 100)
                .background(ProfileEntity.palette[colorIndex], in: .circle)
            Text(name.isEmpty ? "Preview" : name)
                .font(.headline)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing {
            existing.name = trimmed
            existing.symbol = symbol
            existing.colorIndex = colorIndex
            existing.isKids = isKids
        } else {
            let profile = ProfileEntity(name: trimmed, symbol: symbol, colorIndex: colorIndex, isKids: isKids)
            context.insert(profile)
            try? context.save()
            profiles.select(profile)
        }
        try? context.save()
        dismiss()
    }
}
