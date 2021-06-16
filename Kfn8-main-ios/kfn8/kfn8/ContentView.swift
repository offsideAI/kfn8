//
//  ContentView.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import SwiftUI
import RealityKit
import ARKit
import FocusEntity

struct ContentView : View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var placementSettings: PlacementSettings
    @State private var isPlacementPanelEnabled = false
    @State private var modelConfirmedForPlacement: Model?
    @State private var isControlsVisible: Bool = true
    @State private var isBrowseShown: Bool = false
    @State private var isSettingsShown: Bool = false


    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement).edgesIgnoringSafeArea(.all)

            ModelPickerView(isPlacementPanelEnabled: $isPlacementPanelEnabled, items: Models().all)

            if self.placementSettings.currentSelectedModel == nil {
                ControlView(isControlsVisible: $isControlsVisible, isBrowseShown: $isBrowseShown, isSettingsShown: $isSettingsShown)
            } else {
                PlacementPanelView(isPlacementPanelEnabled: $isPlacementPanelEnabled, modelConfirmedForPlacement: $modelConfirmedForPlacement)
            }
            

        }
        .navigationBarBackButtonHidden(true)
        // return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
  @EnvironmentObject var placementSettings: PlacementSettings
  @EnvironmentObject var sessionSettings: SessionSettings
  @Binding var modelConfirmedForPlacement: Model?
  func makeUIView(context: Context) -> CustomARView {
      
    // TODO-FIXME-DEBUG-DEPRECATE let arView = CustomARView(frame: .zero)
    let arView = CustomARView(frame: .zero, sessionSettings: sessionSettings)
    // Subscribe to SceneEvents.Update
    self.placementSettings.sceneObserver = arView.scene.subscribe(to: SceneEvents.Update.self, { (event) in
        // Call updateScene method
        self.updateScene(for: arView)
    })

    return arView
      
  }
    
  func updateUIView(_ uiView: CustomARView, context: Context) {
    if let model = self.modelConfirmedForPlacement {
        if let modelEntity = model.modelEntity {
            print("DEBUG: adding model to scene \(model.modelName)")
            
            let anchorEntity = AnchorEntity(plane: .any)
            anchorEntity.addChild(modelEntity.clone(recursive: true))
            uiView.scene.addAnchor(anchorEntity)
            
        } else {
            print("DEBUG: Unable to load modelEntity for \(model.modelName)")
        }
        
        
        DispatchQueue.main.async {
            self.modelConfirmedForPlacement = nil
        }
        
    }
  }

  private func updateScene(for arView: CustomARView) {
      // Only display focusEntity wen the user has selected a model for placement
      arView.focusEntity?.isEnabled = self.placementSettings.currentSelectedModel != nil
      
      // Add model to scene if confirmed for placement
      if let currentConfirmedModel = self.placementSettings.currentConfirmedModel, let modelEntity = currentConfirmedModel.modelEntity {
          // Call place method
          self.place(modelEntity, in: arView)
          // Reset confirmed model
          self.placementSettings.currentConfirmedModel = nil
      }
  }
    
  private func place(_ modelEntity: ModelEntity, in arView: ARView) {
      // 1. Clone modeleEntity. This creates an identical copy of modelEntity and references the same model.
      // This also allows us to have multiple models of the same asset in our scene
      let clonedEntity = modelEntity.clone(recursive: true)
      // 2. Enable translation and rotation gestures
      clonedEntity.generateCollisionShapes(recursive: true)
      arView.installGestures([.translation, .rotation], for: clonedEntity)
      // 3. Create an anchorEntity and add clonedEntity to the anchorEntity
      let anchorEntity = AnchorEntity(plane: .any)
      anchorEntity.addChild(clonedEntity)
      // 4. Add the anchorEntity to the arView scene
      arView.scene.addAnchor(anchorEntity)
      print("Added modelEntity to scene")
      
  }
}


#if DEBUG

struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PlacementSettings())
            .environmentObject(SessionSettings())
    }
}

#endif
