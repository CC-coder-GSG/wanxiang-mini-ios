import SwiftUI
import SwiftData

struct RegisterLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RegisterHistory.operateTime, order: .reverse) private var history: [RegisterHistory]

    private let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            if history.isEmpty {
                ContentUnavailableView("暂无注册记录", systemImage: "clock.arrow.circlepath")
            } else {
                List {
                    ForEach(history) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item.sn)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(df.string(from: item.operateTime))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let rt = item.registerTime {
                                Label("注册时间: \(df.string(from: rt))", systemImage: "checkmark.circle")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                            if let et = item.extendTime {
                                Label("延期时间: \(df.string(from: et))", systemImage: "calendar.badge.plus")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.appCard)
                    }
                    .onDelete(perform: deleteItems)
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("注册日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for idx in offsets {
            modelContext.delete(history[idx])
        }
        try? modelContext.save()
    }
}

#Preview("注册日志") {
    NavigationStack {
        RegisterLogView()
    }
    .modelContainer(LocalStore.shared.container)
}
