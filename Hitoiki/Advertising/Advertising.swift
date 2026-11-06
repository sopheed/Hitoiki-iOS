import Combine
import GoogleMobileAds
import SwiftUI
import UserMessagingPlatform

@MainActor
final class Advertising: ObservableObject {
    static let shared = Advertising()
    @Published private(set) var canShowBanner = false
    @Published private(set) var privacyOptionsRequired = false
    @Published var privacyError: String?
    private var preparing = false
    private var updatedConsent = false
    private var startedSDK = false

    func prepare() async {
        guard AdvertisingConfiguration.enabled else { return }
        while preparing {
            do { try await Task.sleep(nanoseconds: 100_000_000) }
            catch { return }
        }
        guard !Task.isCancelled else { return }
        preparing = true
        defer { preparing = false }

        if !updatedConsent {
            let parameters = RequestParameters()
            parameters.isTaggedForUnderAgeOfConsent = AdvertisingConfiguration.childDirected
            let error: Error? = await withCheckedContinuation { continuation in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                    continuation.resume(returning: error)
                }
            }
            #if DEBUG
            if let error { print("[Ads] Consent update failed: \(error.localizedDescription)") }
            #endif
            guard !Task.isCancelled else { return }
            if error == nil {
                do {
                    try await ConsentForm.loadAndPresentIfRequired(from: nil)
                    updatedConsent = true
                } catch {
                    #if DEBUG
                    print("[Ads] Consent form unavailable: \(error.localizedDescription)")
                    #endif
                    // The app remains fully usable if consent cannot be obtained.
                }
            }
        }
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }

        if !startedSDK {
            // Keep Google's processing restricted without requiring an opt-out first.
            UserDefaults.standard.set(true, forKey: "gad_rdp")
            let configuration = MobileAds.shared.requestConfiguration
            configuration.publisherPrivacyPersonalizationState = .disabled
            configuration.coarseLocationCollectionEnabled = false
            configuration.setPublisherFirstPartyIDEnabled(false)
            configuration.maxAdContentRating = .general
            if AdvertisingConfiguration.childDirected {
                configuration.ageRestrictedTreatment = .child
            }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                MobileAds.shared.start { _ in continuation.resume() }
            }
            startedSDK = true
        }
        canShowBanner = true
        #if DEBUG
        print("[Ads] SDK ready; using Google demo banners")
        #endif
    }

    func showPrivacyOptions() async {
        guard privacyOptionsRequired, !preparing else { return }
        preparing = true
        canShowBanner = false
        defer {
            preparing = false
            canShowBanner = startedSDK && ConsentInformation.shared.canRequestAds
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        }
        do { try await ConsentForm.presentPrivacyOptionsForm(from: nil) }
        catch { privacyError = "広告のプライバシー設定を開けませんでした。通信状況を確認して、もう一度お試しください。" }
    }
}

/// Lives inside a page's safe area or at the end of its content, never over controls.
/// Empty/error responses collapse the slot; they do not block any app feature.
struct AdBannerPlacement: View {
    var isVisible = true
    @ObservedObject private var advertising = Advertising.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var loadedHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            if isVisible && scenePhase == .active {
                if AdvertisingConfiguration.layoutPreview {
                    VStack(spacing: 4) {
                        Text("広告").font(.system(size: 10)).foregroundStyle(.secondary)
                        Text("テスト広告・レイアウト確認用")
                            .font(.footnote).frame(maxWidth: .infinity).frame(height: 50)
                            .background(Color(.tertiarySystemFill))
                    }
                    .padding(.top, 16).padding(.bottom, 8)
                    .accessibilityIdentifier("advertising.preview")
                } else if advertising.canShowBanner {
                    GeometryReader { geometry in
                        VStack(spacing: 4) {
                            Text("広告").font(.system(size: 10)).foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            BannerContainer(width: min(600, geometry.size.width)) { height in
                                loadedHeight = height
                            }
                        }
                        .padding(.top, 16).padding(.bottom, 8)
                    }
                    .frame(height: loadedHeight > 0 ? loadedHeight + 40 : 0)
                    .clipped()
                    .background(Color(.systemBackground))
                    .accessibilityIdentifier("advertising.banner")
                }
            }
        }
        .task(id: "\(isVisible)-\(scenePhase == .active)") {
            guard isVisible && scenePhase == .active else { return }
            // Let startup stories, return checks and input sheets settle first.
            do { try await Task.sleep(nanoseconds: 600_000_000) }
            catch { return }
            await advertising.prepare()
        }
        .onChange(of: isVisible) { visible in
            if !visible { loadedHeight = 0 }
        }
        .onDisappear { loadedHeight = 0 }
    }
}

