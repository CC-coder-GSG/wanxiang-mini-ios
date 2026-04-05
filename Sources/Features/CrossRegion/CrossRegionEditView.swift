import SwiftUI

struct AccountTypeOption {
    let code: String
    let label: String
}

struct CrossRegionEditView: View {
    static let accountTypeOptions: [AccountTypeOption] = [
        .init(code: "9",     label: "随区域"),
        .init(code: "0",     label: "SinoGNSS"),
        .init(code: "2",     label: "中国移动"),
        .init(code: "1",     label: "千寻"),
        .init(code: "0,2",   label: "SinoGNSS → 中国移动"),
        .init(code: "0,2,1", label: "SinoGNSS → 中国移动 → 千寻"),
        .init(code: "0,1",   label: "SinoGNSS → 千寻"),
        .init(code: "0,1,2", label: "SinoGNSS → 千寻 → 中国移动"),
        .init(code: "2,0,1", label: "中国移动 → SinoGNSS → 千寻"),
        .init(code: "2,0",   label: "中国移动 → SinoGNSS"),
        .init(code: "2,1,0", label: "中国移动 → 千寻 → SinoGNSS"),
        .init(code: "2,1",   label: "中国移动 → 千寻"),
        .init(code: "1,2,0", label: "千寻 → 中国移动 → SinoGNSS"),
        .init(code: "1,2",   label: "千寻 → 中国移动"),
        .init(code: "1,0,2", label: "千寻 → SinoGNSS → 中国移动"),
        .init(code: "1,0",   label: "千寻 → SinoGNSS"),
    ]
    @Environment(AppEnvironment.self) private var env
    let device: DeviceItem

    @State private var detail: DeviceDetail? = nil
    @State private var isSpan: Bool = false
    @State private var accountType: String = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil
    @State private var showDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if let err = errorMsg {
                        ErrorBanner(message: err) { errorMsg = nil }
                    }
                    if let msg = successMsg {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(msg).font(.subheadline)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }

                    if let d = detail {
                        // Device info
                        VStack(alignment: .leading, spacing: 6) {
                            Text("设备信息").font(.subheadline.bold()).padding(.bottom, 2)
                            InfoRow(label: "SN", value: d.sn)
                            InfoRow(label: "类型", value: d.deviceType)
                            InfoRow(label: "经销商", value: d.salesName ?? "—")
                            InfoRow(label: "创建人", value: d.creatorName ?? "—")
                            InfoRow(label: "备注", value: d.remark ?? "—")
                            InfoRow(label: "剩余时长", value: "\(d.remainingTime) 天")
                            InfoRow(label: "在线", value: d.online ? "是" : "否")
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Span setting
                        VStack(alignment: .leading, spacing: 12) {
                            Text("跨区设置").font(.subheadline.bold())
                            Toggle("允许跨区", isOn: $isSpan)
                            Button("更新跨区状态") { updateSpan() }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Account type (基站策略)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("基站策略").font(.subheadline.bold())
                            Picker("基站策略", selection: $accountType) {
                                ForEach(Self.accountTypeOptions, id: \.code) { opt in
                                    Text(opt.label).tag(opt.code)
                                }
                            }
                            Button("更新基站策略") { updateAccountType() }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Delete
                        VStack(alignment: .leading, spacing: 12) {
                            Text("危险操作").font(.subheadline.bold())
                            Button("删除设备") { showDeleteConfirm = true }
                                .buttonStyle(PrimaryButtonStyle(isDestructive: true))
                                .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 12)
            }
            .navigationTitle(device.sn)
            .navigationBarTitleDisplayMode(.inline)
            .task { loadDetail() }
            .confirmationDialog("确定删除该设备？此操作不可撤销。", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("删除", role: .destructive) { deleteDevice() }
                Button("取消", role: .cancel) {}
            }

            if isLoading { LoadingOverlay(message: "处理中...") }
        }
    }

    private func loadDetail() {
        isLoading = true
        Task {
            do {
                let token = try env.requireToken()
                let d = try await APIClient.shared.fetchDeviceDetail(id: device.id, token: token)
                detail = d
                isSpan = d.isSpan
                let validCode = Self.accountTypeOptions.first(where: { $0.code == d.accountType })?.code
                accountType = validCode ?? "9"
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func updateSpan() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                let resp = try await APIClient.shared.updateSpan(id: device.id, isSpan: isSpan, token: token)
                successMsg = resp.message.isEmpty ? "更新成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func updateAccountType() {
        guard Self.accountTypeOptions.contains(where: { $0.code == accountType }) else { errorMsg = "请选择基站策略"; return }
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                let resp = try await APIClient.shared.updateAccountType(sn: device.sn, accountType: accountType, token: token)
                successMsg = resp.message.isEmpty ? "更新成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func deleteDevice() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        Task {
            do {
                _ = try await APIClient.shared.deleteEquipment(sn: device.sn, token: token)
                successMsg = "设备已删除"
                dismiss()
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}
