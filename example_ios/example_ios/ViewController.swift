import Flutter
import UIKit

class ViewController: UIViewController {
    @IBAction func openChart(_ sender: Any) {
        present(makeFlutterVC(engine: appDelegate.chartEngine), animated: true)
    }

    @IBAction func openScalper(_ sender: Any) {
        present(makeFlutterVC(engine: appDelegate.chartEngine), animated: true)
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
