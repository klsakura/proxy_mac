import SwiftUI

@available(macOS 14.0, *)
struct RuleDetailView: View {
    @Bindable var rule: Rule

    var body: some View {
        Form {
            TextField("Host", text: $rule.host)
            TextField("Path Prefix", text: $rule.pathPrefix)
            TextField("Upstream", text: $rule.upstream)
            TextField("Priority", value: $rule.priority, formatter: numberFormatter)
            Toggle("Enabled", isOn: $rule.enabled)
            TextEditor(text: Binding(
                get: { rule.note ?? "" },
                set: { rule.note = $0 }
            ))
                .frame(minHeight: 120)
        }
        .padding()
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        return formatter
    }
}
