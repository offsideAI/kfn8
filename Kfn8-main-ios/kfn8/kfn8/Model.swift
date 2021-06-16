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
    
    private var cancellable: AnyCancellable?
    
    init(modelName: String, category: ModelCategory, scaleCompensation: Float = 1.0) {
        self.modelName = modelName
        self.category = category
        self.image = UIImage(named: modelName) ?? UIImage(systemName: "photo")!
        self.scaleCompensation = scaleCompensation
        
        let filename = modelName + ".usdz"
        
        
        
        self.cancellable = ModelEntity.loadModelAsync(named: filename)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .failure:
                  print("ApiCall failed.")
                    print("Unable to load modelEntity for modelName: \(self.modelName)")
                case .finished:
                  print("ApiCall finished.")
                }
            }, receiveValue: { modelEntity in
                // Get our modelEntity
                self.modelEntity = modelEntity
                print("Successfully loaded modelEntity for modelName: \(self.modelName)")
            })
        
    }
    // Create a method to async load modelEntity
    func asyncLoadModelEntity() {
        let filename = self.modelName + ".usdz"
        
        self.cancellable = ModelEntity.loadModelAsync(named: filename)
            .sink(receiveCompletion: { loadCompletion in
                switch loadCompletion {
                case .failure(let error): print("Unable to load modelEntity for \(filename) Error: \(error.localizedDescription)")
                    
                case .finished:
                    break
                }
            }, receiveValue: { modelEntity in
                self.modelEntity = modelEntity
                self.modelEntity?.scale *= self.scaleCompensation
                
                print("modelEntity for \(self.modelName) has been loaded")
    
            })
    }
    
}


struct Models {
    var all: [Model] = []
    
    init() {
        // Uno
        let uno0 = Model(modelName: "hipster", category: .uno, scaleCompensation: 50.0/100)
        let uno1 = Model(modelName: "chair_swan", category: .uno, scaleCompensation: 50.0/100)
        let uno2 = Model(modelName: "cup_saucer_set", category: .uno, scaleCompensation: 50.0/100)
        let uno3 = Model(modelName: "fender_stratocaster", category: .uno, scaleCompensation: 50.0/100)
        
        self.all += [uno0, uno1, uno2, uno3]
        
        // Dos
        let dos1 = Model(modelName: "flower_tulip", category: .dos, scaleCompensation: 50.0/100)
        let dos2 = Model(modelName: "gramophone", category: .dos, scaleCompensation: 50.0/100)
        let dos3 = Model(modelName: "pot_plant", category: .dos, scaleCompensation: 50.0/100)
        let dos4 = Model(modelName: "teapot", category: .dos, scaleCompensation: 50.0/100)
        self.all += [dos1, dos2, dos3, dos4]
        
        // Tres
        let tres1 = Model(modelName: "toy_biplane", category: .tres, scaleCompensation: 50.0/100)
        let tres2 = Model(modelName: "tv_retro", category: .tres, scaleCompensation: 50.0/100)
        self.all += [tres1, tres2]
        
        // Quatros
        let quatros1 = Model(modelName: "wateringcan", category: .quatro, scaleCompensation: 50.0/100)
        let quatros2 = Model(modelName: "wheelbarrow", category: .quatro, scaleCompensation: 50.0/100)
        self.all += [quatros1, quatros2]
    }
    
    func get(category: ModelCategory) -> [Model] {
        return all.filter( {$0.category == category})
    }
    
    func getAll() -> [Model] {
        return all
    }
}

