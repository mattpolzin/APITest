//
//  HelpView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/23/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

struct HelpView: View {
    let host: URL
    @State var isLoaded: Bool = false

    var body: some View {
        ZStack {
            HelpWebView(host: host, isLoaded: self.$isLoaded)
                .opacity(isLoaded ? 1.0 : 0.0)
                .animation(.easeOut)
            VStack {
                HStack {
                    Spacer()
                    Button(action: { store.dispatch(Help.close) }, label: { Image("Close").resizable() } )
                        .padding(8)
                        .frame(width: 46, height: 46)
                }
                Spacer()
            }
        }
    }
}

final class HelpWebView: NSObject, UIViewRepresentable, WKNavigationDelegate {

    let host: URL
    var isLoaded: Binding<Bool>

    init(host: URL, isLoaded: Binding<Bool>) {
        self.host = host
        self.isLoaded = isLoaded
    }

    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true

        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        print(URLRequest(url: host.appendingPathComponent("docs")))
        uiView.load(URLRequest(url: host.appendingPathComponent("docs")))
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: ()) {
        uiView.navigationDelegate = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoaded.wrappedValue = true
    }
}
