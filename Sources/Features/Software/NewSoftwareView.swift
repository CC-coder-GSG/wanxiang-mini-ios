import SwiftUI

// Period options matching Android exactly
private let periodOptions: [(label: String, days: Int)] = [
    ("本次不注册", 0),
    ("一天", 1),
    ("三天", 3),
    ("七天", 7),
    ("一个月", 30),
    ("两个月", 60),
    ("半年", 180),
    ("一年", 365),
    ("永久", 73000)
]

struct NewSoftwareView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var onSuccess: (() -> Void)? = nil

    @State private var remark = ""
    // Default: 3 days from now
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now
    @State private var genNum = 1

    // fn[0]=软件注册 defaults to "一年"(index 7), rest default to "本次不注册"(index 0)
    @State private var fnPeriodIndex = [7, 0, 0, 0, 0]

    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var successMsg: String? = nil

    private let fnNames = ["软件注册", "多语言功能", "铁路测量", "样方放样", "物探放样"]

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            Form {
                Section("基本信息") {
                    TextField("备注（选填）", text: $remark)
                    DatePicker("到期时间", selection: $expirationDate,
                               in: Date.now...,
                               displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                    Stepper("生成数量：\(genNum)", value: $genNum, in: 1...100)
                }

                Section("功能有效期") {
                    ForEach(0..<5, id: \.self) { i in
                        Picker(fnNames[i], selection: $fnPeriodIndex[i]) {
                            ForEach(periodOptions.indices, id: \.self) { j in
                                Text(periodOptions[j].label).tag(j)
                            }
                        }
                    }
                }

                if let err = errorMsg {
                    Section {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.subheadline)
                    }
                }
                if let msg = successMsg {
                    Section {
                        Label(msg, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }

                Section {
                    Button("生成注册码") { submit() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isLoading)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init())
                }
            }
            .navigationTitle("新建注册码")
            .navigationBarTitleDisplayMode(.inline)

            if isLoading {
                LoadingOverlay(message: "生成中...")
            }
        }
    }

    private func submit() {
        isLoading = true
        errorMsg = nil
        successMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                // Format: "yyyy-MM-dd 23:59:59" matching Android
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                let dateStr = df.string(from: expirationDate) + " 23:59:59"

                // Always send all 5 functions, 0 days = "本次不注册"
                let functions: [NewSoftwareFunction] = (0..<5).map { i in
                    NewSoftwareFunction(id: i + 1, regDays: periodOptions[fnPeriodIndex[i]].days)
                }
                let req = NewSoftwareRequest(
                    cn: true,
                    companyId: nil,
                    expirationDate: dateStr,
                    functions: functions,
                    genNum: genNum,
                    isDomestic: 1,
                    isExport: false,
                    remark: remark,
                    salesMan: "暂无归属"
                )
                let resp = try await APIClient.shared.createSoftwareLicense(request: req, userId: env.userId, token: token)
                successMsg = resp.message.isEmpty ? "生成成功" : resp.message
                onSuccess?()
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}

#Preview("新建注册码") {
    NavigationStack {
        NewSoftwareView()
    }
    .environment(AppEnvironment.preview())
}
