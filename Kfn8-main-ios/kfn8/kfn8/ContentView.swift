//
//  ContentView.swift
//  kfn8
//
//  Created by coder on 6/3/21.
//

import SwiftUI
import RealityKit

struct ContentView : View {
    var body: some View {
        Text("Hello World")
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
