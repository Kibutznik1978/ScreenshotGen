import SwiftUI

struct ProjectListView: View {
    @Environment(ProjectStore.self) private var store
    @State private var renamingId: UUID?
    @State private var renameText: String = ""

    var body: some View {
        @Bindable var store = store

        List(selection: $store.selectedProjectId) {
            ForEach(store.projects) { project in
                projectRow(project)
                    .tag(project.id)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    Button {
                        store.createProject()
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 22)
                    }
                    .buttonStyle(.borderless)
                    .help("New project")
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .background(.bar)
        }
        .onChange(of: store.selectedProjectId) {
            store.selectedSlotIndex = nil
        }
    }

    @ViewBuilder
    private func projectRow(_ project: Project) -> some View {
        if renamingId == project.id {
            TextField("Project name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    store.renameProject(project.id, to: renameText)
                    renamingId = nil
                }
                .onExitCommand {
                    renamingId = nil
                }
        } else {
            Text(project.name)
                .contextMenu {
                    Button("Rename...") {
                        renameText = project.name
                        renamingId = project.id
                    }
                    Divider()
                    Button("Delete", role: .destructive) {
                        store.deleteProject(project.id)
                    }
                    .disabled(store.projects.count <= 1)
                }
        }
    }
}
