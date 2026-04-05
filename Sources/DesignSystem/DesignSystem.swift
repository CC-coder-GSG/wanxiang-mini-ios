import SwiftUI

// MARK: - Colors

extension Color {
    static let appPrimary = Color.primary
    static let appCard = Color(UIColor.secondarySystemBackground)
    static let appBackground = Color(UIColor.systemGroupedBackground)
    static let appDivider = Color(UIColor.separator)
}

// MARK: - Card

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

// MARK: - Primary Button

struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDestructive ? Color.red : Color.primary)
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.appDivider, lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(UIColor.systemBackground)))
            )
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Section Header

struct SectionTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.bottom, 4)
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let dismiss = onDismiss {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}

// MARK: - Date Formatter Helpers

extension String {
    /// Format millisecond timestamp to readable string
    static func fromMillis(_ ms: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        return DateFormatter.display.string(from: date)
    }
}

extension DateFormatter {
    static let display: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let iso8601ms: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}

// MARK: - Days until deadline

func daysUntil(_ dateString: String) -> Int? {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    guard let date = df.date(from: dateString) else { return nil }
    return Calendar.current.dateComponents([.day], from: .now, to: date).day
}

func isoString(daysFromNow days: Int) -> String {
    let date = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
    return DateFormatter.iso8601ms.string(from: date)
}

func deadlineString(daysFromNow days: Int) -> String {
    let date = Calendar.current.date(byAdding: .day, value: days + 1, to: .now) ?? .now
    return DateFormatter.display.string(from: date)
}
