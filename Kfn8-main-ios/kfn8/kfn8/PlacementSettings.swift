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
    // When the user selects a model in BrowseView, currentSelectedModel property is set
    @Published var currentSelectedModel: Model? {
        willSet(newValue) {
            print("Setting currentSelectedModel to \(String(describing: newValue?.modelName))")
        }
    }
    
    // When the user taps confirm in PlacementView, the value of currentSelectedModel is assigned to currentConfirmedModel
    @Published var currentConfirmedModel: Model? {
        willSet(newValue) {
            guard let model = newValue else {
                print("Clearing confirmedModel")
                return
            }
            print("Setting confirmedModel to \(model.modelName)")
        }
    }
    
    // This property retains the cancellable object for SceneEvents.Update subscriber
    var sceneObserver: Cancellable?
    
}