private struct BannerContainer: UIViewControllerRepresentable {
    let width: CGFloat
    let onHeightChange: (CGFloat) -> Void

    func makeUIViewController(context: Context) -> BannerController {
        BannerController(width: width, onHeightChange: onHeightChange)
    }
    func updateUIViewController(_ controller: BannerController, context: Context) {
        controller.update(width: width)
    }
    static func dismantleUIViewController(_ controller: BannerController, coordinator: ()) {
        controller.removeBanner()
    }
}

private final class BannerController: UIViewController, BannerViewDelegate {
    private var banner: BannerView?
    private var requestedWidth: CGFloat = 0
    private var availableWidth: CGFloat
    private var visible = false
    private let onHeightChange: (CGFloat) -> Void

    init(width: CGFloat, onHeightChange: @escaping (CGFloat) -> Void) {
        availableWidth = width
        self.onHeightChange = onHeightChange
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        visible = true
        loadIfNeeded()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        visible = false
        removeBanner()
    }
    func update(width: CGFloat) {
        availableWidth = width
        loadIfNeeded()
    }
    func removeBanner() {
        banner?.delegate = nil
        banner?.removeFromSuperview()
        banner = nil
        requestedWidth = 0
    }
    private func reportHeight(_ height: CGFloat) {
        DispatchQueue.main.async { [weak self] in self?.onHeightChange(height) }
    }
    private func loadIfNeeded() {
        let width = floor(availableWidth)
        guard visible, width >= 320, abs(requestedWidth - width) > 1 else { return }
        removeBanner()
        reportHeight(0)
        requestedWidth = width
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdvertisingConfiguration.bannerID
        banner.rootViewController = self
        banner.delegate = self
        banner.alpha = 0
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.banner = banner
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        banner.load(request)
    }
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        guard bannerView === banner else { return }
        bannerView.alpha = 1
        reportHeight(bannerView.adSize.size.height)
        #if DEBUG
        print("[Ads] Banner received")
        #endif
    }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        guard bannerView === banner else { return }
        bannerView.alpha = 0
        reportHeight(0)
        #if DEBUG
        print("[Ads] Banner unavailable: \(error.localizedDescription)")
        #endif
    }
}

struct AdvertisingPrivacySection: View {
    @ObservedObject private var advertising = Advertising.shared
    var body: some View {
        Section {
            Text("一部の画面にGoogle AdMobのバナー広告を表示します。パーソナライズ広告と広告のための位置情報収集は無効にしています。アプリ内の記録や写真を広告へ渡すことはありません。")
                .font(.footnote).foregroundStyle(.secondary)
            if advertising.privacyOptionsRequired {
                Button("広告のプライバシー設定") {
                    Task { await advertising.showPrivacyOptions() }
                }
                .accessibilityIdentifier("advertising.privacyOptions")
            }
            Link("プライバシーポリシー", destination: URL(string: "https://sopheed.com/apps/#privacy")!)
        } header: { Text("広告とプライバシー") }
        .alert("広告のプライバシー設定", isPresented: Binding(
            get: { advertising.privacyError != nil },
            set: { if !$0 { advertising.privacyError = nil } }
        )) { Button("閉じる", role: .cancel) { advertising.privacyError = nil } }
        message: { Text(advertising.privacyError ?? "") }
    }
}
