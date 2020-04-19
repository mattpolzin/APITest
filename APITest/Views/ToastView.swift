//
//  ToastView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/18/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct ToastView: View, Identifiable {
    let id: Int
    let title: String
    let message: String
    let style: Toast.Content.Style

    init(content: Toast.Content) {
        id = content.id
        title = content.title
        message = content.message
        style = content.style
    }

    var body: some View {
        GeometryReader { geometry in
            HStack {
                VStack {
                    VStack {
                        Text(self.title).font(.title).padding(.bottom, 5)
                        Text(self.message).font(.headline)
                    }
                    .padding(10)
                    .frame(width: geometry.size.width / 3.0)
                    .background(
                        RoundedRectangle(cornerRadius: 3).fill(self.style.color)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                            .shadow(radius: 1)
                    )
                    Spacer()
                }
            }.edgesIgnoringSafeArea(.top)
            .offset(y: -3)

        }.id(id)
        .transition(
            .move(edge: .top)
        ).animation(.easeInOut(duration: 0.3))
    }
}

extension Toast.Content.Style {
    var color: Color {
        switch self {
        case .error:
            return .red
        case .warning:
            return .yellow
        case .info:
            return Color(.secondarySystemBackground)
        }
    }
}
