//
//  TabViewOne.swift
//  kfn8
//
//  Created by coder on 6/17/21.
//

import Foundation
import SwiftUI


struct TabViewOne: View {
    var body: some View {
        
        NavigationView {
            Text("Welcome")
            NavigationLink(destination:
                            DetailViewOne(),
                           label: {
                            Text("Go to Detail")
                                .bold()
                                .frame(width: 280, height: 50, alignment: .center)
                                .background(Color.blue)
                                .foregroundColor(Color.white)
                                .cornerRadius(10)
                                .padding(10)
                           }
            )
        }
    }
    
}

#if DEBUG

struct TabViewOne_Previews: PreviewProvider {
    static var previews: some View {
        TabViewOne()
    }
}

#endif



