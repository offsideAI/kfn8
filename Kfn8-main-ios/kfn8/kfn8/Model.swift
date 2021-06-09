//
//  Model.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import UIKit
import RealityKit
import Combine

enum ModelCategory: CaseIterable {
    case uno
    case dos
    case tres
    case quatro
    
    var label: String {
        get {
            switch self {
            case .uno:
                return "Uno"
            case .dos:
                return "Dos"
            case .tres:
                return "Tres"
            case .quatro:
                return "Quatro"
                
            }
        }
    }
}

class Model {
    var modelName: String
    var image: UIImage
    var modelEntity: ModelEntity?
    var category: ModelCategory
    var scaleCompensation: Float
    
    private var cancellable: AnyCancellable? = nil
    
    init(modelName: String, category: ModelCategory, scaleCompensation: Float = 1.0) {
        self.modelName = modelName
        self.category = category
        self.image = UIImage(named: modelName) ?? UIImage(systemName: "photo")!
        self.scaleCompensation = scaleCompensation
        
        let filename = modelName + ".usdz"
        
        
        
        self.cancellable = ModelEntity.loadModelAsync(named: filename)
            .sink(receiveCompletion: { loadCompletion in
                // Handle our error
                print("Unable to load modelEntity for modelName: \(self.modelName)")
            }, receiveValue: { modelEntity in
                // Get our modelEntity
                self.modelEntity = modelEntity
                print("Successfully loaded modelEntity for modelName: \(self.modelName)")
            })
        
    }
    // TODO-FIXME-DEBUG : Create a method to async load modelEntity
    
}


struct Models {
    var all: [Model] = []
    
    init() {
        // Uno
        let uno1 = Model(modelName: "chair_swan", category: .uno, scaleCompensation: 0.32/100)
        let uno2 = Model(modelName: "cup_saucer_set", category: .uno, scaleCompensation: 0.32/100)
        let uno3 = Model(modelName: "fender_stratocaster", category: .uno, scaleCompensation: 0.32/100)
        self.all += [uno1, uno2, uno3]
        
        // Dos
        let dos1 = Model(modelName: "flower_tulip", category: .uno, scaleCompensation: 0.32/100)
        let dos2 = Model(modelName: "gramophone", category: .uno, scaleCompensation: 0.32/100)
        let dos3 = Model(modelName: "pot_plant", category: .uno, scaleCompensation: 0.32/100)
        let dos4 = Model(modelName: "teapot", category: .uno, scaleCompensation: 0.32/100)
        self.all += [dos1, dos2, dos3, dos4]
        
        // Tres
        let tres1 = Model(modelName: "toy_biplane", category: .uno, scaleCompensation: 0.32/100)
        let tres2 = Model(modelName: "tv_retro", category: .uno, scaleCompensation: 0.32/100)
        self.all += [tres1, tres2]
        
        // Quatros
        let quatros1 = Model(modelName: "wateringcan", category: .uno, scaleCompensation: 0.32/100)
        let quatros2 = Model(modelName: "wheelbarrow", category: .uno, scaleCompensation: 0.32/100)
        self.all += [quatros1, quatros2]
    }
    
    func get(category: ModelCategory) -> [Model] {
        return all.filter( {$0.category == category})
    }
    
    func getAll() -> [Model] {
        return all
    }
}

