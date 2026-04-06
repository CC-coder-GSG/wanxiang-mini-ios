import SwiftUI

struct DiagnosticView: View {
    let account: CorsAccount
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var diag: DiagnosticData? = nil
    @State private var usage: UsageDetailData? = nil
    @State private var warnData: WarnPageData? = nil
    @State private var isLoading = false
    @State private var errorMsg: String? = nil

    // 时间范围，默认最近 24 小时
    @State private var startDate = Date().addingTimeInterval(-86400)
    @State private var endDate   = Date()

    @State private var warnPage  = 1
    @State private var warnSize  = 20

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // MARK: content

                        // ── 账户基本状态 ───────────────────────────
                        if let d = diag {
                            BasicStatusCard(diag: d)
                        }

                        // ── 时间范围选择 ───────────────────────────
                        DateRangeCard(startDate: $startDate, endDate: $endDate) {
                            loadUsageAndWarn()
                        }

                        // ── 在线时长统计 ───────────────────────────
                        if let u = usage {
                            UsageSummaryCard(usage: u)
                            if let list = u.statusList, !list.isEmpty {
                                TimelineCard(segments: list)
                            }
                            if let states = u.stateList, !states.isEmpty {
                                StateListCard(states: states)
                            }
                        }

                        // ── 告警记录 ───────────────────────────────
                        WarnListCard(
                            warnData: warnData,
                            page: warnPage,
                            onPageChange: { p in warnPage = p; loadWarn() }
                        )

                        if let err = errorMsg {
                            ErrorBanner(message: err) { errorMsg = nil }
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity)
                }
                .navigationTitle("诊断工具 · \(account.name)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("关闭") { dismiss() }
                    }
                }
                .task { loadAll() }

                if isLoading { LoadingOverlay(message: "加载中...") }
            }
        }
    }

    // MARK: - Load

    private func loadAll() {
        isLoading = true
        errorMsg  = nil
        Task {
            guard let token = try? env.requireToken() else {
                errorMsg = "请先登录"; isLoading = false; return
            }
            async let diagTask    = APIClient.shared.fetchDiagnostic(id: account.id, name: account.name, token: token)
            async let usageTask   = APIClient.shared.fetchUsageDetail(id: account.id, name: account.name, st: st, et: et, token: token)
            async let warnTask    = APIClient.shared.fetchWarnPage(id: account.id, name: account.name, st: st, et: et, page: warnPage, size: warnSize, token: token)
            do {
                let (d, u, w) = try await (diagTask, usageTask, warnTask)
                diag = d; usage = u; warnData = w
            } catch { errorMsg = env.handle(error) }
            isLoading = false
        }
    }

    private func loadUsageAndWarn() {
        guard let token = try? env.requireToken() else { return }
        warnPage = 1
        Task {
            do {
                async let u = APIClient.shared.fetchUsageDetail(id: account.id, name: account.name, st: st, et: et, token: token)
                async let w = APIClient.shared.fetchWarnPage(id: account.id, name: account.name, st: st, et: et, page: 1, size: warnSize, token: token)
                let (ud, wd) = try await (u, w)
                usage = ud; warnData = wd
            } catch { errorMsg = env.handle(error) }
        }
    }

    private func loadWarn() {
        guard let token = try? env.requireToken() else { return }
        Task {
            do {
                warnData = try await APIClient.shared.fetchWarnPage(id: account.id, name: account.name, st: st, et: et, page: warnPage, size: warnSize, token: token)
            } catch { errorMsg = env.handle(error) }
        }
    }

    private var st: Int64 { Int64(startDate.timeIntervalSince1970 * 1000) }
    private var et: Int64 { Int64(endDate.timeIntervalSince1970   * 1000) }
}

// MARK: - BasicStatusCard

private struct BasicStatusCard: View {
    let diag: DiagnosticData

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── 账户基本信息 ─────────────────────────────────
            SectionHeader(title: "账户信息")
            if let basic = diag.basic {
                DiagRow(label: "账户名", value: basic.name ?? "—")
                DiagRow(label: "服务状态") {
                    AccountStatusBadge(status: basic.status ?? -1)
                }
                if let exp = basic.expiredate {
                    DiagRow(label: "到期时间", value: String.fromMillis(exp))
                }
            }

