//
//  ShareViewController.swift
//  ShareExtension
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private let appGroupID = "group.com.musiclinker.app"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.08, alpha: 1)

        let label = UILabel()
        label.text = "已复制链接 ✅\n请打开 MusicLinker"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])

        extractAndDeliver()
    }

    private func extractAndDeliver() {
        guard let ctx = extensionContext else { return done() }

        let attachments = (ctx.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        var found: String?
        let group = DispatchGroup()

        for provider in attachments {
            for type in [UTType.url.identifier, UTType.plainText.identifier] {
                guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
                group.enter()
                provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
                    defer { group.leave() }
                    guard found == nil else { return }
                    if let url = item as? URL { found = url.absoluteString }
                    else if let text = item as? String { found = self.extractURL(from: text) ?? text }
                }
                break
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            let final = found.flatMap { self.extractURL(from: $0) } ?? found

            if let url = final {
                // 通道 1: App Groups
                if let shared = UserDefaults(suiteName: self.appGroupID) {
                    shared.set(url, forKey: "sharedMusicURL")
                    shared.synchronize()

                    // 验证：立即读回确认写入成功
                    let readBack = shared.string(forKey: "sharedMusicURL")
                    print("📦 App Groups 写入\(readBack != nil ? "✅" : "❌"): \(url)")
                } else {
                    print("❌ App Groups 未配置！UserDefaults(suiteName:) 返回 nil")
                }

                // 通道 2: 尝试打开主 App
                self.openMainApp(with: url)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.done()
            }
        }
    }

    private func openMainApp(with url: String) {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "?&=+#")
        let encoded = url.addingPercentEncoding(withAllowedCharacters: allowed) ?? url
        guard let appURL = URL(string: "musiclinker://open?url=\(encoded)") else { return }
        extensionContext?.open(appURL, completionHandler: nil)
    }

    private func extractURL(from text: String) -> String? {
        guard let d = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        return d.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text))?.url?.absoluteString
    }

    private func done() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
