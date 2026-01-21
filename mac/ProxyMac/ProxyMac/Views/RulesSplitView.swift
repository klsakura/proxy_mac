import SwiftData
import SwiftUI

@available(macOS 14.0, *)
struct RulesSplitView: View {
    @AppStorage("rules.sortMode") private var sortMode = "auto"
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var settings: ProxySettings
    @EnvironmentObject private var controller: ProxyCoreController
    @Query(sort: \Rule.order) private var rules: [Rule]
    @State private var selectionID: PersistentIdentifier?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportData = Data()
    @State private var showingSettings = false

    private var displayRules: [Rule] {
        sortMode == "manual" ? RuleSorting.manualSort(rules) : RuleSorting.autoSort(rules)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectionID) {
                ForEach(displayRules) { rule in
                    RuleRowView(rule: rule)
                        .tag(rule.persistentModelID)
                }
                .onMove { indices, newOffset in
                    guard sortMode == "manual" else { return }
                    var reordered = displayRules
                    reordered.move(fromOffsets: indices, toOffset: newOffset)
                    _ = RuleSorting.reassignOrder(reordered)
                    try? context.save()
                }
            }
        } detail: {
            if let rule = selectedRule {
                RuleDetailView(rule: rule)
            } else {
                Text("Select a rule")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(ProxyCoreActions.startStopTitle(for: controller.state)) {
                    ProxyCoreActions.toggle(controller: controller, settings: settings)
                }
                Button("Settings") { showingSettings = true }
                Divider()
                Button("Add") { addRule() }
                Button("Delete") { deleteRule() }
                Divider()
                Button("Import") { showingImporter = true }
                Button("Export") { exportRules() }
                Divider()
                Picker("Sort Mode", selection: $sortMode) {
                    Text("Auto").tag("auto")
                    Text("Manual").tag("manual")
                }
                .pickerStyle(.segmented)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                importRules(from: url)
            case .failure:
                break
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: JSONFileDocument(data: exportData),
            contentType: .json,
            defaultFilename: "proxy-rules"
        ) { _ in }
        .sheet(isPresented: $showingSettings) {
            ProxySettingsView(settings: settings)
        }
        .onAppear {
            controller.updateControlAddress(settings.controlAddress)
            applyConfig()
        }
        .onChange(of: rulesSignature) { _ in
            applyConfig()
        }
        .onChange(of: settings.snapshot) { _ in
            controller.updateControlAddress(settings.controlAddress)
            applyConfig()
        }
    }

    private func addRule() {
        let nextOrder = (rules.map { $0.order }.max() ?? -1) + 1
        let rule = Rule(host: "", pathPrefix: "/", upstream: "", order: nextOrder)
        context.insert(rule)
        selectionID = rule.persistentModelID
        try? context.save()
    }

    private func deleteRule() {
        guard let rule = selectedRule else { return }
        context.delete(rule)
        selectionID = nil
        try? context.save()
    }

    private func exportRules() {
        do {
            let data = try RuleJSON.export(rules)
            exportData = data
            showingExporter = true
        } catch {
            return
        }
    }

    private func importRules(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let imported = try RuleJSON.importRules(data)
            imported.forEach { context.insert($0) }
            try? context.save()
            if selectionID == nil {
                selectionID = imported.first?.persistentModelID
            }
        } catch {
            return
        }
    }

    private var selectedRule: Rule? {
        guard let selectionID else { return nil }
        return rules.first { $0.persistentModelID == selectionID }
    }

    private var rulesSignature: String {
        rules.map {
            "\($0.host)|\($0.pathPrefix)|\($0.upstream)|\($0.enabled)|\($0.order)|\($0.priority)|\($0.note ?? "")"
        }
        .joined(separator: ";")
    }

    private func applyConfig() {
        Task { await ProxyCoreActions.applyConfig(rules: rules, settings: settings, controller: controller) }
    }
}
