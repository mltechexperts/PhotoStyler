//
//  PhotoStylerApp.swift
//  PhotoStyler
//
//  Created by muralidhar lalagiri on 3/20/26.
//

import SwiftData
import SwiftUI

@main
struct PhotoStylerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: CapturedPhoto.self)
    }
}
