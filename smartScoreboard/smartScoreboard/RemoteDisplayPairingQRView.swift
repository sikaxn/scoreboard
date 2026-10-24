import SwiftUI
import CoreImage.CIFilterBuiltins

struct RemoteDisplayPairingQRView: View {
    let displayID: String
    let pairingCode: String
    let size: CGFloat

    private static let context = CIContext()

    var body: some View {
        if let image = makeImage() {
            Image(image, scale: 1, label: Text("Pairing QR Code"))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Pairing QR Code")
                .accessibilityIdentifier("remote.pairingQR")
        }
    }

    private func makeImage() -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(ScoreboardRemoteDisplayPairingCode(
            displayID: displayID, pairingCode: pairingCode
        ).encodedValue.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        return Self.context.createCGImage(output, from: output.extent)
    }
}
