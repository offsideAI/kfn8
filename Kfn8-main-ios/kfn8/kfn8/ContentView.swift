//
//  ContentView.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import SwiftUI
import RealityKit
import ARKit

struct ContentView : View {
    @State private var isControlPanelEnabled = false
    @State private var selectedModel: String?
    @State private var modelConfirmedForPlacement: String?
    
    private var models: [String] = {
        // Dynamically get filenames
        let filemanager = FileManager.default
        guard let path = Bundle.main.resourcePath,
              let files = try? filemanager.contentsOfDirectory(atPath: path) else {
            return []
        }
        var availableModels: [String] = []
        for filename in files where
            filename.hasSuffix("usdz") {
            let modelName = filename.replacingOccurrences(of: ".usdz", with: "")
            availableModels.append(modelName)
        }
        return availableModels
    }()
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer(modelConfirmedForPlacement: self.$modelConfirmedForPlacement).edgesIgnoringSafeArea(.all)
            if self.isControlPanelEnabled {
                ControlPanelView(isControlPanelEnabled: $isControlPanelEnabled, selectedModel: $selectedModel, modelConfirmedForPlacement: $modelConfirmedForPlacement)
            } else {
                ModelPickerView(isControlPanelEnabled: $isControlPanelEnabled, selectedModel: $selectedModel, models: models)
            }
            

        }
        .navigationBarBackButtonHidden(true)
        // return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    @Binding var modelConfirmedForPlacement: String?
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
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
        if let modelName = self.modelConfirmedForPlacement {
            print("DEBUG: adding model to scene \(modelName)")
            
            let filename = modelName + ".usdz"
            
            let modelEntity = try! ModelEntity.loadModel(named: filename)
            
            let anchorEntity = AnchorEntity(plane: .any)
            /*
            anchorEntity.addChild(modelEntity)
            uiView.scene.addAnchor(anchorEntity)
            */
            
            DispatchQueue.main.async {
                self.modelConfirmedForPlacement = nil
            }
            
        }
    }
    
}

struct ModelPickerView: View {
    @Binding var isControlPanelEnabled: Bool
    @Binding var selectedModel: String?
    var models: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count) {
                    index in
                    // Text(self.models[index])
                    Button(action: {
                        print("Selected model with name: \(self.models[index])")
                        self.selectedModel = self.models[index]
                        self.isControlPanelEnabled = true
                        
                    }) {
                        if let uiImage = UIImage(named: self.models[index]) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(height:80)
                                .aspectRatio(1/1, contentMode: .fit)
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                        
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.black.opacity(0.5))
    }
}

struct ControlPanelView: View {
    @Binding var isControlPanelEnabled: Bool
    @Binding var selectedModel: String?
    @Binding var modelConfirmedForPlacement: String?
    
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
    }
    func resetControlParameters() {
        self.isControlPanelEnabled = false
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
