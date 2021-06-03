//
//  ContentView.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var models: [String] = ["tv_retro", "fender_stratocaster", "wateringcan", "toy_car", "chair_swan", "wheelbarrow", "flower_tulip", "teapot", "cup_saucer_set", "pot_plant", "gramophone", "toy_biplane", "toy_robot_vintage"]
    var body: some View {
        ZStack(alignment: .bottom) {
            ARViewContainer().edgesIgnoringSafeArea(.all)
            ScrollView(.horizontal, showsIndicators:false) {
                HStack(spacing: 30) {
                    ForEach(0 ..< self.models.count) {
                        index in
                        Text(self.models[index])
                    }
                }
            }
            
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

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif
