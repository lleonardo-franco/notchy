import SwiftUI

struct ApprovalContent: View {
    let model: NotchModel

    var body: some View {
        if let request = model.pendingApproval {
            VStack(spacing: 0) {
                HStack {
                    StatusIcon(status: .waiting, size: 12)
                    Spacer()
                    if model.claude.approvals.count > 1 {
                        Text("+\(model.claude.approvals.count - 1)")
                            .font(.system(size: 11, weight: .bold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(height: model.notchHeight)

                Color.clear.frame(height: 8)

                HStack(spacing: 6) {
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

                Text(request.body)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.white.opacity(0.07))
                    )
                    .frame(height: NotchModel.approvalBoxHeight)

                Color.clear.frame(height: 12)

                HStack(spacing: 8) {
                    Button {
                        model.answerInTerminal(request)
                    } label: {
                        Label("Responder no terminal", systemImage: "terminal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    PillButton(title: "Negar", style: .secondary) {
                        model.deny(request)
                    }
                    PillButton(title: "Permitir", style: .primary) {
                        model.approve(request)
                    }
                }
                .frame(height: 30)

                Color.clear.frame(height: 14)
            }
            .padding(.horizontal, 18)
            .id(request.id)
        }
    }
}
