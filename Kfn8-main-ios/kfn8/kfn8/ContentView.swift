//
//  ContentView.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import SwiftUI
import RealityKit

struct ContentView : View {
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
            ARViewContainer().edgesIgnoringSafeArea(.all)
            ModelPickerView(models: models)
        }
        .navigationBarBackButtonHidden(true)
        // return ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    
    func makeUIView(context: Context) -> ARView {
        
        let arView = ARView(frame: .zero)
    
        
        return arView
        
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
    
}

struct ModelPickerView: View {
    var models: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators:false) {
            HStack(spacing: 30) {
                ForEach(0 ..< self.models.count) {
                    index in
                    // Text(self.models[index])
                    Button(action: {
                        print("Selected model with name: \(self.models[index])")
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

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