            // ── 最新连接信息 ─────────────────────────────────
            if let latest = diag.latest {
                Divider().padding(.vertical, 8)
                SectionHeader(title: "最新连接信息")
                DiagRow(label: "在线状态") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(latest.online == true ? Color.green : Color.secondary.opacity(0.5))
                            .frame(width: 8, height: 8)
                        Text(latest.online == true ? "在线" : "离线")
                            .font(.subheadline)
                    }
                }
                if let t = latest.type {
                    DiagRow(label: "协议类型") {
                        Text(t == 0 ? "Ntrip" : "Tcp").font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.blue.opacity(0.1), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                if let mp = latest.mountPoint, !mp.isEmpty {
                    DiagRow(label: "挂载点", value: mp)
                }
                if let t = latest.lastloadtime {
                    DiagRow(label: "最后上线", value: String.fromMillisDetailed(t))
                }
                if let t = latest.lastunloadtime {
                    DiagRow(label: "最后下线", value: String.fromMillisDetailed(t))
                }
                if let t = latest.ggaTime {
                    DiagRow(label: "最新GGA时间", value: String.fromMillisDetailed(t))
                }
                if let t = latest.boradCastTime {
                    DiagRow(label: "最新播发时间", value: String.fromMillisDetailed(t))
                }
                DiagRow(label: "定位状态") {
                    Text(posStateName(latest.state))
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(posStateColor(latest.state).opacity(0.12), in: Capsule())
                        .foregroundStyle(posStateColor(latest.state))
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // 定位状态: state 字段
    private func posStateName(_ s: Int?) -> String {
        switch s {
        case 1: return "单点"
        case 2: return "伪距差分"
        case 3: return "PPS"
        case 4: return "固定解"
        case 5: return "浮点解"
        case 6: return "惯性导航"
        default: return "未定位"
        }
    }
    private func posStateColor(_ s: Int?) -> Color {
        switch s {
        case 4: return .green
        case 5: return .blue
        case 2: return .orange
        case 1: return .secondary
        default: return .secondary
        }
    }
}

// MARK: - DateRangeCard

private struct DateRangeCard: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onQuery: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("查询时间范围").font(.subheadline.bold())

            // 两行各占一行，避免横向溢出
            DatePicker("开始", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Locale(identifier: "zh_CN"))
            DatePicker("结束", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                .environment(\.locale, Locale(identifier: "zh_CN"))

            HStack(spacing: 8) {
                QuickRangeButton(label: "1小时") { setRange(hours: 1) }
                QuickRangeButton(label: "24小时") { setRange(hours: 24) }
                QuickRangeButton(label: "7天") { setRange(hours: 24 * 7) }
                Spacer()
            }
            Button(action: onQuery) {
                Label("查询", systemImage: "magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func setRange(hours: Int) {
        endDate   = Date()
        startDate = Date().addingTimeInterval(Double(-hours) * 3600)
        onQuery()
    }
}

private struct QuickRangeButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UsageSummaryCard

private struct UsageSummaryCard: View {
    let usage: UsageDetailData

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使用统计").font(.subheadline.bold())
            if let info = usage.useInfo {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatCell(title: "连接次数",
                             value: info.logIn.map { "\($0)" } ?? "—")
                    StatCell(title: "GGA总数",
                             value: info.ggaCount.map { "\($0)" } ?? "—")
                    StatCell(title: "无效GGA",
                             value: info.invalidGga.map { "\($0)" } ?? "—")
                    StatCell(title: "平均卫星数",
                             value: info.avgSatNum.map { String(format: "%.1f", $0) } ?? "—")
                    StatCell(title: "平均延迟",
                             value: info.avgDelay.map { String(format: "%.1fms", $0) } ?? "—")
                    StatCell(title: "固定率", value: info.fixed ?? "—")
                    StatCell(title: "浮点率", value: info.floated ?? "—")
                }
            } else {
                Text("暂无统计数据").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - TimelineCard

private struct TimelineCard: View {
    let segments: [StatusSegment]

    private var totalMs: Double {
        segments.compactMap { $0.timeLength }.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("在线时间轴").font(.subheadline.bold())

            // 色块时间轴
            GeometryReader { geo in
                HStack(spacing: 1) {
                    ForEach(segments) { seg in
                        let w = totalMs > 0 ? max(2, (seg.timeLength ?? 0) / totalMs * geo.size.width) : 2
                        Rectangle()
                            .fill(seg.online == true ? Color.green : Color.secondary.opacity(0.25))
                            .frame(width: w, height: 32)
                            .cornerRadius(2)
                    }
                }
            }
            .frame(height: 32)

            // 图例
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.green).frame(width: 16, height: 10)
                    Text("在线").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.25)).frame(width: 16, height: 10)
                    Text("离线").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(segments.count) 段").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - WarnListCard

private struct WarnListCard: View {
    let warnData: WarnPageData?
    let page: Int
    let onPageChange: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("连接记录").font(.subheadline.bold())
                Spacer()
                if let total = warnData?.total {
                    Text("共 \(total) 条").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let records = warnData?.records, !records.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.offset) { _, r in
                        WarnRow(record: r)
                        if r.id != records.last?.id {
                            Divider().padding(.leading, 36)
                        }
                    }
                }

                // 分页
                let total = warnData?.pages ?? 1
                if total > 1 {
                    HStack {
                        Button { onPageChange(page - 1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(page <= 1)
                        .buttonStyle(.borderless)

                        Spacer()
                        Text("\(page) / \(total)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()

                        Button { onPageChange(page + 1) } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(page >= total)
                        .buttonStyle(.borderless)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text(warnData == nil ? "加载中..." : "暂无连接记录")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

private struct WarnRow: View {
    let record: WarnRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 26, height: 26)
                .background(iconColor.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(eventName)
                        .font(.subheadline.bold())
                        .foregroundStyle(iconColor)
                    Spacer()
                    if let t = record.createTime {
                        Text(String.fromMillisDetailed(t))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if let ip = record.ip {
                    let portStr = record.port.map { ":\($0)" } ?? ""
                    Text("IP: \(ip)\(portStr)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let mp = record.mountPoint, !mp.isEmpty {
                    Text("挂载点: \(mp)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var eventName: String {
        record.event ?? record.content ?? "未知事件"
    }

    private var iconName: String {
        let e = record.event ?? ""
        if e.contains("上线") { return "arrow.up.circle.fill" }
        if e.contains("下线") { return "arrow.down.circle.fill" }
        if e.contains("认证") { return "exclamationmark.triangle.fill" }
        if e.contains("踢") || e.contains("断") { return "xmark.circle.fill" }
        if e.contains("GGA") || e.contains("无效") { return "location.slash.fill" }
        return "info.circle.fill"
    }

    private var iconColor: Color {
        let e = record.event ?? ""
        if e.contains("上线") { return .green }
        if e.contains("下线") { return .secondary }
        if e.contains("认证") || e.contains("踢") || e.contains("无效") { return .orange }
        return .blue
    }
}

// MARK: - StateListCard (横向滚动表格)

private struct StateListCard: View {
    let states: [StatePoint]

    private let colWidths: [CGFloat] = [150, 80, 80, 90]
    private let headers = ["时间", "GGA状态", "卫星数", "差分延迟(ms)"]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GGA详情").font(.subheadline.bold())
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(spacing: 0) {
                    // 表头
                    HStack(spacing: 0) {
                        ForEach(Array(headers.enumerated()), id: \.offset) { i, h in
                            Text(h)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: colWidths[i], alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 4)
                        }
                    }
                    .background(Color.secondary.opacity(0.08))

                    Divider()

                    // 数据行
                    ForEach(Array(states.prefix(100).enumerated()), id: \.offset) { idx, s in
                        HStack(spacing: 0) {
                            Text(s.createTime.map { String.fromMillisDetailed($0) } ?? "—")
                                .frame(width: colWidths[0], alignment: .leading)
                            Text(ggaStateLabel(s.state))
                                .foregroundStyle(ggaStateColor(s.state))
                                .frame(width: colWidths[1], alignment: .leading)
                            Text(s.satNum.map { "\($0)" } ?? "—")
                                .frame(width: colWidths[2], alignment: .leading)
                            Text(s.delay.map { String(format: "%.0f", $0) } ?? "—")
                                .frame(width: colWidths[3], alignment: .leading)
                        }
                        .font(.caption)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                        .background(idx % 2 == 0 ? Color.clear : Color.secondary.opacity(0.04))

                        if idx < states.prefix(100).count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func ggaStateLabel(_ s: Int?) -> String {
        switch s {
        case 1: return "单点"
        case 2: return "差分"
        case 4: return "固定"
        case 5: return "浮点"
        default: return s.map { "\($0)" } ?? "—"
        }
    }

    private func ggaStateColor(_ s: Int?) -> Color {
        switch s {
        case 4: return .green
        case 5: return .blue
        case 2: return .orange
        default: return .secondary
        }
    }
}

// MARK: - SectionHeader / DiagRow helpers

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.caption.bold())
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)
    }
}

private struct DiagRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    init(label: String, value: String) where Content == Text {
        self.label = label
        self.content = { Text(value).font(.subheadline) }
    }

    init(label: String, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.content = content
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            content()
        }
        .padding(.vertical, 3)
    }
}

// MARK: - AccountStatusBadge

private struct AccountStatusBadge: View {
    let status: Int
    var body: some View {
        Text(label)
            .font(.caption2)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
    private var label: String {
        switch status { case 0: return "服务中"; case 1: return "未激活"; case 2: return "已到期"; default: return "未知" }
    }
    private var color: Color {
        switch status { case 0: return .green; case 1: return .orange; case 2: return .red; default: return .secondary }
    }
}

// MARK: - String extension

extension String {
    static func fromMillisDetailed(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: Double(ms) / 1000)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "MM-dd HH:mm:ss"
        return fmt.string(from: date)
    }
}
