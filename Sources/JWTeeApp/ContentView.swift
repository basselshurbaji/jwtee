import SwiftUI
import JWTCore

struct ContentView: View {
    @State private var tokenText = ""
    @State private var secretText = ""
    @State private var secretIsBase64 = false

    private var decoded: Result<JWT, JWTError>? {
        let trimmed = tokenText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        do {
            return .success(try JWT(token: trimmed))
        } catch let error as JWTError {
            return .failure(error)
        } catch {
            return .failure(.malformedStructure(segmentCount: 0))
        }
    }

    var body: some View {
        HSplitView {
            inputPane
                .frame(minWidth: 320)
            outputPane
                .frame(minWidth: 360)
        }
        .padding()
    }

    // MARK: - Input

    private var inputPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encoded token").font(.headline)
            TextEditor(text: $tokenText)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.3))

            Text("Secret").font(.headline)
            TextField("Signing secret", text: $secretText)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Toggle("Secret is base64-encoded", isOn: $secretIsBase64)
                .font(.caption)

            Spacer()
        }
        .padding(8)
    }

    // MARK: - Output

    @ViewBuilder
    private var outputPane: some View {
        switch decoded {
        case .none:
            placeholder
        case let .failure(error):
            errorView(error)
        case let .success(jwt):
            decodedView(jwt)
        }
    }

    private var placeholder: some View {
        VStack {
            Spacer()
            Text("Paste a JWT to decode it.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func errorView(_ error: JWTError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Could not decode token", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            Text(message(for: error)).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(8)
    }

    private func decodedView(_ jwt: JWT) -> some View {
        let inspection = TokenInspection(jwt: jwt)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !inspection.highlights.isEmpty {
                    GroupBox("Claims") {
                        VStack(alignment: .leading, spacing: 8) {
                            validityBadges(inspection)
                            ForEach(inspection.highlights, id: \.label) { item in
                                HStack(alignment: .top) {
                                    Text(item.label).bold().frame(width: 90, alignment: .leading)
                                    Text(item.value).font(.system(.body, design: .monospaced))
                                    Spacer()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                GroupBox("Header") { monospaced(inspection.prettyHeader) }
                GroupBox("Payload") { monospaced(inspection.prettyPayload) }
                GroupBox("Signature") { signatureSection(for: jwt) }
            }
            .padding(8)
        }
    }

    private func signatureSection(for jwt: JWT) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            signatureBadge(for: jwt)
            if !jwt.rawSignature.isEmpty {
                Text("Encoded signature")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(jwt.rawSignature)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func signatureBadge(for jwt: JWT) -> some View {
        if secretText.isEmpty {
            Label("Enter a secret to verify the signature", systemImage: "key")
                .foregroundStyle(.secondary)
        } else {
            switch JWTVerifier.verify(jwt, secret: secretText, encoding: secretIsBase64 ? .base64 : .utf8) {
            case .valid:
                Label("Signature verified", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green).font(.headline)
            case .invalid:
                Label("Invalid signature", systemImage: "xmark.seal.fill")
                    .foregroundStyle(.red).font(.headline)
            case let .unsupportedAlgorithm(alg):
                Label("Unsupported algorithm: \(alg ?? "none")", systemImage: "questionmark.diamond")
                    .foregroundStyle(.orange).font(.headline)
            }
        }
    }

    @ViewBuilder
    private func validityBadges(_ inspection: TokenInspection) -> some View {
        HStack {
            if let expired = inspection.isExpired {
                Label(expired ? "Expired" : "Not expired",
                      systemImage: expired ? "clock.badge.xmark" : "clock")
                    .foregroundStyle(expired ? .red : .green)
            }
            if let early = inspection.isNotYetValid, early {
                Label("Not yet valid (nbf)", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            }
        }
        .font(.subheadline)
    }

    private func monospaced(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func message(for error: JWTError) -> String {
        switch error {
        case let .malformedStructure(count):
            return "A JWT must have 3 dot-separated segments; found \(count)."
        case let .invalidBase64URL(segment):
            return "The \(segment.rawValue) segment is not valid base64url."
        case let .invalidJSON(segment):
            return "The \(segment.rawValue) segment is not valid JSON."
        case .notAJSONObject:
            return "A token segment decoded to JSON that is not an object."
        }
    }
}
