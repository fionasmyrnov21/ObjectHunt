import Foundation
import UIKit
import UserNotifications

final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var bestAttemptContent: UNMutableNotificationContent?
    private var downloadTask: URLSessionDataTask?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        NSLog("[PushExt] ===== didReceive ENTRY =====")
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        let userInfo = request.content.userInfo
        logPayload(userInfo)

        guard let bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        attachImage(to: bestAttemptContent, userInfo: userInfo) { [weak self] finished in
            self?.finish(with: finished)
        }
    }

    private func finish(with content: UNNotificationContent) {
        NSLog("[PushExt] Delivering notification with %d attachment(s).", content.attachments.count)
        contentHandler?(content)
        contentHandler = nil
    }

    private func attachImage(
        to content: UNMutableNotificationContent,
        userInfo: [AnyHashable: Any],
        completion: @escaping (UNNotificationContent) -> Void
    ) {
        guard let imageAddress = imageAddress(from: userInfo) else {
            NSLog("[PushExt] No image URL in payload — delivering text-only notification.")
            completion(content)
            return
        }

        NSLog("[PushExt] Downloading image from %@", imageAddress.absoluteString)
        downloadAttachment(from: imageAddress) { attachment in
            if let attachment {
                content.attachments = [attachment]
                NSLog("[PushExt] Attachment added successfully.")
            } else {
                NSLog("[PushExt] Attachment download or creation failed.")
            }
            completion(content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        NSLog("[PushExt] serviceExtensionTimeWillExpire — delivering notification without image.")
        downloadTask?.cancel()
        if let bestAttemptContent {
            finish(with: bestAttemptContent)
        }
    }

    private func logPayload(_ userInfo: [AnyHashable: Any]) {
        var safe: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let stringKey = key as? String else { continue }
            safe[stringKey] = jsonSafeValue(value)
        }
        let aps = userInfo["aps"] as? [AnyHashable: Any]
        let mutableContentValue = aps?["mutable-content"]
        let hasMutableContent = mutableContentValue != nil
        let resolvedImage = imageAddress(from: userInfo)?.absoluteString ?? "<none>"
        let topLevelKeys = userInfo.keys.compactMap { $0 as? String }.sorted().joined(separator: ", ")

        NSLog("[PushExt] top-level keys: %@", topLevelKeys.isEmpty ? "<none>" : topLevelKeys)
        if hasMutableContent {
            NSLog("[PushExt] mutable-content: %@ (present)", String(describing: mutableContentValue!))
        } else {
            NSLog("[PushExt] mutable-content: MISSING — extension will not run on iOS")
        }
        NSLog("[PushExt] resolved image address: %@", resolvedImage)
        if JSONSerialization.isValidJSONObject(safe),
           let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            NSLog("[PushExt] Push payload JSON:\n%@", json)
        }
    }

    private func jsonSafeValue(_ value: Any) -> Any {
        if let dict = value as? [AnyHashable: Any] {
            var result: [String: Any] = [:]
            for (key, value) in dict {
                guard let stringKey = key as? String else { continue }
                result[stringKey] = jsonSafeValue(value)
            }
            return result
        }
        if let array = value as? [Any] {
            return array.map { jsonSafeValue($0) }
        }
        if value is NSNull { return NSNull() }
        if value is NSNumber || value is String || value is Bool {
            return value
        }
        if JSONSerialization.isValidJSONObject([value]) {
            return value
        }
        return "\(value)"
    }

    private func imageAddress(from userInfo: [AnyHashable: Any]) -> URL? {
        let keys = [
            "image",
            "image_url",
            "imageUrl",
            "picture",
            "thumbnail",
            "media_url",
            "media-url",
            "banner",
            "banner_url",
            "bannerUrl",
            "img",
            "attachment-url",
            "attachment_url",
            "gcm.n.image",
            "gcm.notification.image",
            "google.c.a.c_image"
        ]

        for key in keys {
            if let address = validAddress(userInfo[key]) {
                return address
            }
        }

        if let fcmOptions = parsedDictionary(userInfo["fcm_options"]) {
            if let address = validAddress(fcmOptions["image"]) ?? validAddress(fcmOptions["imageUrl"]) {
                return address
            }
        }

        if let data = parsedDictionary(userInfo["data"]) {
            for key in keys {
                if let address = validAddress(data[key]) {
                    return address
                }
            }
        }

        if let message = parsedDictionary(userInfo["message"]) {
            if let nested = parsedDictionary(message["data"]) {
                for key in keys {
                    if let address = validAddress(nested[key]) {
                        return address
                    }
                }
            }
            for key in keys {
                if let address = validAddress(message[key]) {
                    return address
                }
            }
        }

        return recursiveImageAddress(from: userInfo)
    }

    private func parsedDictionary(_ value: Any?) -> [AnyHashable: Any]? {
        if let dictionary = value as? [AnyHashable: Any] {
            return dictionary
        }
        if let jsonString = value as? String,
           let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let dictionary = json as? [AnyHashable: Any] {
            return dictionary
        }
        return nil
    }

    private func recursiveImageAddress(from value: Any) -> URL? {
        if let dictionary = value as? [AnyHashable: Any] {
            for (key, nestedValue) in dictionary {
                if let key = key as? String,
                   isImageKey(key),
                   let address = validAddress(nestedValue) {
                    return address
                }
                if let address = recursiveImageAddress(from: nestedValue) {
                    return address
                }
            }
        }

        if let array = value as? [Any] {
            for item in array {
                if let address = recursiveImageAddress(from: item) {
                    return address
                }
            }
        }

        return nil
    }

    private func isImageKey(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return lowercased.contains("image")
            || lowercased.contains("picture")
            || lowercased.contains("thumbnail")
            || lowercased.contains("banner")
            || lowercased.contains("media")
    }

    private func validAddress(_ value: Any?) -> URL? {
        guard let string = value as? String,
              !string.isEmpty,
              let address = URL(string: string),
              let scheme = address.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        return address
    }

    private func downloadAttachment(from address: URL, completion: @escaping (UNNotificationAttachment?) -> Void) {
        downloadAttachment(from: address, attempt: 1, maxAttempts: 3, completion: completion)
    }

    private func downloadAttachment(
        from address: URL,
        attempt: Int,
        maxAttempts: Int,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        var request = URLRequest(url: address, cachePolicy: .reloadIgnoringLocalCacheData)
        request.timeoutInterval = 8
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("image/jpeg,image/png,image/*;q=0.8,*/*;q=0.5", forHTTPHeaderField: "Accept")

        NSLog("[PushExt] Download attempt %d/%d", attempt, maxAttempts)
        downloadTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else {
                completion(nil)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

            if let error {
                NSLog("[PushExt] Download error (attempt %d): %@", attempt, error.localizedDescription)
            } else {
                NSLog("[PushExt] Download status: %d, bytes: %d (attempt %d)", statusCode, data?.count ?? 0, attempt)
            }

            if let data, !data.isEmpty, (200...299).contains(statusCode) || (statusCode < 0 && error == nil) {
                completion(self.attachment(from: data, response: response, sourceAddress: address))
                return
            }

            guard attempt < maxAttempts else {
                NSLog("[PushExt] All %d download attempts failed.", maxAttempts)
                completion(nil)
                return
            }

            let delay = 0.6 * Double(attempt)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                self.downloadAttachment(from: address, attempt: attempt + 1, maxAttempts: maxAttempts, completion: completion)
            }
        }
        downloadTask?.resume()
    }

    private func attachment(from data: Data, response: URLResponse?, sourceAddress: URL) -> UNNotificationAttachment? {
        guard let prepared = preparedAttachmentFile(from: data, response: response, sourceAddress: sourceAddress) else {
            NSLog("[PushExt] Attachment skipped — payload is not a usable image.")
            return nil
        }

        do {
            NSLog("[PushExt] Wrote %d bytes to %@ (type=%@)", prepared.data.count, prepared.fileAddress.lastPathComponent, prepared.typeHint)
            return try UNNotificationAttachment(
                identifier: "image",
                url: prepared.fileAddress,
                options: [UNNotificationAttachmentOptionsTypeHintKey: prepared.typeHint]
            )
        } catch {
            NSLog("[PushExt] Attachment creation failed: %@", error.localizedDescription)
            return nil
        }
    }

    private func preparedAttachmentFile(from data: Data, response: URLResponse?, sourceAddress: URL) -> (data: Data, fileAddress: URL, typeHint: String)? {
        let maxBytes = 10 * 1024 * 1024
        let detected = detectedImageExtension(from: data)
        var fileExtension = detected ?? resolvedFileExtension(response: response, sourceAddress: sourceAddress)
        var payload = data

        let rawTypes = ["jpg", "png", "gif", "heic", "heif"]
        let canUseRaw = detected != nil && rawTypes.contains(detected!) && payload.count <= maxBytes

        if !canUseRaw {
            guard let image = UIImage(data: data) else {
                return nil
            }
            let quality: CGFloat = data.count > maxBytes ? 0.55 : 0.85
            guard let jpegData = image.jpegData(compressionQuality: quality), jpegData.count <= maxBytes else {
                return nil
            }
            payload = jpegData
            fileExtension = "jpg"
        }

        if fileExtension == "jpeg" {
            fileExtension = "jpg"
        }

        let typeHint = typeHint(forExtension: fileExtension)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PushAttachments", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileAddress = directory.appendingPathComponent("image.\(fileExtension)")

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try payload.write(to: fileAddress, options: [.atomic])
            return (payload, fileAddress, typeHint)
        } catch {
            NSLog("[PushExt] Failed to write attachment file: %@", error.localizedDescription)
            return nil
        }
    }

    private func detectedImageExtension(from data: Data) -> String? {
        guard data.count >= 12 else { return nil }
        let prefix = [UInt8](data.prefix(12))
        if prefix[0] == 0xFF, prefix[1] == 0xD8, prefix[2] == 0xFF {
            return "jpg"
        }
        if prefix[0] == 0x89, prefix[1] == 0x50, prefix[2] == 0x4E, prefix[3] == 0x47 {
            return "png"
        }
        if prefix[0] == 0x47, prefix[1] == 0x49, prefix[2] == 0x46 {
            return "gif"
        }
        if prefix[0] == 0x52, prefix[1] == 0x49, prefix[2] == 0x46, prefix[3] == 0x46 {
            let brand = String(data: data.subdata(in: 8..<12), encoding: .ascii)
            if brand == "WEBP" {
                return "webp"
            }
        }
        if let box = String(data: data.subdata(in: 4..<8), encoding: .ascii), box == "ftyp" {
            let brand = String(data: data.subdata(in: 8..<12), encoding: .ascii) ?? ""
            if ["heic", "heif", "mif1", "msf1"].contains(brand) {
                return "heic"
            }
        }
        return nil
    }

    private func resolvedFileExtension(response: URLResponse?, sourceAddress: URL) -> String {
        let pathExtension = sourceAddress.pathExtension.lowercased()
        if ["jpg", "jpeg", "png", "gif", "heic", "heif"].contains(pathExtension) {
            return pathExtension == "jpeg" ? "jpg" : pathExtension
        }

        let mime = response?.mimeType?.split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        switch mime {
        case "image/png":
            return "png"
        case "image/gif":
            return "gif"
        case "image/heic", "image/heif":
            return "heic"
        case "image/webp":
            return "webp"
        default:
            return "jpg"
        }
    }

    private func typeHint(forExtension fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "png":
            return "public.png"
        case "gif":
            return "public.gif"
        case "heic", "heif":
            return "public.heic"
        default:
            return "public.jpeg"
        }
    }
}
