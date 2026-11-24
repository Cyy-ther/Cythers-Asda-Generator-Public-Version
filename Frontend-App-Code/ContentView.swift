import SwiftUI
import AVFoundation
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @State private var prefix = ""
    @State private var ean = ""
    @State private var price = ""
    @State private var storeID = ""

    @State private var breakdownLines: [(String, String, Bool)] = []
    @State private var fullBarcode = ""
    @State private var errorText = ""
    @State private var barcodeImage: UIImage?

    @State private var isShowingScanner = false
    @State private var savedConfirmation = false

    private let context = CIContext()
    private let filter = CIFilter.code128BarcodeGenerator()
    private let asdaGreen = Color(red: 120/255, green: 190/255, blue: 32/255)
    private let bgDark = Color(red: 13/255, green: 17/255, blue: 14/255)
    private let cardDark = Color(red: 22/255, green: 27/255, blue: 23/255)

    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 4) {
                        Text("ASDA")
                            .font(.system(size: 54, weight: .black))
                            .foregroundStyle(asdaGreen)
                        Text("barcode gen")
                            .font(.system(size: 18, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(.white)
                        Text("Made By Cyy-ther")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.top, 2)
                    }
                    .padding(.top, 12)

                    // Input Card
                    VStack(alignment: .leading, spacing: 14) {
                        inputField(title: "Header Prefix (3 digits)-c_icon_ID:", text: $prefix, placeholder: "e.g. 510")

                        // Product Barcode Input + Camera Scan Button
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Product EAN-13 Barcode (up to 13 digits):")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 205/255))

                            HStack(spacing: 8) {
                                TextField("e.g. 5000118047817", text: $ean)
                                    .keyboardType(.numberPad)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundStyle(asdaGreen)
                                    .padding(10)
                                    .background(bgDark)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color(red: 43/255, green: 56/255, blue: 45/255), lineWidth: 1)
                                    )

                                Button(action: { isShowingScanner = true }) {
                                    Image(systemName: "barcode.viewfinder")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(bgDark)
                                        .frame(width: 44, height: 42)
                                        .background(asdaGreen)
                                        .cornerRadius(4)
                                }
                                .accessibilityLabel("Scan Product Barcode")
                            }
                        }

                        inputField(title: "Price Markdown in Pence (5 digits):", text: $price, placeholder: "e.g. 00025")
                        inputField(title: "Store ID (4 digits, blank = 6416):", text: $storeID, placeholder: "e.g. 6416")

                        HStack(spacing: 12) {
                            Button(action: generate) {
                                Text("Generate")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(asdaGreen)
                                    .foregroundStyle(bgDark)
                                    .cornerRadius(6)
                            }

                            Button(action: reset) {
                                Text("Restart")
                                    .font(.system(size: 16, weight: .semibold))
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 18)
                                    .background(Color(red: 30/255, green: 38/255, blue: 32/255))
                                    .foregroundStyle(.white)
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 4)

                        if !errorText.isEmpty {
                            Text(errorText)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }

                        // Breakdown Output
                        if !breakdownLines.isEmpty {
                            Divider().background(Color.gray.opacity(0.3))

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Barcode Breakdown")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundStyle(asdaGreen)

                                ForEach(breakdownLines, id: \.0) { label, value, isHighlight in
                                    Text("\(label): \(value)")
                                        .font(.system(size: 13, weight: isHighlight ? .bold : .regular, design: .monospaced))
                                        .foregroundStyle(isHighlight ? asdaGreen : Color.white.opacity(0.9))
                                        .textSelection(.enabled)
                                }
                            }
                        }

                        // White Code 128 Barcode Card + Save to Camera Roll
                        if let image = barcodeImage {
                            VStack(spacing: 10) {
                                VStack(spacing: 6) {
                                    Image(uiImage: image)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 90)

                                    Text(fullBarcode)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black)
                                        .textSelection(.enabled)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 12)
                                .background(Color.white)
                                .cornerRadius(6)

                                Button(action: saveBarcodeToPhotos) {
                                    HStack(spacing: 6) {
                                        Image(systemName: savedConfirmation ? "checkmark.circle.fill" : "square.and.arrow.down")
                                        Text(savedConfirmation ? "Saved to Photos" : "Save to Camera Roll")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(savedConfirmation ? asdaGreen : Color(red: 30/255, green: 38/255, blue: 32/255))
                                    .foregroundStyle(savedConfirmation ? bgDark : .white)
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(18)
                    .background(cardDark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 43/255, green: 56/255, blue: 45/255), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerSheet(asdaGreen: asdaGreen, bgDark: bgDark) { scannedCode in
                let digitsOnly = scannedCode.filter(\.isNumber)
                ean = String(digitsOnly.prefix(13))
                isShowingScanner = false
            }
        }
    }

    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color(red: 203/255, green: 213/255, blue: 205/255))

            TextField(placeholder, text: text)
                .keyboardType(.numberPad)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(asdaGreen)
                .padding(10)
                .background(bgDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 43/255, green: 56/255, blue: 45/255), lineWidth: 1)
                )
        }
    }

    private func generate() {
        savedConfirmation = false
        var result = BarcodeResult()
        let ok = build_asda_barcode(prefix, ean, price, storeID, &result)

        if ok == 1 {
            errorText = ""
            let pfx = withUnsafePointer(to: result.prefix) { $0.withMemoryRebound(to: CChar.self, capacity: 4) { String(cString: $0) } }
            let eanStr = withUnsafePointer(to: result.ean) { $0.withMemoryRebound(to: CChar.self, capacity: 14) { String(cString: $0) } }
            let prc = withUnsafePointer(to: result.price) { $0.withMemoryRebound(to: CChar.self, capacity: 6) { String(cString: $0) } }
            let str = withUnsafePointer(to: result.store) { $0.withMemoryRebound(to: CChar.self, capacity: 5) { String(cString: $0) } }
            let pay = withUnsafePointer(to: result.payload) { $0.withMemoryRebound(to: CChar.self, capacity: 26) { String(cString: $0) } }
            let full = withUnsafePointer(to: result.full_barcode) { $0.withMemoryRebound(to: CChar.self, capacity: 27) { String(cString: $0) } }

            fullBarcode = full
            breakdownLines = [
                ("Header Prefix", pfx, false),
                ("Product EAN-13", eanStr, false),
                ("Price in Pence", prc, false),
                ("Store ID", str, false),
                ("25-digit Payload", pay, false),
                ("Luhn Check Digit", "\(result.check_digit)", false),
                ("Complete 26-digit Barcode", full, true)
            ]
            barcodeImage = renderCode128(from: full)
        } else {
            barcodeImage = nil
            breakdownLines = []
            fullBarcode = ""
            errorText = withUnsafePointer(to: result.error) { $0.withMemoryRebound(to: CChar.self, capacity: 128) { String(cString: $0) } }
        }
    }

    private func reset() {
        prefix = ""
        ean = ""
        price = ""
        storeID = ""
        breakdownLines = []
        fullBarcode = ""
        errorText = ""
        barcodeImage = nil
        savedConfirmation = false
    }

    private func renderCode128(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.quietSpace = 10
        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    @MainActor
    private func saveBarcodeToPhotos() {
        guard let rawBars = barcodeImage, !fullBarcode.isEmpty else { return }

        let exportView = VStack(spacing: 12) {
            Image(uiImage: rawBars)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 680, height: 180)

            Text(fullBarcode)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 28)
        .background(Color.white)

        let renderer = ImageRenderer(content: exportView)
        renderer.scale = 2.0

        if let finalImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(finalImage, nil, nil, nil)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            savedConfirmation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                savedConfirmation = false
            }
        }
    }
}

