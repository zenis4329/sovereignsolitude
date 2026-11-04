import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var ambientMedia = AmbientMediaController.shared
    @AppStorage(AmbientMediaController.userMusicEnabledKey) private var userMusicEnabled = true

    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @AppStorage(AppThemePreferences.appearanceStorageKey) private var appearanceRaw = AppThemePreferences.defaultAppearance.rawValue
    @AppStorage(AppThemePreferences.accentStorageKey) private var accentRaw = AppThemePreferences.defaultAccent.rawValue
    @AppStorage(AppThemePreferences.spectrumSliderStorageKey) private var spectrumPosition = AppThemePreferences.defaultAccent.spectrumPosition

    private var appearanceBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { AppAppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    private var accentBinding: Binding<AppAccentSpectrum> {
        Binding(
            get: { AppAccentSpectrum(rawValue: accentRaw) ?? .azure },
            set: { accentRaw = $0.rawValue }
        )
    }

    private var spectrumBinding: Binding<Double> {
        Binding(
            get: { spectrumPosition },
            set: { spectrumPosition = $0 }
        )
    }

    private var accent: AppAccentSpectrum {
        AppAccentSpectrum(rawValue: accentRaw) ?? .azure
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    AppearanceModePicker(selection: appearanceBinding)
                    SpectrumAccentPicker(
                        selection: accentBinding,
                        sliderPosition: spectrumBinding
                    )
                    languageCard
                    musicCard
                    statusCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .apexScreenBackground()
            .navigationTitle(language.text("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language.text("common.done")) { dismiss() }
                }
            }
            .tint(accent.color)
        }
    }

    // MARK: Cards

    private var profileCard: some View {
        HStack(spacing: 14) {
            AppLogo(size: 58)
            VStack(alignment: .leading, spacing: 4) {
                Text("HMT IPA PRX")
                    .font(.title3.weight(.bold))
                Text(appVersion)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(language.text("settings.about_blurb"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .apexCard()
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(language.text("settings.language"), systemImage: "globe")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)

            Picker(language.text("settings.language"), selection: $languageCode) {
                ForEach(AppLanguage.allCases) { option in
                    Text(option.displayName).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .apexCard()
    }

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(language.text("settings.music"), systemImage: "music.note")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)

            Toggle(isOn: $userMusicEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.text("settings.music_toggle"))
                        .font(.body.weight(.semibold))
                    Text(language.text("settings.music_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: userMusicEnabled) { enabled in
                ambientMedia.isUserMusicEnabled = enabled
            }

            if GameCatalogStore.shared.catalog.resolvedMusicEnabled {
                Text(
                    ambientMedia.isMusicPlaying
                        ? language.text("settings.music_playing")
                        : language.text("settings.music_ready")
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text(language.text("settings.music_server_off"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .apexCard()
        .onAppear {
            // Keep controller in sync with AppStorage.
            ambientMedia.isUserMusicEnabled = userMusicEnabled
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(language.text("settings.support"), systemImage: "shield.lefthalf.filled")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)

            row(language.text("settings.ios_version"), "\(AppInfo.osVersion) (\(AppInfo.osBuild))")
            Divider().opacity(0.45)
            HStack {
                Text(language.text("settings.compatibility"))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(
                    text: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                    tone: appState.isSupported ? .success : .danger
                )
            }
            Divider().opacity(0.45)
            HStack {
                Text(language.text("settings.exploit_status"))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(
                    text: language.text(appState.exploitStatus.isSuccess ? "settings.ready" : "settings.not_ready"),
                    tone: appState.exploitStatus.isSuccess ? .success : .warning
                )
            }

            Divider().opacity(0.45)
            VStack(alignment: .leading, spacing: 8) {
                Text(language.text("settings.verified_versions"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowWrap(items: verifiedVersionChips) { version in
                    Text(version)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(accent.softColor.opacity(0.55), in: Capsule())
                        .overlay(Capsule().stroke(accent.color.opacity(0.25), lineWidth: 1))
                }
            }

            Text(language.text("settings.supported_range_summary"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .apexCard()
    }

    private var verifiedVersionChips: [String] {
        [
            "iOS 17 · \(ExploitSupportPolicy.verifiedIOS17Range)",
            "iOS 18 · \(ExploitSupportPolicy.verifiedIOS18Range)",
            "iOS 26 · \(ExploitSupportPolicy.verifiedIOS26Range)"
        ] + ExploitSupportPolicy.verifiedIOS27Builds.map { "iOS 27 · \($0.build)" }
    }

    private var socialCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(language.text("settings.social_media"), systemImage: "bubble.left.and.bubble.right.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)
                .padding(.bottom, 6)

            creditsRow(
                name: language.text("social.telegram_announce"),
                role: language.text("social.telegram_announce_role"),
                url: "https://t.me/apexproxyv1",
                icon: "megaphone.fill"
            )
            divider
            creditsRow(
                name: language.text("social.telegram_chat"),
                role: language.text("social.telegram_chat_role"),
                url: "https://t.me/apexproxyv1chat",
                icon: "paperplane.fill"
            )
            divider
            creditsRow(
                name: language.text("social.zalo_chat"),
                role: language.text("social.zalo_chat_role"),
                url: "https://zalo.me/g/gsl985njohn9jkco9sio",
                icon: "message.fill"
            )
        }
        .apexCard()
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(language.text("settings.credits"), systemImage: "star.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent.color)
                .padding(.bottom, 6)

            creditsRow(
                name: "HuuTien",
                role: language.text("credit.huutien"),
                url: "https://t.me/htios2590",
                icon: "person.crop.circle.fill"
            )
            divider
            creditsRow(
                name: "Kari",
                role: language.text("credit.kari"),
                url: "https://t.me/kariios9",
                icon: "hammer.fill"
            )
        }
        .apexCard()
    }

    private var divider: some View {
        Divider().opacity(0.4).padding(.vertical, 4)
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.weight(.semibold))
        }
    }

    private func creditsRow(name: String, role: String, url: String, icon: String) -> some View {
        Button {
            guard let link = URL(string: url) else { return }
            UIApplication.shared.open(link)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(role)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(language.text("accessibility.open_profile", name))
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        if let display = Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String {
            return "\(display) · \(short) (\(build))"
        }
        return "\(short) (\(build))"
    }
}

// Simple wrapping layout for version chips
private struct FlowWrap<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            generate(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, 8)
                    .padding(.bottom, 8)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { g in
                Color.clear.preference(key: HeightKey.self, value: g.size.height)
            }
        )
        .onPreferenceChange(HeightKey.self) { totalHeight = $0 }
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
