import SwiftUI

struct CrossRegionView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var sn = ""
    @State private var deviceItems: [DeviceItem] = []
    @State private var selectedDevice: DeviceItem? = nil
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @FocusState private var snFocused: Bool

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Search
                HStack(spacing: 10) {
                    TextField("输入 SN 号", text: $sn)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .focused($snFocused)
                        .submitLabel(.search)
                        .onSubmit { search() }
                    Button("查询") { search() }
                        .buttonStyle(.borderedProminent)
                        .disabled(sn.isEmpty || isLoading)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)

                if let err = errorMsg {
                    ErrorBanner(message: err) { errorMsg = nil }
                }

                List {
                    ForEach(deviceItems) { item in
                        NavigationLink {
                            CrossRegionEditView(device: item)
                        } label: {
                            DeviceItemRow(device: item)
                        }
                        .listRowBackground(Color.appCard)
                    }
                }
                .listStyle(.insetGrouped)
                .overlay {
                    if deviceItems.isEmpty && !isLoading {
                        ContentUnavailableView("输入 SN 号查询设备", systemImage: "magnifyingglass")
                    }
                }
            }
            .navigationTitle("万象地信")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        EquipmentInputView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

            if isLoading { LoadingOverlay(message: "查询中...") }
        }
    }

    private func search() {
        snFocused = false
        let snVal = sn.trimmingCharacters(in: .whitespaces)
        guard !snVal.isEmpty else { return }
        isLoading = true
        errorMsg = nil
        Task {
            do {
                let token = try env.requireToken()
                let data = try await APIClient.shared.fetchDeviceList(keyword: snVal, page: 1, pageSize: 15, token: token)
                deviceItems = data.list
                if data.list.isEmpty { errorMsg = "未查询到该 SN 号" }
                else if data.list.count > 1 { errorMsg = "检测到多条记录，请精确 SN 号" }
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }
}

struct DeviceItemRow: View {
    let device: DeviceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.sn).font(.subheadline.bold())
                Spacer()
                Circle()
                    .fill((device.online == true) ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
            if let dt = device.deviceType {
                Text(dt).font(.caption).foregroundStyle(.secondary)
            }
            if let s = device.salesName {
                Label(s, systemImage: "storefront").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                if let exp = device.expireTime {
                    Label(String.fromMillis(exp), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(exp < Int64(Date().timeIntervalSince1970 * 1000) ? .red : .secondary)
                }
                Spacer()
                if let d = device.duration, d > 0 {
                    Text("配套剩余 \(d) 年").font(.caption2).foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("跨区设备管理") {
    NavigationStack {
        CrossRegionView()
    }
    .environment(AppEnvironment.preview())
}

#Preview("设备行") {
    DeviceItemRow(device: DeviceItem(
        id: 999,
        sn: "SN2024001234",
        deviceType: "N5 PRO",
        salesName: "北京测绘有限公司",
        remark: "测试设备",
        remainingTime: 180,
        online: true,
        isFarm: false,
        status: 1,
        duration: 365,
        createTime: nil,
        expireTime: nil
    ))
    .padding()
}
