//
//  MessageCellView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/25/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels

struct MessageCellView: View {
    let messageType: API.MessageType
    let message: String
    let path: String?
    let context: String?
    let highlighted: Bool

    var body: some View {
        Group {
            HStack {
                Rectangle().fill(messageType.color)
                    .frame(width: 5)
                VStack(alignment: .leading, spacing: 10) {
                    Text(message).font(.body).bold()
                    path.map { Text("→ \($0)").font(.body).italic() }
                    context.map { Text("→ \($0)").font(.body) }
                }
            }
            .padding(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
        }
        .background(
            Group {
                highlighted ? Color.accentColor : Color.clear
            }
            .cornerRadius(3)
            .animation(.easeInOut(duration: highlighted ? 0.075 : 0.55))
        )
        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
    }

    /// A dummy cell that uses morse code as placeholder for text.
    static var dummy: Self {
        MessageCellView(
            messageType: .info,
            message: .randomMorse(count: 25),
            path: .randomMorse(count: 8, asPath: true),
            context: .randomMorse(count: 15),
            highlighted: false
        )
    }
}

extension String {
    /// Random Morse Code snippet (dots and dashes)
    ///
    /// - parameters:
    ///     - count: The number of characters to generate.
    ///     - asPath: (default `false`) If true, inserts a couple of forward slashes
    ///         randomly to give the appearance of a URI path.
    fileprivate static func randomMorse(count: Int, asPath: Bool = false) -> String {
        let characters: [Character] = ["·", "−"]

        let randomChar: () -> Character = { characters[Int.random(in: 0..<(characters.count))] }

        let randomMorse = (0..<count).reduce(into: "") { res, _ in res.append(randomChar()) }

        guard asPath else {
            return randomMorse
        }

        let pathSplits = [
            Int.random(in: 0..<randomMorse.count),
            Int.random(in: 1..<randomMorse.count)
            ].map { randomMorse.index(randomMorse.startIndex, offsetBy: $0) }

        let ret = String(randomMorse[randomMorse.startIndex..<pathSplits[0]])
            + "/"
            + String(randomMorse[randomMorse.startIndex..<pathSplits[1]])
            + "/"
            + String(randomMorse[pathSplits[1]...])

        return ret
    }
}
