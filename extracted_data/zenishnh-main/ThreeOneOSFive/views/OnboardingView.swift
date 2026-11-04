import SwiftUI
import UIKit

/// First-launch only: choose language. Notices are handled separately by `NoticeBannerView`.
struct OnboardingView: View {
    // ĐÃ SỬA: Mặc định chọn sẵn Tiếng Việt
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    var onComplete: () -> Void

    private var language: AppLanguage { AppLanguage(rawValue: languageCode) ?? .vietnamese }

    var body: some View {
        ZStack {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                languagePage
                controls
            }
        }
        .tint(AppTheme.accent)
        .animation(.spring(response: 0.38, dampingFraction: 0.84), value: languageCode)
    }

    private var languagePage: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 12)
            AppLogo(size: 72)
            VStack(spacing: 8) {
                Text(language.text("onboarding.language_title"))
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(language.text("onboarding.language_subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 10) {
                ForEach(AppLanguage.allCases) { option in
                    Button {
                        languageCode = option.rawValue
                    } label: {
                        HStack(spacing: 12) {
                            Text(option.displayName)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if languageCode == option.rawValue {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.accent)
                                    .font(.title3)
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(languageCode == option.rawValue ? AppTheme.accent : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 12)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Text(language.text("onboarding.language_hint"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                OnboardingStore.markCompleted()
                onComplete()
            } label: {
                Text(language.text("common.finish"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)
            .controlSize(.large)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(.bar)
    }
}

// MARK: - Notice (every open, can hide 1 hour)

enum NoticeStore {
    private static let snoozeUntilKey = "notice.snoozeUntil"

    static var snoozeUntil: Date? {
        get {
            let ts = UserDefaults.standard.double(forKey: snoozeUntilKey)
            guard ts > 0 else { return nil }
            return Date(timeIntervalSince1970: ts)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: snoozeUntilKey)
            } else {
                UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
            }
        }
    }

    static var isSnoozed: Bool {
        guard let until = snoozeUntil else { return false }
        return until > Date()
    }

    static func hideForOneHour() {
        snoozeUntil = Date().addingTimeInterval(60 * 60)
    }

    static func clearSnooze() {
        snoozeUntil = nil
    }
}

/// Full-screen notice from website `config.json`. Shown on every open unless snoozed 1h.
struct NoticeBannerView: View {
    @Environment(\.appLanguage) private var language
    @ObservedObject private var catalog = GameCatalogStore.shared
    var onDismiss: () -> Void
    var onSnoozeOneHour: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accent.opacity(0.10))
                        .frame(width: 104, height: 104)
                        .blur(radius: 18)
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.accentGradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: AppTheme.accent.opacity(0.18), radius: 10, y: 4)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.top, 26)
                .padding(.bottom, 18)

                VStack(spacing: 9) {
                    Text(catalog.catalog.noticeTitle)
                        .font(.title2.weight(.black))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)

                    HStack(spacing: 7) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("THÔNG BÁO HỆ THỐNG")
                            .font(.caption2.weight(.bold))
                            .tracking(1.4)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)

                ScrollView(showsIndicators: false) {
                    Text(catalog.catalog.noticeMessage)
                        .font(.body)
                        .foregroundStyle(Color.primary.opacity(0.78))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxHeight: 210)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.primary.opacity(0.07)))
                .padding(.horizontal, 20)
                .padding(.top, 18)

                HStack(spacing: 10) {
                    Button {
                        onDismiss()
                    } label: {
                        Text(language.text("common.ok"))
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(AppTheme.accentGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .shadow(color: AppTheme.accent.opacity(0.28), radius: 12, y: 6)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onSnoozeOneHour()
                    } label: {
                        Label("HIDE FOR 1H", systemImage: "clock")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(LinearGradient(colors: [AppTheme.accent.opacity(0.65), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 36, y: 20)
            )
            .frame(maxWidth: 520)
            .padding(.horizontal, 22)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }
}

// MARK: - First-launch language gate
enum OnboardingStore {
    static let languageCompletedKey = "onboarding.languageCompleted"
    static let completedVersionKey = "onboarding.completedVersion"
    static let completedFingerprintKey = "onboarding.completedFingerprint"

    // ĐÃ SỬA: Ép App bỏ qua màn hình chọn ngôn ngữ (Luôn trả về false)
    static var shouldShowLanguagePicker: Bool {
        return false 
    }

    static func shouldShow() -> Bool {
        shouldShowLanguagePicker
    }

    static func markCompleted() {
        UserDefaults.standard.set(true, forKey: languageCompletedKey)
        UserDefaults.standard.set("language-only", forKey: completedVersionKey)
        UserDefaults.standard.set("language-only", forKey: completedFingerprintKey)
    }
}
