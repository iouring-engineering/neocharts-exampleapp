import Flutter
import SwiftUI
import UIKit

class ViewController: UIViewController {
    // A tap while a mount is in flight is ignored.
    private var opening = false

    override func viewDidLoad() {
        super.viewDidLoad()

        let landing = LandingView(onOpenChart: { [weak self] dark in self?.openChart(dark: dark) })
        let hosting = UIHostingController(rootView: landing)

        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    private var appDelegate: AppDelegate {
        UIApplication.shared.delegate as! AppDelegate
    }

    /// Mounts the chart (retrying while the engine starts), then shows it.
    private func openChart(dark: Bool) {
        guard !opening, presentedViewController == nil else { return }
        opening = true
        appDelegate.bridge.mount(themeJson: themeJson(dark: dark)) { [weak self] _ in
            guard let self else { return }
            self.opening = false
            // Shown even when the mount failed: a failed init shows the SDK error view.
            self.present(self.makeChartVC(), animated: true)
        }
    }

    private func makeChartVC() -> ChartViewController {
        let vc = ChartViewController(engine: appDelegate.chartEngine, nibName: nil, bundle: nil)
        vc.modalPresentationStyle = .fullScreen
        let bridge = appDelegate.bridge
        vc.onDismiss = { bridge?.unmount() }
        appDelegate.activeChartVC = vc
        return vc
    }

    /// The landing page's brightness plus demo brand colours; see the theming docs for all tokens.
    private func themeJson(dark: Bool) -> String {
        let demo = ["primary": "#7B1FA2", "onPrimary": "#FFFFFF", "bullish": "#26A69A", "bearish": "#EF5350"]
        let theme: Row = ["brightness": dark ? "dark" : "light", "colors": ["light": demo, "dark": demo]]
        return (try? JSON.string(theme)) ?? "null"
    }
}

/// The chart; leaving it (onClose's dismiss) unmounts. That runs as the
/// dismissal starts, before the card can be tapped again, so no remount race.
final class ChartViewController: FlutterViewController {
    var onDismiss: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Assumes .fullScreen: a sheet's cancelled swipe would also read as dismissed.
        if isBeingDismissed { onDismiss?() }
    }
}
