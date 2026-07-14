import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerOcrChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// Native OCR backed by Apple's Vision framework (VNRecognizeTextRequest).
  ///
  /// Dart side: MethodChannel('fr.benoitfontaine.second_brain/ocr')
  ///   .invokeMethod<String>('recognize', {'path': imagePath, 'languages': ['fr-FR', 'en-US']})
  private func registerOcrChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fr.benoitfontaine.second_brain/ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String
      else {
        result(FlutterError(
          code: "BAD_ARGS",
          message: "Expected arguments {path: String, languages: [String]?}",
          details: nil))
        return
      }
      let languages = args["languages"] as? [String] ?? ["fr-FR", "en-US"]
      DispatchQueue.global(qos: .userInitiated).async {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        if #available(macOS 13.0, *) {
          request.automaticallyDetectsLanguage = true
        }
        let handler = VNImageRequestHandler(url: URL(fileURLWithPath: path), options: [:])
        do {
          try handler.perform([request])
          // One line of output per recognized text observation, top candidate only.
          let text = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
          DispatchQueue.main.async { result(text) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "OCR_FAILED",
              message: error.localizedDescription,
              details: nil))
          }
        }
      }
    }
  }
}
