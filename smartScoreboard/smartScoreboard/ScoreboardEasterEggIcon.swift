import Foundation

#if os(iOS)
import UIKit
#endif

#if !os(tvOS)
enum ScoreboardEasterEggIcon {
    static let userDefaultsKey = "scoreboardBunnyIconEnabled"
    static let defaultAssetName = "ScoreboardIcon"
    static let bunnyAssetName = "AuxScoreboardIcon"

    private static let alternateIconName = "AuxIcon"

    static func assetName(isBunnyEnabled: Bool) -> String {
        isBunnyEnabled ? bunnyAssetName : defaultAssetName
    }

    @MainActor
    static func applyPersistedSystemIcon() {
        applySystemIcon(isBunnyEnabled: UserDefaults.standard.bool(forKey: userDefaultsKey))
    }

    @MainActor
    static func applySystemIcon(isBunnyEnabled: Bool, completion: ((Error?) -> Void)? = nil) {
        #if os(iOS)
        let app = UIApplication.shared
        guard app.supportsAlternateIcons else {
            completion?(nil)
            return
        }

        let iconName = isBunnyEnabled ? alternateIconName : nil
        guard app.alternateIconName != iconName else {
            completion?(nil)
            return
        }

        app.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async {
                completion?(error)
            }
        }
        #else
        completion?(nil)
        #endif
    }
}
#endif
