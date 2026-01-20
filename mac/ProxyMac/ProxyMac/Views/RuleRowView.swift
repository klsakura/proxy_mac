import SwiftUI

@available(macOS 14.0, *)
struct RuleRowView: View {
    @Bindable var rule: Rule

    var body: some View {
        HStack {
            Toggle("", isOn: $rule.enabled)
                .labelsHidden()
            VStack(alignment: .leading) {
                Text(rule.host.isEmpty ? "(host)" : rule.host)
                Text(rule.pathPrefix)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(rule.upstream.isEmpty ? "(upstream)" : rule.upstream)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(rule.enabled ? 1.0 : 0.5)
    }
}
