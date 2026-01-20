import SwiftUI

@available(macOS 14.0, *)
struct RuleDetailView: View {
    @Bindable var rule: Rule

    var body: some View {
        Form {
            TextField("Host", text: $rule.host)
            TextField("Path Prefix", text: $rule.pathPrefix)
            TextField("Upstream", text: $rule.upstream)
            Toggle("Enabled", isOn: $rule.enabled)
            TextEditor(text: Binding(
                get: { rule.note ?? "" },
                set: { rule.note = $0 }
            ))
                .frame(minHeight: 120)
        }
        .padding()
    }
}
