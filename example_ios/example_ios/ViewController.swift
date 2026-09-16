import Flutter
import SwiftUI
import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let landing = LandingView(onOpenChart: { [weak self] in
            guard let self else { return }
            self.present(self.makeFlutterVC(engine: self.appDelegate.chartEngine), animated: true)
        })
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

    private func makeFlutterVC(engine: FlutterEngine) -> FlutterViewController {
        let vc = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        vc.modalPresentationStyle = .fullScreen
        appDelegate.activeChartVC = vc
        return vc
    }
}
