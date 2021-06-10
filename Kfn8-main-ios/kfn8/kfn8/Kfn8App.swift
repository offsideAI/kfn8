//
//  Kfn8App.swift
//  kfn8
//
//  Created by coder on 6/10/21.
//

import SwiftUI

@main
struct Kfn8App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // perform any task on app launch
        print("Kfn8App init called")
    }
    var body: some Scene {
        WindowGroup {
            LoginView(choice: "ContentView")
        }
    }
}
