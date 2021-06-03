//
//  Model.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import UIKit
import RealityKit
import Combine

class Model {
    var modelName: String
    var image: UIImage
    var modelEntity: ModelEntity?
    
    private var cancellable: AnyCancellable? = nil
    
    init(modelName: String) {
        self.modelName = modelName
        self.image = UIImage(named: modelName)!
        
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
    
    
}
