//
//  ServerPromptPopup.swift
//  KingdomApp
//
//  Dumb WebView popup - backend controls all content via URL
//

import SwiftUI
import WebKit

/// WebView that loads URL with auth token in header (not URL params)
struct ServerPromptWebView: UIViewRepresentable {
    let url: URL
    let authToken: String?
    @Binding var isLoading: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if not already loaded
        if webView.url == nil {
            var request = URLRequest(url: url)
            if let token = authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            webView.load(request)
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ServerPromptWebView
        
        init(_ parent: ServerPromptWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
        }
    }
}

/// Full-screen popup that shows backend-controlled web content
struct ServerPromptPopup: View {
    let prompt: ServerPrompt
    let onDismiss: () -> Void
    
    @State private var isLoading = true
    @State private var opacity: Double = 0
    
    // Get token from APIClient
    private var authToken: String? {
        APIClient.shared.authToken
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .background(
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 24, height: 24)
                            )
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                
                // WebView - prepend base URL if relative path
                if let url = prompt.fullURL {
                    ZStack {
                        ServerPromptWebView(url: url, authToken: authToken, isLoading: $isLoading)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(opacity)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            withAnimation(.easeIn(duration: 0.25)) {
                opacity = 1
            }
        }
    }
}

#Preview {
    ServerPromptPopup(
        prompt: ServerPrompt(id: "test", modalUrl: "https://example.com"),
        onDismiss: {}
    )
}
