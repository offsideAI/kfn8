//
//  PlacementSettings.swift
//  kfn8
//
//  Created by coder on 6/9/21.
//

import SwiftUI
import RealityKit
import Combine

class PlacementSettings: ObservableObject {
    
    @Published var currentSelectedModel: Model? {
        willSet(newValue) {
            print("Setting currentSelectedModel to \(String(describing: newValue?.modelName))")
        }
    }
    
    @Published var confirmedCurrentModel: Model? {
        willSet(newValue) {
            guard let model = newValue else {
                print("Clearing confirmedModel")
                return
            }
            print("Setting confirmedModel to \(model.modelName)")
        }
    }
}
