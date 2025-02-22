//
//  COREHelpWindowSceneDelegate.swift
//  
//
//  Created by Steven Troughton-Smith on 03/01/2023.
//

import UIKit
import AppleUniversalCore

open class COREHelpWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
	public var window: UIWindow?

	public let helpRootController = COREHelpRootViewController()
	
	open func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let scene = scene as? UIWindowScene else { return }
		window = UIWindow(windowScene: scene)
		guard let window = window else { return }
		
        if let langageCode = Locale.current.languageCode,
           let helpResource = Bundle.main.url(forResource: "Help_\(langageCode)", withExtension: "help") {
            helpRootController.helpBundle = HelpBundle(url: helpResource)
        } else {
            helpRootController.helpBundle = HelpBundle(url: Bundle.main.url(forResource: "Help", withExtension: "help")!)
        }
		
		window.tintColor = .systemPurple
		
#if targetEnvironment(macCatalyst)

		let toolbar = NSToolbar()
		toolbar.delegate = self
		scene.titlebar?.toolbar = toolbar
		scene.titlebar?.toolbarStyle = .unifiedCompact
	
#endif
		
		window.rootViewController = helpRootController
		window.makeKeyAndVisible()
	}
	
}
