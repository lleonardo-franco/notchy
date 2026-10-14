import SwiftUI

struct ApprovalContent: View {
    let model: NotchModel

    var body: some View {
        if let request = model.pendingApproval {
            ApprovalCard(model: model, request: request)
                .id(request.id)
        }
    }
}

struct ApprovalCard: View {
    let model: NotchModel
    let request: ApprovalRequest

    @State var draft = ""
    @FocusState var focused: Bool

    private var editing: Bool { model.editingApproval }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                StatusIcon(status: .waiting, size: 12)
                Spacer()
                if model.claude.approvals.count > 1 {
                    IconButton(symbol: "chevron.left", size: 10, frame: 22, help: "Pedido anterior") {
                        model.showApproval(offset: -1)
                    }
                    Text(verbatim: "\(position)/\(model.claude.approvals.count)")
                        .font(.system(size: 11, weight: .bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .accessibilityLabel(Text("Pedido \(position) de \(model.claude.approvals.count)"))
                    IconButton(symbol: "chevron.right", size: 10, frame: 22, help: "Próximo pedido") {
                        model.showApproval(offset: 1)
                    }
                }
            }
            .frame(height: model.notchHeight)

            Color.clear.frame(height: 8)

            HStack(spacing: 6) {
                if request.codingAgent != .claude {
                    AgentBadge(agent: request.codingAgent)
                }
                Text(request.project)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("quer usar \(request.tool)")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer(minLength: 0)
            }
            .lineLimit(1)
            .frame(height: 20)

            Color.clear.frame(height: 6)

            box
                .frame(height: NotchModel.approvalBoxHeight)

            Color.clear.frame(height: 12)

            HStack(spacing: 8) {
                Button {
                    model.answerInTerminal(request)
                } label: {
                    Label("Terminal", systemImage: "terminal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Responder no terminal")
                .accessibilityLabel(Text("Responder no terminal"))

                Spacer()

                Button {
                    model.approve(request, command: editedCommand, remember: true)
                } label: {
                    Text("Sempre permitir")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(rememberHelp)

                PillButton(title: "Negar", style: .secondary) {
                    model.deny(request)
                }
                PillButton(title: "Permitir", style: .primary) {
                    model.approve(request, command: editedCommand)
                }
            }
            .frame(height: 30)

            Color.clear.frame(height: 14)
        }
        .padding(.horizontal, 18)
        .onDisappear {
            model.endEditing()
        }
    }

    private var position: Int {
        (model.claude.approvals.firstIndex { $0.id == request.id } ?? 0) + 1
    }

    private var editedCommand: String? {
        guard editing else { return nil }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var rememberHelp: LocalizedStringKey {
        if request.tool == "Bash" {
            return "Permite este comando em \(request.project) daqui em diante, sem perguntar"
        }
        return "Permite \(request.tool) em \(request.project) daqui em diante, sem perguntar"
    }

    @ViewBuilder
    private var box: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if editing {
                    TextField("Comando", text: $draft)
                        .textFieldStyle(.plain)
                        .focused($focused)
                        .onSubmit {
                            model.approve(request, command: editedCommand)
                        }
                        .onExitCommand {
                            model.endEditing()
                        }
                } else {
                    Text(request.body)
                        .lineLimit(3)
                        .truncationMode(.tail)
                }
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .padding(.trailing, request.canEdit == true ? 18 : 0)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(editing ? 0.12 : 0.07))
            )

            if request.canEdit == true, !editing {
                IconButton(symbol: "pencil", size: 10, frame: 22, help: "Editar o comando antes de permitir") {
                    draft = request.command ?? request.body
                    model.beginEditing()
                    DispatchQueue.main.async {
                        focused = true
                    }
                }
                .padding(4)
            }
        }
    }
}
