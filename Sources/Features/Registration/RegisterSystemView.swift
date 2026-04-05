import SwiftUI

struct RegisterSystemView: View {
    @Environment(AppEnvironment.self) private var env
    let record: RegRecord

    @State private var isHostNet: Bool
    @State private var isNtrip: Bool
    @State private var hostNetDate: Date
    @State private var ntripDate: Date
    @State private var trialDaysText: String
    @State private var tempDeadlineDate: Date
    @State private var isLoading = false
    @State private var loadingMsg = ""
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil
    @FocusState private var trialDaysFocused: Bool

    private let df = DateFormatter.display

    init(record: RegRecord) {
        self.record = record
        _isHostNet = State(initialValue: record.isHostNet)
        _isNtrip = State(initialValue: record.isNtrip)
        _trialDaysText = State(initialValue: "\(record.trialDay)")

        // Parse dates or default to +365 days
        let future = Calendar.current.date(byAdding: .day, value: 365, to: .now)!
        if let s = record.offHostNetTime, let d = DateFormatter.display.date(from: String(s.prefix(10))) {
            _hostNetDate = State(initialValue: d)
        } else {
            _hostNetDate = State(initialValue: future)
        }
        if let s = record.offNtripTime, let d = DateFormatter.display.date(from: String(s.prefix(10))) {
            _ntripDate = State(initialValue: d)
        } else {
            _ntripDate = State(initialValue: future)
        }
        if let s = record.tempRegDeadline, let d = DateFormatter.display.date(from: s) {
            _tempDeadlineDate = State(initialValue: d)
        } else {
            _tempDeadlineDate = State(initialValue: future)
        }
    }

    var alreadyOut: Bool { record.tempRegCodeExpireTime != nil }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {

                    // SN Header
                    HStack {
                        Text("SN: \(record.sn)")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

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

                    // Function Authorization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("网络功能授权").font(.subheadline.bold())
                        Toggle("主机网络", isOn: $isHostNet)
                        if isHostNet {
                            DatePicker("主机网络截止", selection: $hostNetDate, displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }
                        Toggle("手簿网络", isOn: $isNtrip)
                        if isNtrip {
                            DatePicker("手簿网络截止", selection: $ntripDate, displayedComponents: .date)
                                .environment(\.locale, Locale(identifier: "zh_CN"))
                        }
                        Button("提交功能授权") { submitFunctions() }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isLoading)
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Modify temp deadline
                    VStack(alignment: .leading, spacing: 12) {
                        Text("修改注册截止时间").font(.subheadline.bold())
                        DatePicker("截止日期", selection: $tempDeadlineDate, displayedComponents: .date)
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        Button("更新截止时间") { updateDeadline() }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(isLoading)
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)

                    // Trial section (only if not yet out)
                    if !alreadyOut {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("试用管理").font(.subheadline.bold())
                            HStack {
                                Text("试用天数")
                                Spacer()
                                TextField("天数", text: $trialDaysText)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 70)
                                    .focused($trialDaysFocused)
                            }
                            HStack(spacing: 10) {
                                Button("修改试用天数") { trialDaysFocused = false; updateTrialDays() }
                                    .buttonStyle(SecondaryButtonStyle())
                                Button("开始试用") { trialDaysFocused = false; startTrial() }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                            .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                        // Out
                        VStack(alignment: .leading, spacing: 12) {
                            Text("出库").font(.subheadline.bold())
                            Text("出库后设备进入正式计费周期，试用相关功能将不再显示。").font(.caption).foregroundStyle(.secondary)
                            Button("出库") { outDevice() }
                                .buttonStyle(PrimaryButtonStyle(isDestructive: true))
                                .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Permanent code push
                    if record.permanentRegCodeHave {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("永久码下发").font(.subheadline.bold())
                            Button("下发永久码") { pushPermanentCode() }
                                .buttonStyle(SecondaryButtonStyle())
                                .disabled(isLoading)
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom)
            }
            .navigationTitle("功能授权")
            .navigationBarTitleDisplayMode(.inline)
            .onTapGesture { trialDaysFocused = false }

            if isLoading {
                LoadingOverlay(message: loadingMsg)
            }
        }
    }

    // MARK: - Actions

    private func submitFunctions() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        loadingMsg = "提交中..."
        errorMsg = nil
        successMsg = nil
        Task {
            do {
                let req = FunctionUpdateRequest(
                    snList: [record.sn],
                    isHostNet: isHostNet,
                    isNtrip: isNtrip,
                    initHostNetRegDeadline: isHostNet ? df.string(from: hostNetDate) : record.offHostNetTime,
                    initNtripRegDeadline: isNtrip ? df.string(from: ntripDate) : record.offNtripTime,
                    offHostNetTime: record.offHostNetTime,
                    offNtripTime: record.offNtripTime,
                    keyword: record.sn,
                    lastUpdateTime: record.lastUpdateTime
                )
                let resp = try await APIClient.shared.updateFunctions(info: req, token: token)
                successMsg = resp.message.isEmpty ? "授权成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func updateDeadline() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        loadingMsg = "更新中..."
        Task {
            do {
                let deadlineStr = df.string(from: tempDeadlineDate)
                let resp = try await APIClient.shared.updateTempRegDeadline(sn: record.sn, deadline: deadlineStr, token: token)
                successMsg = resp.message.isEmpty ? "更新成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func updateTrialDays() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        guard let days = Int(trialDaysText), days >= 0 else {
            errorMsg = "请输入有效天数"
            return
        }
        isLoading = true
        loadingMsg = "更新中..."
        Task {
            do {
                let resp = try await APIClient.shared.updateTrialDays(sn: record.sn, days: days, token: token)
                successMsg = resp.message.isEmpty ? "更新成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func startTrial() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        loadingMsg = "处理中..."
        Task {
            do {
                let resp = try await APIClient.shared.trialDevice(sn: record.sn, token: token)
                successMsg = resp.message.isEmpty ? "试用成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func outDevice() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        loadingMsg = "出库中..."
        Task {
            do {
                let resp = try await APIClient.shared.outDevice(sn: record.sn, token: token)
                successMsg = resp.message.isEmpty ? "出库成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func pushPermanentCode() {
        guard let token = try? env.requireToken() else { env.handle(APIError.notLoggedIn); return }
        isLoading = true
        loadingMsg = "下发中..."
        Task {
            do {
                let resp = try await APIClient.shared.pushPermanentCode(sn: record.sn, token: token)
                successMsg = resp.message.isEmpty ? "下发成功" : resp.message
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}

#Preview("功能授权") {
    NavigationStack {
        RegisterSystemView(record: RegRecord(
            sn: "SN2024001234",
            companyName: "北京测绘有限公司",
            createTime: "2024-01-15",
            productionType: "N5 PRO",
            tempRegDeadline: "2025-06-30",
            tempRegCodeExpireTime: nil,
            tempRegCodeHave: false,
            permanentRegCodeHave: true,
            permanentRegCodeOn: false,
            isHostNet: true,
            isNtrip: false,
            offHostNetTime: "2025-12-31",
            offNtripTime: nil,
            lastUpdateTime: "2024-06-01",
            lastUserName: "admin",
            remark: nil,
            trialDay: 7,
            trialStatus: "NOT_TRIAL",
            todayCanTrial: true
        ))
    }
    .environment(AppEnvironment.preview())
}
