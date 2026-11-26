import Flutter
import FlutterPluginRegistrant
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let engineGroup = FlutterEngineGroup(name: "neocharts", project: nil)
    lazy var chartEngine: FlutterEngine = engineGroup.makeEngine(withEntrypoint: nil, libraryURI: nil)
    private(set) var bridge: NeoChartsBridge!

    // The chart while it's on screen, so the `onClose` call (which arrives
    // on the engine, not a view controller) can dismiss it.
    weak var activeChartVC: FlutterViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [
            UIApplication.LaunchOptionsKey: Any
        ]?
    ) -> Bool {
        // Runs the SDK's `main()` (NativeChartRoot) early and wires the bridge to it.
        chartEngine.run()
        GeneratedPluginRegistrant.register(with: chartEngine)
        bridge = NeoChartsBridge(
            messenger: chartEngine.binaryMessenger,
            data: MockDataSource(),
            // Set in the Xcode scheme's Run environment; unset shows the licence error screen.
            homeKey: ProcessInfo.processInfo.environment["NEOCHARTS_HOME_KEY"],
            onClose: { [weak self] in self?.activeChartVC?.dismiss(animated: true) }
        )
        return true
    }
}
