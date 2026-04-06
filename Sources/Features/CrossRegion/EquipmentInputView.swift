import SwiftUI

struct EquipmentInputView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var sn = ""
    @State private var remark = ""
    @State private var duration = "1"
    @State private var active = false
    @State private var dealerKeyword = ""
    @State private var dealers: [DealerItem] = []
    @State private var selectedDealer: DealerItem? = nil
    @State private var isSearchingDealer = false
    @State private var isSubmitting = false
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                Section("设备信息") {
                    LabeledContent("SN 号") {
                        TextField("必填", text: $sn)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                    }
                    LabeledContent("配套时长（年）") {
                        TextField("年数", text: $duration)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    Toggle("是否立即激活", isOn: $active)
                    TextField("备注（选填）", text: $remark)
                }

                Section("经销商") {
                    HStack {
                        TextField("搜索经销商", text: $dealerKeyword)
                            .submitLabel(.search)
                            .onSubmit { searchDealers() }
                        if isSearchingDealer {
                            ProgressView().frame(width: 20)
                        } else {
                            Button("搜索") { searchDealers() }
                                .buttonStyle(.borderless)
                                .disabled(dealerKeyword.isEmpty)
                        }
                    }

                    if let sel = selectedDealer {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sel.companyName).font(.subheadline.bold())
                                if let t = sel.tel { Text(t).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { selectedDealer = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }

                    ForEach(dealers) { dealer in
                        Button {
                            selectedDealer = dealer
                            dealers = []
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(dealer.companyName).font(.subheadline)
                                    if let t = dealer.tel { Text(t).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                if let err = errorMsg {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange).font(.subheadline)
                    }
                }
                if let msg = successMsg {
                    Section {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).font(.subheadline)
                    }
                }

                Section {
                    Button("录入设备") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isSubmitting || sn.isEmpty)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init())
                }
            }
            .navigationTitle("设备录入")
            .navigationBarTitleDisplayMode(.inline)

            if isSubmitting { LoadingOverlay(message: "录入中...") }
        }
    }

    private func searchDealers() {
        guard !dealerKeyword.isEmpty else { return }
        isSearchingDealer = true
        errorMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                dealers = try await APIClient.shared.searchDealer(keyword: dealerKeyword, token: token)
                if dealers.isEmpty { errorMsg = "未找到匹配的经销商" }
            } catch { errorMsg = env.handle(error) }
            isSearchingDealer = false
        }
    }

    private func submit() {
        let snVal = sn.trimmingCharacters(in: .whitespaces)
        guard !snVal.isEmpty else { errorMsg = "请输入 SN 号"; return }
        guard !duration.isEmpty, let durationInt = Int(duration), durationInt >= 1, durationInt <= 10 else { errorMsg = "请输入有效的年数（1-10）"; return }
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }

        isSubmitting = true
        errorMsg = nil
        successMsg = nil
        Task {
            do {
                let resp = try await APIClient.shared.saveEquipment(
                    sn: snVal,
                    companyId: selectedDealer.map { "\($0.companyId)" },
                    managerId: selectedDealer.map { "\($0.managerId)" },
                    remark: remark,
                    duration: duration,
                    active: active,
                    token: token
                )
                successMsg = resp.message.isEmpty ? "录入成功" : resp.message
                sn = ""
                remark = ""
                selectedDealer = nil
            } catch { errorMsg = env.handle(error) }
            isSubmitting = false
        }
    }
}

#Preview("设备录入") {
    NavigationStack {
        EquipmentInputView()
    }
    .environment(AppEnvironment.preview())
}
