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
    @State private var isPlacementPanelEnabled = false
    @State private var selectedModel: Model?
    @State private var modelConfirmedForPlacement: Model?
    @State private var isControlsVisible: Bool = true
    
    
    private var models: [Model] = {
        // Dynamically get filenames
        let filemanager = FileManager.default
        guard let path = Bundle.main.resourcePath,
              let files = try? filemanager.contentsOfDirectory(atPath: path) else {
            return []
        }
        var availableModels: [Model] = []
        for filename in files where
            filename.hasSuffix("usdz") {
            let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
            print("DEBUG:\(modelName)")
            let model = Model(modelName: modelName)
            availableModels.append(model)
        }
        return availableModels
    }()
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement).edgesIgnoringSafeArea(.all)
            if self.isPlacementPanelEnabled {
                PlacementPanelView(isPlacementPanelEnabled: $isPlacementPanelEnabled, selectedModel: $selectedModel, modelConfirmedForPlacement: $modelConfirmedForPlacement)
            } else {
                ModelPickerView(isPlacementPanelEnabled: $isPlacementPanelEnabled, selectedModel: $selectedModel, models: models)
            }
            
            ControlView(isControlsVisible: $isControlsVisible)

        }
        .navigationBarBackButtonHidden(true)
        // return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: Model?
    func makeUIView(context: Context) -> ARView {
        
        // let arView = ARView(frame: .zero)
        let arView = FocusARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        
        // Lidar support
        if ARWorldTrackingConfiguration
            .supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        
        arView.session.run(config)
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
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
    
}



struct ModelPickerView: View {
    @Binding var isPlacementPanelEnabled: Bool
    @Binding var selectedModel: Model?
    var models: [Model]
    var body: some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count) {
                    index in
                    // Text(self.models[index])
                    Button(action: {
                        print("Selected model with name: \(self.models[index].modelName)")
                        self.selectedModel = self.models[index]
                        self.isPlacementPanelEnabled = true
                        
                    }) {
                        Image(uiImage: self.models[index].image)
                                .resizable()
                                .frame(height:80)
                                .aspectRatio(1/1, contentMode: .fit)
                                .background(Color.white)
                                .cornerRadius(12)
                        
                        
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        // .padding(20)
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 130)
        .background(Color.black.opacity(0.5))
    }
}

struct PlacementPanelView: View {
    @Binding var isPlacementPanelEnabled: Bool
    @Binding var selectedModel: Model?
    @Binding var modelConfirmedForPlacement: Model?
    
    var body: some View {
        HStack {
            // Cancel Button
            Button(action: {
                print("Model placement cancel")
                self.resetControlParameters()
            }) {
                Image(systemName: "xmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
            // Confirm Button
            Button(action: {
                print("Model placement confirm")
                self.modelConfirmedForPlacement = self.selectedModel
                self.resetControlParameters()
            }) {
                Image(systemName: "checkmark")
                    .frame(width: 60, height: 60)
                    .font(.title)
                    .background(Color.white.opacity(0.75))
                    .cornerRadius(30)
                    .padding(20)
            }
        }
        .padding(.top, 20)
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.bottom, 130)
    }
    func resetControlParameters() {
        self.isPlacementPanelEnabled = false
        self.selectedModel = nil
    }
}



#if DEBUG

struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#endif
