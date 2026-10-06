//
//  TabViewOne.swift
//  kfn8
//
//  Created by coder on 6/17/21.
//


import SwiftUI
import MapKit


struct TabViewOne: View {
    @State private var region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 51.507222, longitude: -0.1275), span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Text("")
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
    
}

#if DEBUG

struct TabViewOne_Previews: PreviewProvider {
    static var previews: some View {
        TabViewOne()
    }
}

#endif



