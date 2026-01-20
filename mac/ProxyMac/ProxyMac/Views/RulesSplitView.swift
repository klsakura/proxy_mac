import SwiftData
import SwiftUI

@available(macOS 14.0, *)
struct RulesSplitView: View {
    @AppStorage("rules.sortMode") private var sortMode = "auto"
    @Environment(\.modelContext) private var context
    @Query(sort: \Rule.order) private var rules: [Rule]
    @State private var selection: Rule?

    private var displayRules: [Rule] {
        sortMode == "manual" ? RuleSorting.manualSort(rules) : RuleSorting.autoSort(rules)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(displayRules) { rule in
                    RuleRowView(rule: rule)
                        .tag(rule)
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
            if let rule = selection {
                RuleDetailView(rule: rule)
            } else {
                Text("Select a rule")
                    .foregroundStyle(.secondary)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button("Add") { addRule() }
                Button("Delete") { deleteRule() }
                Divider()
                Picker("Sort Mode", selection: $sortMode) {
                    Text("Auto").tag("auto")
                    Text("Manual").tag("manual")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func addRule() {
        let nextOrder = (rules.map { $0.order }.max() ?? -1) + 1
        let rule = Rule(host: "", pathPrefix: "/", upstream: "", order: nextOrder)
        context.insert(rule)
        selection = rule
        try? context.save()
    }

    private func deleteRule() {
        guard let selection else { return }
        context.delete(selection)
        self.selection = nil
        try? context.save()
    }
}
