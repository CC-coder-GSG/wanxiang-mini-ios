import SwiftUI
import CoreImage.CIFilterBuiltins

struct SoftwareListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var licenses: [SoftwareLicense] = []
    @State private var keyword = ""
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var selectedLicense: SoftwareLicense? = nil
    @State private var copiedCode: String? = nil

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("关键词搜索", text: $keyword)
                        .submitLabel(.search)
                        .onSubmit { reload() }
                    if !keyword.isEmpty {
                        Button { keyword = ""; reload() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
                .padding(.vertical, 10)

                if let err = errorMsg {
                    ErrorBanner(message: err) { errorMsg = nil }
                }

                List {
                    ForEach(licenses) { lic in
                        Button { selectedLicense = lic } label: {
                            LicenseRow(license: lic)
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = lic.passWord
                                copiedCode = lic.passWord
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedCode = nil }
                            } label: {
                                Label("复制注册码", systemImage: "doc.on.doc")
                            }
                        }
                        .listRowBackground(Color.appCard)
                    }

                    // Pagination
                    if totalPages > 1 {
                        HStack {
                            Button { loadPage(currentPage - 1) } label: {
                                Image(systemName: "chevron.left")
                            }
                            .disabled(currentPage <= 1)

                            Spacer()
                            Text("\(currentPage) / \(totalPages)")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()

                            Button { loadPage(currentPage + 1) } label: {
                                Image(systemName: "chevron.right")
                            }
                            .disabled(currentPage >= totalPages)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { reload() }
            }
            .navigationTitle("软件注册码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        NewSoftwareView { reload() }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { reload() }
            .sheet(item: $selectedLicense) { lic in
                LicenseDetailSheet(license: lic)
            }

            if isLoading {
                LoadingOverlay(message: "加载中...")
            }

            if let code = copiedCode {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill").foregroundStyle(.white)
                        Text("已复制").foregroundStyle(.white).font(.subheadline.bold())
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                .animation(.easeInOut(duration: 0.25), value: code)
                .allowsHitTesting(false)
            }
        }
    }

    private func reload() { loadPage(1) }

    private func loadPage(_ page: Int) {
        guard page >= 1 else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                let data = try await APIClient.shared.fetchSoftwareLicenses(keyword: keyword, page: page, size: 20, token: token)
                licenses = data.content
                totalPages = data.totalPages ?? 1
                currentPage = page
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}

struct LicenseRow: View {
    let license: SoftwareLicense

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(license.passWord)
                    .font(.system(.subheadline, design: .monospaced).bold())
                Spacer()
                let stateVal = license.state ?? ""
                Text(stateVal)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(stateVal == "UNUSED" ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1), in: Capsule())
                    .foregroundStyle(stateVal == "UNUSED" ? .green : .secondary)
            }
            if let sm = license.salesMan, !sm.isEmpty {
                Text("销售: \(sm)").font(.caption).foregroundStyle(.secondary)
            }
            Text("创建: \((license.creationTime ?? "").prefix(10))  到期: \((license.expirationDate ?? "").prefix(10))")
                .font(.caption).foregroundStyle(.secondary)
            if let fns = license.functions, !fns.isEmpty {
                Text(fns.filter(\.enable).map { functionName($0.id) }.joined(separator: "·"))
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct LicenseDetailSheet: View {
    let license: SoftwareLicense
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: UIImage? = nil
    @State private var qrCopied = false

    private let functionNames = ["软件注册", "多语言功能", "铁路测量", "样方放样", "物探放样"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // QR Code
                    if let img = qrImage {
                        ZStack(alignment: .bottom) {
                            Image(uiImage: img)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 200, height: 200)
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .contextMenu {
                                    Button {
                                        UIPasteboard.general.image = img
                                        qrCopied = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { qrCopied = false }
                                    } label: {
                                        Label("复制二维码", systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let root = scene.windows.first?.rootViewController {
                                            var top = root
                                            while let presented = top.presentedViewController { top = presented }
                                            top.present(av, animated: true)
                                        }
                                    } label: {
                                        Label("分享二维码", systemImage: "square.and.arrow.up")
                                    }
                                }

                            if qrCopied {
                                Text("已复制")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.7), in: Capsule())
                                    .padding(.bottom, 8)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: qrCopied)
                    }

                    // Password to copy
                    HStack {
                        Text(license.passWord)
                            .font(.system(.title3, design: .monospaced).bold())
                        Spacer()
                        Button {
                            UIPasteboard.general.string = license.passWord
                        } label: {
                            Image(systemName: "doc.on.doc").foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

                    // Details
                    VStack(alignment: .leading, spacing: 6) {
                        InfoRow(label: "批次号", value: license.batchNo ?? "—")
                        InfoRow(label: "状态", value: license.state ?? "—")
                        InfoRow(label: "创建时间", value: String((license.creationTime ?? "").prefix(10)))
                        InfoRow(label: "到期时间", value: String((license.expirationDate ?? "").prefix(10)))
                        InfoRow(label: "可激活天数", value: "\(license.redeemableDays ?? 0) 天")
                        InfoRow(label: "销售", value: license.salesMan ?? "—")
                        InfoRow(label: "备注", value: license.remark ?? "—")
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                    // Functions
                    if let fns = license.functions, !fns.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("功能详情").font(.subheadline.bold())
                            ForEach(fns, id: \.id) { fn in
                                HStack {
                                    Image(systemName: fn.enable ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(fn.enable ? .green : .secondary)
                                    Text(functionName(fn.id))
                                    Spacer()
                                    if fn.enable {
                                        Text("\(fn.regDays) 天").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("注册码详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear { generateQR() }
        }
    }

    private func generateQR() {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(license.passWord.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(scaled, from: scaled.extent) else { return }
        qrImage = UIImage(cgImage: cgImage)
    }
}

private func functionName(_ id: Int) -> String {
    switch id {
    case 1: return "软件注册"
    case 2: return "多语言"
    case 3: return "铁路测量"
    case 4: return "样方放样"
    case 5: return "物探放样"
    default: return "功能\(id)"
    }
}

#Preview("软件注册码列表") {
    NavigationStack {
        SoftwareListView()
    }
    .environment(AppEnvironment.preview())
}

#Preview("注册码行") {
    LicenseRow(license: SoftwareLicense(
        licenseId: "abc123",
        batchNo: "BATCH001",
        passWord: "XXXX-YYYY-ZZZZ-0000",
        creationTime: "2024-01-15T10:00:00",
        expirationDate: "2025-01-15T10:00:00",
        redeemableDays: 365,
        remark: "测试用",
        salesMan: "张三",
        state: "UNUSED",
        functions: [
            SoftwareFunction(id: 1, regDays: 365, enable: true),
            SoftwareFunction(id: 3, regDays: 180, enable: true)
        ]
    ))
    .padding()
}
