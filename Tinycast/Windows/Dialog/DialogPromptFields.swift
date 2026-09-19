import SwiftUI

/// A one-line dialog field; reference semantics are what let the caller read it back.
@MainActor
@Observable
final class DialogPromptState {
    var text: String
    let placeholder: String

    init(text: String = "", placeholder: String = "") {
        self.text = text
        self.placeholder = placeholder
    }

    var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmed.isEmpty }
}

struct DialogPromptFields: View {
    @Environment(\.metrics) private var metrics
    @Bindable var state: DialogPromptState
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $state.text, prompt: Text(state.placeholder))
            .focused($focused)
            .dialogTextField()
            .onAppear { focused = true }
    }
}
