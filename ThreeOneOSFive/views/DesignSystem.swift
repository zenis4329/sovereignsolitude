import SwiftUI
import UIKit

// MARK: - Appearance

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var titleKey: String {
        switch self {
        case .system: return "theme.appearance.system"
        case .light: return "theme.appearance.light"
        case .dark: return "theme.appearance.dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Spectral accent

enum AppAccentSpectrum: String, CaseIterable, Identifiable {
    case crimson
    case coral
    case amber
    case gold
    case lime
    case emerald
    case teal
    case cyan
    case azure
    case indigo
    case violet
    case magenta

    var id: String { rawValue }

    /// Hue on the spectrum ring (0...1), red → violet → magenta.
    var spectrumPosition: Double {
        switch self {
        case .crimson: return 0.00
        case .coral: return 0.06
        case .amber: return 0.10
        case .gold: return 0.14
        case .lime: return 0.22
        case .emerald: return 0.33
        case .teal: return 0.45
        case .cyan: return 0.52
        case .azure: return 0.58
        case .indigo: return 0.68
        case .violet: return 0.78
        case .magenta: return 0.90
        }
    }

    var titleKey: String { "theme.accent.\(rawValue)" }

    var color: Color {
        Color(hue: spectrumPosition, saturation: 0.78, brightness: 0.96)
    }

    var deepColor: Color {
        Color(hue: spectrumPosition, saturation: 0.86, brightness: 0.72)
    }

    var softColor: Color {
        Color(hue: spectrumPosition, saturation: 0.42, brightness: 0.98)
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: spectrumPosition, saturation: 0.70, brightness: 1.0),
                Color(hue: min(spectrumPosition + 0.08, 1.0), saturation: 0.82, brightness: 0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func nearest(to position: Double) -> AppAccentSpectrum {
        allCases.min(by: {
            abs($0.spectrumPosition - position) < abs($1.spectrumPosition - position)
        }) ?? .azure
    }
}

// MARK: - Theme preferences (persisted)

enum AppThemePreferences {
    static let appearanceStorageKey = "theme.appearance"
    static let accentStorageKey = "theme.accent.spectrum"
    static let spectrumSliderStorageKey = "theme.accent.spectrum.position"

    static var defaultAppearance: AppAppearanceMode { .system }
    static var defaultAccent: AppAccentSpectrum { .azure }
}

// MARK: - Semantic colors

enum AppTheme {
    static var accent: Color {
        let raw = UserDefaults.standard.string(forKey: AppThemePreferences.accentStorageKey)
            ?? AppThemePreferences.defaultAccent.rawValue
        return (AppAccentSpectrum(rawValue: raw) ?? .azure).color
    }

    static var accentDeep: Color {
        let raw = UserDefaults.standard.string(forKey: AppThemePreferences.accentStorageKey)
            ?? AppThemePreferences.defaultAccent.rawValue
        return (AppAccentSpectrum(rawValue: raw) ?? .azure).deepColor
    }

    static var accentSoft: Color {
        let raw = UserDefaults.standard.string(forKey: AppThemePreferences.accentStorageKey)
            ?? AppThemePreferences.defaultAccent.rawValue
        return (AppAccentSpectrum(rawValue: raw) ?? .azure).softColor
    }

    static var accentGradient: LinearGradient {
        let raw = UserDefaults.standard.string(forKey: AppThemePreferences.accentStorageKey)
            ?? AppThemePreferences.defaultAccent.rawValue
        return (AppAccentSpectrum(rawValue: raw) ?? .azure).gradient
    }

    static let canvas = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.06, green: 0.07, blue: 0.10, alpha: 1)
                : UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1)
        }
    )

    static let elevated = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.11, green: 0.12, blue: 0.16, alpha: 1)
                : UIColor.white
        }
    )

    static let elevatedSecondary = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.16, blue: 0.21, alpha: 1)
                : UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
        }
    )

    static let hairline = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor.white.withAlphaComponent(0.10)
                : UIColor.black.withAlphaComponent(0.08)
        }
    )

    static let label = Color.primary
    static let secondaryLabel = Color.secondary

    static let success = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.20)
    static let danger = Color(red: 1.00, green: 0.35, blue: 0.35)

    // Compatibility aliases for existing views
    static var pageBackground: Color { canvas }
    static var consoleBackground: Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 1)
                    : UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
            }
        )
    }
    static let pageInset: CGFloat = 16
    static let emptyIconSize: CGFloat = 44
    static let selectionIconSize: CGFloat = 22
    static let rowIconSize: CGFloat = 18
    static let appIconSize: CGFloat = 40
    static let fileRowHeight: CGFloat = 52
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 34
    static let cornerRadius: CGFloat = 16
    static let cardCornerRadius: CGFloat = 20
    static let compactIconSize: CGFloat = 16
    static let mediumIconSize: CGFloat = 20
    static let largeIconSize: CGFloat = 28
    static let controlHeight: CGFloat = 44
    static let listRowVerticalPadding: CGFloat = 8


    static let spectrumGradient = AngularGradient(
        gradient: Gradient(colors: [
            Color(hue: 0.00, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.08, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.16, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.33, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.50, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.66, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.75, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.83, saturation: 0.85, brightness: 1.0),
            Color(hue: 0.00, saturation: 0.85, brightness: 1.0)
        ]),
        center: .center
    )
}

