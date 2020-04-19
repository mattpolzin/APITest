//
//  AppDelegate.swift
//  APITest
//
//  Created by Mathew Polzin on 4/8/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import UIKit
import ReSwift
import APIModels

let store = ReSwift.Store<AppState>(
    reducer: AppState.reducer,
    state: AppState(),
    middleware: [APIMiddlewareController().middleware]
)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        store.dispatch(API.WatchTests.start)
        store.dispatch(API.GetAllTests.request)

        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        store.dispatch(API.WatchTests.stop)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        store.dispatch(API.WatchTests.start)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        store.dispatch(API.WatchTests.stop)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

