import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  var textureController: TextureController!

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.textureController = TextureController.init(
      flutterViewController: flutterViewController
    )

    super.awakeFromNib()
  }
}