// MARK: - Shared chrome

struct AppSearchField: View {
    @Binding var text: String
    var prompt: String
    var clearLabel: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(clearLabel))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(AppTheme.elevatedSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(prompt))
    }
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = 32

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.14))
                .frame(width: frameSize, height: frameSize)

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

struct AppLogo: View {
    var size: CGFloat = 54

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(AppTheme.accentGradient)
                .frame(width: size, height: size)
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, y: 6)

            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
        }
        .accessibilityHidden(true)
    }
}

private enum RemoteImageMemoryCache {
    static let images = NSCache<NSURL, UIImage>()
}

struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { Image(uiImage: image).resizable() }
            else { placeholder() }
        }
        .task(id: url) {
            guard let url else { image = nil; return }
            if let cached = RemoteImageMemoryCache.images.object(forKey: url as NSURL) {
                image = cached
                return
            }
            var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
            request.setValue("image/*", forHTTPHeaderField: "Accept")
            guard let (data, response) = try? await URLSession.shared.data(for: request),
                  let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  let decoded = UIImage(data: data) else { return }
            RemoteImageMemoryCache.images.setObject(decoded, forKey: url as NSURL)
            image = decoded
        }
    }
}

struct ApexCardModifier: ViewModifier {
    var padding: CGFloat = 16
    @ObservedObject private var catalog = GameCatalogStore.shared

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.elevated.opacity(catalog.catalog.resolvedCardOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 14, y: 6)
            )
    }
}

extension View {
    func apexCard(padding: CGFloat = 16) -> some View {
        modifier(ApexCardModifier(padding: padding))
    }

    func apexScreenBackground() -> some View {
        // Keep screens translucent so remote image/video wallpaper (App root) shows through.
        background(Color.clear)
    }
}

struct SpectrumAccentPicker: View {
    @Binding var selection: AppAccentSpectrum
    @Binding var sliderPosition: Double
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(language.text("theme.accent.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // Continuous spectrum slider
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: AppAccentSpectrum.allCases.map(\.color),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 18)
                            .overlay(
                                Capsule()
                                    .stroke(AppTheme.hairline, lineWidth: 1)
                            )

                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                            .overlay(
                                Circle()
                                    .fill(selection.color)
                                    .padding(5)
                            )
                            .overlay(
                                Circle().stroke(AppTheme.hairline, lineWidth: 1)
                            )
                            .offset(x: thumbX(in: geo.size.width) - 14)
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let width = max(geo.size.width, 1)
                                let p = min(max(value.location.x / width, 0), 1)
                                sliderPosition = p
                                selection = AppAccentSpectrum.nearest(to: p)
                            }
                    )
                }
                .frame(height: 28)

                Text(language.text(selection.titleKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selection.color)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Discrete spectrum chips
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(AppAccentSpectrum.allCases) { accent in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selection = accent
                            sliderPosition = accent.spectrumPosition
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(accent.gradient)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(selection == accent ? 0.95 : 0.25), lineWidth: selection == accent ? 3 : 1)
                                )
                                .shadow(color: accent.color.opacity(selection == accent ? 0.45 : 0.15), radius: selection == accent ? 8 : 3, y: 2)

                            if selection == accent {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.text(accent.titleKey))
                }
            }
        }
        .apexCard()
    }

    private func thumbX(in width: CGFloat) -> CGFloat {
        CGFloat(sliderPosition) * width
    }
}

struct AppearanceModePicker: View {
    @Binding var selection: AppAppearanceMode
    @Environment(\.appLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("theme.appearance.title"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(AppAppearanceMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            selection = mode
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                            Text(language.text(mode.titleKey))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(selection == mode ? Color.white : Color.primary)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selection == mode ? AnyShapeStyle(AppTheme.accentGradient) : AnyShapeStyle(AppTheme.elevatedSecondary))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selection == mode ? Color.clear : AppTheme.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .apexCard()
    }
}

struct StatusBadge: View {
    let text: String
    let tone: Tone

    enum Tone {
        case neutral, success, warning, danger, accent

        var color: Color {
            switch self {
            case .neutral: return .secondary
            case .success: return AppTheme.success
            case .warning: return AppTheme.warning
            case .danger: return AppTheme.danger
            case .accent: return AppTheme.accent
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(tone.color)
            .background(tone.color.opacity(0.14), in: Capsule())
    }
}
