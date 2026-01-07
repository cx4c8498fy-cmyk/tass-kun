import Foundation
import GoogleMobileAds
import UIKit

final class InterstitialAd: NSObject, GADFullScreenContentDelegate, ObservableObject {
    private let adUnitID: String
    private var interstitial: GADInterstitialAd?
    @Published private(set) var isReady: Bool = false

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
    }

    func load() {
        let request = GADRequest()
        GADInterstitialAd.load(withAdUnitID: adUnitID, request: request) { [weak self] ad, error in
            if let error = error {
                print("[AdMob] Interstitial failed to load: \(error.localizedDescription)")
                self?.isReady = false
                return
            }
            self?.interstitial = ad
            self?.interstitial?.fullScreenContentDelegate = self
            self?.isReady = true
            print("[AdMob] Interstitial loaded.")
        }
    }

    func show(from viewController: UIViewController?) {
        guard let interstitial = interstitial, let viewController = viewController else {
            print("[AdMob] Interstitial not ready.")
            return
        }
        interstitial.present(fromRootViewController: viewController)
        isReady = false
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first { $0.isKeyWindow }?
            .rootViewController
    }

    func showIfReady() {
        show(from: rootViewController())
    }

    // MARK: - GADFullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("[AdMob] Interstitial dismissed.")
        load()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdMob] Interstitial failed to present: \(error.localizedDescription)")
        load()
    }
}