// MARK: - Native AVFoundation Universal 1D Barcode Scanner
struct BarcodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let asdaGreen: Color
    let bgDark: Color
    let onCodeScanned: (String) -> Void

    var body: some View {
        ZStack {
            bgDark.ignoresSafeArea()

            CameraPreview(onCodeScanned: onCodeScanned)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                            .padding()
                    }
                }

                Spacer()

                RoundedRectangle(cornerRadius: 12)
                    .stroke(asdaGreen, lineWidth: 3)
                    .frame(width: 290, height: 150)
                    .background(Color.black.opacity(0.1))

                Text("Align product barcode inside frame")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .padding(.top, 14)

                Spacer()
            }
        }
    }
}

struct CameraPreview: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.onCodeScanned = onCodeScanned
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCodeScanned: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [
                .ean13,
                .ean8,
                .upce,
                .code128,
                .code39,
                .code39Mod43,
                .code93,
                .interleaved2of5,
                .itf14,
                .codabar,
                .gs1DataBar,
                .gs1DataBarExpanded,
                .gs1DataBarLimited
            ]
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue else {
            return
        }

        let digitsOnly = value.filter(\.isNumber)
        guard !digitsOnly.isEmpty else { return }

        hasScanned = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        session.stopRunning()
        onCodeScanned?(digitsOnly)
    }
}
