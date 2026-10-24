import XCTest
import CoreImage

@MainActor
final class RemoteDisplayPairingUITests: ScoreboardUITestCase {
    func testScanRequiresPairingAndHandlesCameraDenied() {
        // Resetting a previously denied permission can terminate the app.
        app.resetAuthorizationStatus(for: .camera)
        launch()
        openRemoteDisplaySettings()
        let scan = mainWindow.buttons["Scan to Pair"].firstMatch
        reveal(scan)
        XCTAssertFalse(scan.isEnabled)
        tap(mainWindow.switches["settings.toggle.Enable Remote Display / Control Pairing"])
        tap(scan)
        let permission = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        if permission.waitForExistence(timeout: 5) {
            let deny = permission.buttons["Don’t Allow"]
            if deny.exists { deny.tap() }
            else { permission.buttons.firstMatch.tap() }
        }
        let error = app.staticTexts["remote.scan.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Cancel"].isHittable)
        // Simulators without a camera report unavailable instead of prompting.
        XCTAssertTrue(error.label.contains("camera") || error.label.contains("Camera"))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(mainWindow.staticTexts["settings.title.remoteDisplay"].waitForExistence(timeout: 5))
    }

    func testPairingQRStaysReachableInPortraitAndLandscape() throws {
        launch()
        openRemoteDisplaySettings()
        tap(mainWindow.buttons["Enter"].firstMatch)
        let qr = app.images["remote.pairingQR"]
        XCTAssertTrue(qr.waitForExistence(timeout: 10))
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            rotate(to: orientation)
            waitUntil("QR size must settle after rotation") { qr.frame.width >= 90 }
            reveal(qr)
            XCTAssertTrue(qr.isHittable)
            XCTAssertGreaterThanOrEqual(qr.frame.width, 90)
            XCTAssertTrue(mainWindow.frame.contains(qr.frame), "The entire QR code must fit on screen")
            let screenshot = mainWindow.screenshot()
            XCTAssertTrue(try pairingPayload(in: screenshot).hasPrefix("smartscoreboard://pair?"),
                          "The QR must decode from the actual rendered screen")
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Remote Display QR pairing \(orientation.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testPairedDisplayActionsRemainReachable() throws {
        launch("remote")
        let qr = app.images["remote.pairingQR"]
        XCTAssertTrue(qr.waitForExistence(timeout: 10))
        reveal(qr)
        let payload = try pairingPayload(in: mainWindow.screenshot())
        let items = try XCTUnwrap(URLComponents(string: payload)?.queryItems)
        let displayID = try XCTUnwrap(items.first { $0.name == "display" }?.value)
        let code = try XCTUnwrap(items.first { $0.name == "code" }?.value)
        let operatorPeer = RemoteDisplayOperatorPeer()
        defer { operatorPeer.stop() }
        operatorPeer.pair(displayID: displayID, code: code)
        let disconnect = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Disconnect'")).firstMatch
        XCTAssertTrue(disconnect.waitForExistence(timeout: 20), "A real pairing must expose Disconnect")
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            rotate(to: orientation)
            for control in [disconnect, app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Forget Paired Devices'")).firstMatch] {
                reveal(control)
                XCTAssertTrue(control.isHittable)
                XCTAssertTrue(mainWindow.frame.contains(control.frame), "Paired-device actions must stay inside the visible window")
            }
            let screenshot = XCTAttachment(screenshot: mainWindow.screenshot())
            screenshot.name = "Paired Remote Display controls \(orientation.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    private func pairingPayload(in screenshot: XCUIScreenshot) throws -> String {
        let image = try XCTUnwrap(screenshot.image.cgImage)
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode,
            context: CIContext(options: [.useSoftwareRenderer: true]),
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        return try XCTUnwrap(detector.features(in: CIImage(cgImage: image))
            .compactMap { ($0 as? CIQRCodeFeature)?.messageString }
            .first { $0.hasPrefix("smartscoreboard://pair?") })
    }

    private func rotate(to orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        waitUntil("The window must finish rotating") {
            let frame = self.mainWindow.frame
            return (frame.height > frame.width) == (orientation == .portrait)
        }
    }
}
