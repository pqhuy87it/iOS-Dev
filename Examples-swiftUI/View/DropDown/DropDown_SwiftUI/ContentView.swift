//
//  ContentView.swift
//  DropDown_SwiftUI
//
//  Created by Immature Inc on 02/03/2020.
//  Copyright © 2020 AnthonyDesignCode. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Menus")
                .font(.largeTitle)
            Text("Let's create a Drop Down Menu")
                .font(.title)
                .layoutPriority(1)
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(LinearGradient(gradient: .init(colors: [.blue, .purple]), startPoint: .top, endPoint: .bottom))
                .foregroundColor(.white)
            Text("We are going to create a drop down menu with buttons, background Color with a shadow then we are going to place this menu on the leading side of our View.")
                .font(.title)
                .layoutPriority(1)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(gradient: .init(colors: [.blue, .purple]), startPoint: .top, endPoint: .bottom))
                .foregroundColor(.white)
            VStack(){
                HStack {
                    Spacer()
                    DropDown()
                    Spacer()
                }
                .padding(.leading, -240)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct DropDown: View {
    
    @State var expand = false
    
    var body: some View {
        VStack() {
            Spacer()
            VStack(spacing: 30) {
                HStack() {
                    Text("Menu")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Image(systemName: expand ? "chevron.up" : "chevron.down")
                        .resizable()
                        .frame(width: 13, height: 6)
                        .foregroundColor(.white)
                }.onTapGesture {
                    self.expand.toggle()
                }
                if expand {
                    Button(action: {
                        self.expand.toggle()
                    }) {
                        Text("Profile")
                            .padding(10)
                    }.foregroundColor(.white)
                    Button(action: {
                        self.expand.toggle()
                    }) {
                        Text("Settings")
                            .padding(10)
                    }.foregroundColor(.white)
                    Button(action: {
                        self.expand.toggle()
                    }) {
                        Text("Sign out")
                            .padding(10)
                    }.foregroundColor(.white)
                }
            }
            .padding()
            .background(LinearGradient(gradient: .init(colors: [.blue, .purple]), startPoint: .top, endPoint: .bottom))
            .cornerRadius(15)
            .shadow(color: .gray, radius: 5)
            .animation(.spring())
        }
    }
}
