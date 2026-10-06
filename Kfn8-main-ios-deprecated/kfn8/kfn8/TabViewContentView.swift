//
//  TabViewContentView.swift
//  kfn8
//
//  Created by coder on 6/17/21.
//

import Foundation
import SwiftUI


struct TabViewContentView: View {
    var body: some View {
        TabView {
            TabViewOne()
                .tabItem { Text("First")}
                .tag(1)
            
            TabViewTwo()
                .tabItem { Text("One")}
                .tag(2)
        }
    }
    
}

#if DEBUG

struct TabViewContentView_Previews: PreviewProvider {
    static var previews: some View {
        TabViewContentView()
    }
}

#endif



