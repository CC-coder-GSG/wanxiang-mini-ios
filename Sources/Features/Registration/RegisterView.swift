import SwiftUI

struct RegisterView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sn = ""
    @State private var extendDays = 30
    @State private var record: RegRecord? = nil
    @State private var isLoading = false
    @State private var loadingMsg = "查询中..."
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil
    @State private var showRegisterConfirm = false
    @FocusState private var snFocused: Bool

    private let dayOptions = [30, 1, 2, 3, 4, 5, 6, 7, 15]

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // SN Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SN 号").font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("输入设备 SN 号", text: $sn)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.characters)
                                .focused($snFocused)
                                .onChange(of: sn) {
                                    record = nil
                                    errorMsg = nil
                                    successMsg = nil
                                }
                            if !sn.isEmpty {
                                Button { sn = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // Extend days picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("生成天数").font(.caption).foregroundStyle(.secondary)
                        Picker("天数", selection: $extendDays) {
                            ForEach(dayOptions, id: \.self) { d in
                                Text("\(d) 天").tag(d)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 10) {
                        Button("查询注册信息") { queryInfo() }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(sn.isEmpty || isLoading)

                        Button("生成注册码") { showRegisterConfirm = true }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(sn.isEmpty || isLoading)
                    }
                    .padding(.horizontal)

                    // Error / Success
                    if let err = errorMsg {
                        ErrorBanner(message: err) { errorMsg = nil }
                    }
                    if let msg = successMsg {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(msg).font(.subheadline)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }

                    // Device info card
                    if let r = record {
                        DeviceInfoCard(record: r)
                            .padding(.horizontal)

                        NavigationLink {
                            RegisterSystemView(record: r)
                        } label: {
                            Label("功能授权", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 16)
            }
            .navigationTitle("设备注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        RegisterLogView()
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
            .confirmationDialog("确定要生成注册码吗？", isPresented: $showRegisterConfirm, titleVisibility: .visible) {
                Button("生成") { generateCode() }
                Button("取消", role: .cancel) {}
            }

            if isLoading {
                LoadingOverlay(message: loadingMsg)
            }
        }
    }

    // MARK: - Query info

    private func queryInfo() {
        snFocused = false
        let snVal = sn.trimmingCharacters(in: .whitespaces)
        guard !snVal.isEmpty else { return }
        isLoading = true
        loadingMsg = "查询中..."
        errorMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                let records = try await APIClient.shared.fetchRegisterInfo(keyword: snVal, token: token)
                if records.isEmpty {
                    errorMsg = "未查询到该 SN 号"
                    record = nil
                } else if records.count > 1 {
                    errorMsg = "检测到多个设备，请检查 SN 号"
                    record = nil
                } else {
                    record = records[0]
                }
            } catch {
                errorMsg = env.handle(error)
            }
            isLoading = false
        }
    }

    // MARK: - Generate code

    private func generateCode() {
        snFocused = false
        let snVal = sn.trimmingCharacters(in: .whitespaces)
        guard !snVal.isEmpty else { return }
        isLoading = true
        loadingMsg = "处理中..."
        errorMsg = nil
        successMsg = nil

        Task {
            do {
                let token = try env.requireToken()

                // 1. Save history
                let histRecord = LocalStore.shared.addHistory(sn: snVal)

                // 2. Fetch current register info
                let records = try await APIClient.shared.fetchRegisterInfo(keyword: snVal, token: token)
                guard !records.isEmpty else { throw APIError.serverError("未查询到该 SN 号") }
                guard records.count == 1 else { throw APIError.serverError("检测到多个设备，请检查 SN 号") }
                let r = records[0]

                guard let deadline = r.tempRegDeadline else {
                    throw APIError.serverError("注册截至日期不存在，请先出库")
                }

                let codeExpireISO = isoString(daysFromNow: extendDays)

                // 3. Check if need to extend deadline first
                if let remaining = daysUntil(deadline), remaining > extendDays + 1 {
                    // Deadline has enough room, generate code directly
                    let resp = try await APIClient.shared.generateDomesticCode(sn: snVal, expireTime: codeExpireISO, token: token)
                    LocalStore.shared.updateHistory(record: histRecord, registerTime: Date())
                    successMsg = resp.message
                } else {
                    // Need to extend deadline first
                    let newDeadline = deadlineString(daysFromNow: extendDays)
                    loadingMsg = "延期中..."
                    _ = try await APIClient.shared.extendRegDeadline(sn: snVal, deadline: newDeadline, token: token)
                    LocalStore.shared.updateHistory(record: histRecord, extendTime: Date())
                    loadingMsg = "生成注册码..."
                    let resp = try await APIClient.shared.generateDomesticCode(sn: snVal, expireTime: codeExpireISO, token: token)
                    LocalStore.shared.updateHistory(record: histRecord, registerTime: Date())
                    successMsg = resp.message
                }

                // 4. Refresh device info
                loadingMsg = "刷新信息..."
                let records2 = try await APIClient.shared.fetchRegisterInfo(keyword: snVal, token: token)
                if records2.count == 1 { record = records2[0] }

            } catch {
                errorMsg = env.handle(error)
            }
            isLoading = false
        }
    }
}

// MARK: - DeviceInfoCard

struct DeviceInfoCard: View {
    let record: RegRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("设备信息").font(.subheadline.bold()).padding(.bottom, 4)
            InfoRow(label: "SN", value: record.sn)
            InfoRow(label: "经销商", value: record.companyName)
            InfoRow(label: "创建时间", value: record.createTime)
            InfoRow(label: "型号", value: record.productionType)
            InfoRow(label: "注册截止", value: record.tempRegDeadline ?? "—")
            InfoRow(label: "永久码", value: record.permanentRegCodeHave ? "有" : "无")
            InfoRow(label: "临时码到期", value: record.tempRegCodeExpireTime ?? "—")
            InfoRow(label: "主机网络", value: record.isHostNet ? "已开通" : "未开通")
            InfoRow(label: "手簿网络", value: record.isNtrip ? "已开通" : "未开通")
            InfoRow(label: "可试用", value: record.todayCanTrial ? "是" : "否")
            InfoRow(label: "剩余试用", value: "\(record.trialDay) 天")
            InfoRow(label: "试用状态", value: record.trialStatus == "TRIALING" ? "试用中" : "试用结束")
            if let r = record.remark { InfoRow(label: "备注", value: r) }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview("设备注册") {
    NavigationStack {
        RegisterView()
    }
    .environment(AppEnvironment.preview())
    .modelContainer(LocalStore.shared.container)
}

#Preview("设备信息卡片") {
    DeviceInfoCard(record: RegRecord(
        sn: "SN2024001234",
        companyName: "北京测绘有限公司",
        createTime: "2024-01-15",
        productionType: "N5 PRO",
        tempRegDeadline: "2025-06-30",
        tempRegCodeExpireTime: "2025-01-15T00:00:00.000Z",
        tempRegCodeHave: true,
        permanentRegCodeHave: false,
        permanentRegCodeOn: false,
        isHostNet: true,
        isNtrip: false,
        offHostNetTime: nil,
        offNtripTime: nil,
        lastUpdateTime: nil,
        lastUserName: "admin",
        remark: "测试设备",
        trialDay: 7,
        trialStatus: "TRIALING",
        todayCanTrial: true
    ))
    .padding()
}
