//
//  TodoApp_kuzeApp.swift
//  TodoApp_kuze
//
//  Created by 久世晃暢 on 2025/10/20.
//

import SwiftUI
import AppTrackingTransparency

@main
struct TodoApp_kuzeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: requestTrackingAuthorizationIfNeeded)
        }
    }

    private func requestTrackingAuthorizationIfNeeded() {
        guard #available(iOS 14, *),
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { status in
                print("[ATT] Authorization status: \(status.rawValue)")
            }
        }
    }
}
