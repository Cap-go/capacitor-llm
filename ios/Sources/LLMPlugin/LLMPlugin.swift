import Foundation
import Capacitor
#if canImport(FoundationModels)
import FoundationModels
#endif
// For CocoaPods, MediaPipeTasksGenAI should always be available
// For SPM, we need conditional import when SPM support is added
#if canImport(MediaPipeTasksGenAI)
import MediaPipeTasksGenAI
#endif

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */

@objc(LLMPlugin)
public class LLMPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.0.9"
    public let identifier = "LLMPlugin"
    public let jsName = "CapgoLLM"
    public var pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "createChat", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "sendMessage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getReadiness", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setModel", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "downloadModel", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private enum ModelType {
        case appleIntelligence
        case mediaPipe
    }

    private var currentModelType: ModelType = .appleIntelligence
    private var isReady = false
    private var modelPath: String?

    #if canImport(FoundationModels)
    private var appleModel: Any? = {
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default
        } else {
            return nil
        }
    }()

    private var appleChats: [String: Any] = [:]
    #endif

    #if COCOAPODS || canImport(MediaPipeTasksGenAI)
    private var llmInference: LlmInference?
    #endif

    @objc func setModel(_ call: CAPPluginCall) {
        guard let path = call.getString("path") else {
            call.reject("Path is required")
            return
        }

        print("[CapgoLLM] Setting model path: \(path)")

        // Extract model parameters
        let maxTokens = call.getInt("maxTokens") ?? 2048
        let topk = call.getInt("topk") ?? 40
        let temperature = call.getFloat("temperature") ?? 0.8
        let modelType = call.getString("modelType") // Optional model type parameter

        modelPath = path
        isReady = false

        // Check if user wants to use Apple Intelligence
        if path.lowercased() == "apple intelligence" {
            print("[CapgoLLM] Switching to Apple Intelligence")
            currentModelType = .appleIntelligence
            isReady = true
            notifyListeners("readinessChange", data: ["readiness": "ready"])
            call.resolve()
            return
        }

        #if canImport(MediaPipeTasksGenAI)
        Task {
            do {
                let modelURL: URL

                // Check if it's a path within the app bundle
                if path.hasPrefix("/") {
                    modelURL = URL(fileURLWithPath: path)
                    print("[CapgoLLM] Using absolute path: \(modelURL.path)")
                } else {
                    // Try to find it in the app bundle
                    let fileName: String
                    let fileExtension: String

                    // If modelType is provided, use it as the extension
                    if let providedType = modelType, !providedType.isEmpty {
                        // Remove any extension from path and use provided type
                        fileName = (path as NSString).deletingPathExtension
                        fileExtension = providedType
                        print("[CapgoLLM] Using provided model type: \(fileExtension)")
                    } else {
                        // Extract from path
                        fileName = (path as NSString).deletingPathExtension
                        fileExtension = (path as NSString).pathExtension
                    }

                    print("[CapgoLLM] Looking for model in bundle: \(fileName) with type: \(fileExtension.isEmpty ? "bin" : fileExtension)")

                    // Use Bundle.main.path as shown in MediaPipe docs
                    guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: fileExtension.isEmpty ? "bin" : fileExtension) else {
                        print("[CapgoLLM] Error: Model file not found in bundle: \(path)")
                        print("[CapgoLLM] Tried resource: '\(fileName)' with type: '\(fileExtension.isEmpty ? "bin" : fileExtension)'")
                        call.reject("Model file not found in bundle: \(path)")
                        return
                    }
                    modelURL = URL(fileURLWithPath: bundlePath)
                    print("[CapgoLLM] Found model in bundle at path: \(bundlePath)")

                    // For MediaPipe models, verify companion .litertlm file exists
                    if fileExtension == "task" {
                        let companionPath = Bundle.main.path(forResource: fileName, ofType: "litertlm")
                        if companionPath == nil {
                            print("[CapgoLLM] Warning: Companion .litertlm file not found for \(fileName)")
                            // Don't fail here as some models might not need it
                        } else if let companionPath {
                            print("[CapgoLLM] Found companion file at path: \(companionPath)")
                        }
                    }
                }

                // Initialize MediaPipe LLM
                print("[CapgoLLM] Initializing MediaPipe with model at: \(modelURL.path)")
                let options = LlmInference.Options(modelPath: modelURL.path)
                options.maxTokens = maxTokens
                options.maxTopk = topk

                print("[CapgoLLM] Creating LlmInference instance with maxTokens: \(maxTokens), topk: \(topk), temperature: \(temperature)")
                llmInference = try LlmInference(options: options)
                currentModelType = .mediaPipe
                isReady = true

                print("[CapgoLLM] Model loaded successfully")
                notifyListeners("readinessChange", data: ["readiness": "ready"])
                call.resolve()
            } catch {
                print("[CapgoLLM] Error loading model: \(error.localizedDescription)")
                notifyListeners("readinessChange", data: ["readiness": "Failed to load model: \(error.localizedDescription)"])
                call.reject("Failed to load model: \(error.localizedDescription)")
            }
        }
        #else
        call.reject("MediaPipe is not available. Please install via CocoaPods.")
        #endif
    }

    @objc func createChat(_ call: CAPPluginCall) {
        print("[CapgoLLM] Creating chat with model type: \(currentModelType)")
        switch currentModelType {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let instructions = call.getString("instructions")
                let session = LanguageModelSession(instructions: instructions)
                let id = UUID()
                appleChats[id.uuidString] = session
                call.resolve([
                    "id": id.uuidString
                ])
            } else {
                call.reject("Apple Intelligence requires iOS 26.0 or later")
            }
            #else
            call.reject("Apple Intelligence is not available on this device")
            #endif

        case .mediaPipe:
            #if COCOAPODS || canImport(MediaPipeTasksGenAI)
            guard llmInference != nil else {
                print("[CapgoLLM] Error: Model not loaded when creating chat")
                call.reject("Model not loaded")
                return
            }

            // MediaPipe doesn't use sessions, just return a dummy ID
            let id = UUID().uuidString
            print("[CapgoLLM] Created MediaPipe chat with ID: \(id)")
            call.resolve([
                "id": id
            ])
            #else
            call.reject("MediaPipe is not available. Please install via CocoaPods.")
            #endif
        }
    }

    @objc func getReadiness(_ call: CAPPluginCall) {
        let readiness = getReadinessStatus()
        call.resolve(["readiness": readiness])
        // Also notify listeners
        notifyListeners("readinessChange", data: ["readiness": readiness])
    }

    private func getReadinessStatus() -> String {
        switch currentModelType {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), let model = appleModel as? SystemLanguageModel {
                switch model.availability {
                case .available:
                    return "ready"
                case .unavailable(.deviceNotEligible):
                    return "Device is not eligible for Apple Intelligence"
                case .unavailable(.appleIntelligenceNotEnabled):
                    return "Apple Intelligence is not enabled"
                case .unavailable(.modelNotReady):
                    return "Model is not ready"
                case .unavailable(let other):
                    return "Error: \(other)"
                }
            } else {
                return "Apple Intelligence requires iOS 26.0 or later"
            }
            #else
            return "Apple Intelligence is not available on this device"
            #endif

        case .mediaPipe:
            return isReady ? "ready" : "not_ready"
        }
    }

    @objc func sendMessage(_ call: CAPPluginCall) {
        let chatId = call.getString("chatId", "")
        guard let message = call.getString("message") else {
            call.reject("message not found")
            return
        }

        switch currentModelType {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), let model = appleModel as? SystemLanguageModel {
                guard validateAppleAvailability(model: model, call: call) else { return }
                guard let chat = appleChats[chatId] as? LanguageModelSession else {
                    call.reject("chat not found")
                    return
                }

                if chat.isResponding {
                    call.reject("chat is responding, please wait before asking new questions")
                    return
                }

                streamAppleResponse(chatId: chatId, message: message, chat: chat, call: call)
            } else {
                call.reject("Apple Intelligence requires iOS 26.0 or later")
            }
            #else
            call.reject("Apple Intelligence is not available on this device")
            #endif

        case .mediaPipe:
            #if COCOAPODS || canImport(MediaPipeTasksGenAI)
            guard let inference = llmInference else {
                call.reject("Model not loaded")
                return
            }

            streamMediaPipeResponse(chatId: chatId, message: message, inference: inference, call: call)
            #else
            call.reject("MediaPipe is not available. Please install via CocoaPods.")
            #endif
        }
    }

    @objc func downloadModel(_ call: CAPPluginCall) {
        guard let urlString = call.getString("url") else {
            call.reject("URL is required")
            return
        }

        guard let url = URL(string: urlString) else {
            call.reject("Invalid URL")
            return
        }

        let filename = call.getString("filename") ?? url.lastPathComponent

        // Get documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            call.reject("Could not access documents directory")
            return
        }

        let destinationURL = documentsPath.appendingPathComponent(filename)

        // Create download task
        let session = URLSession(configuration: .default, delegate: DownloadDelegate(plugin: self), delegateQueue: nil)
        let downloadTask = session.downloadTask(with: url) { tempURL, _, error in
            if let error = error {
                call.reject("Download failed: \(error.localizedDescription)")
                return
            }

            guard let tempURL = tempURL else {
                call.reject("Download failed: No temporary file")
                return
            }

            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // Move downloaded file to documents directory
                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                var result = [
                    "path": destinationURL.path
                ]

                // Handle companion URL if provided (for compatibility)
                if let companionUrlString = call.getString("companionUrl"),
                   let companionUrl = URL(string: companionUrlString) {

                    let companionFilename = companionUrl.lastPathComponent
                    let companionDestination = documentsPath.appendingPathComponent(companionFilename)

                    // Download companion file synchronously for simplicity
                    do {
                        let companionData = try Data(contentsOf: companionUrl)
                        try companionData.write(to: companionDestination)
                        result["companionPath"] = companionDestination.path
                    } catch {
                        // Log error but don't fail the whole download
                        print("Failed to download companion file: \(error)")
                    }
                }

                call.resolve(result)

            } catch {
                call.reject("Failed to save file: \(error.localizedDescription)")
            }
        }

        downloadTask.resume()
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.pluginVersion])
    }
}

#if canImport(FoundationModels)
private extension LLMPlugin {
    @available(iOS 26.0, *)
    func validateAppleAvailability(model: SystemLanguageModel, call: CAPPluginCall) -> Bool {
        switch model.availability {
        case .available:
            return true
        case .unavailable(.deviceNotEligible):
            call.reject("error deviceNotEligible error")
        case .unavailable(.appleIntelligenceNotEnabled):
            call.reject("error appleIntelligenceNotEnabled error")
        case .unavailable(.modelNotReady):
            call.reject("error modelNotReady error")
        case .unavailable(let other):
            call.reject("error \(other) error")
        }

        return false
    }

    @available(iOS 26.0, *)
    func streamAppleResponse(chatId: String, message: String, chat: LanguageModelSession, call: CAPPluginCall) {
        Task {
            do {
                let stream = chat.streamResponse(to: message)
                for try await chunk in stream {
                    let textChunk = extractAppleTextChunk(from: chunk)
                    notifyListeners("textFromAi", data: [
                        "chatId": chatId,
                        "text": textChunk,
                        "isChunk": true
                    ])
                }
                notifyListeners("aiFinished", data: ["chatId": chatId])
                call.resolve()
            } catch {
                notifyListeners("generationError", data: [
                    "chatId": chatId,
                    "error": error.localizedDescription
                ])
                call.reject("Failed to get response: \(error.localizedDescription)")
            }
        }
    }

    @available(iOS 26.0, *)
    func extractAppleTextChunk(from chunk: Any) -> String {
        let mirror = Mirror(reflecting: chunk)

        if let contentProperty = mirror.children.first(where: { $0.label == "content" }),
           let content = contentProperty.value as? String {
            print("[CapgoLLM] Extracted content: \(content)")
            return content
        }

        if let rawContentProperty = mirror.children.first(where: { $0.label == "rawContent" }),
           let rawContent = rawContentProperty.value as? String {
            print("[CapgoLLM] Extracted rawContent: \(rawContent)")
            return rawContent
        }

        let fallback = "\(chunk)"
        print("[CapgoLLM] Fallback to string conversion: \(fallback)")
        return fallback
    }
}
#endif

#if COCOAPODS || canImport(MediaPipeTasksGenAI)
private extension LLMPlugin {
    func streamMediaPipeResponse(chatId: String, message: String, inference: LlmInference, call: CAPPluginCall) {
        Task {
            do {
                print("[CapgoLLM] Attempting to generate streaming response for message: \(message)")

                let resultStream = inference.generateResponseAsync(inputText: message)

                for try await partialResult in resultStream {
                    print("[CapgoLLM] Partial result: \(partialResult)")
                    notifyListeners("textFromAi", data: [
                        "chatId": chatId,
                        "text": partialResult,
                        "isChunk": true
                    ])
                }

                notifyListeners("aiFinished", data: ["chatId": chatId])
                call.resolve()
            } catch {
                print("[CapgoLLM] Error details: \(error)")
                notifyListeners("generationError", data: [
                    "chatId": chatId,
                    "error": error.localizedDescription
                ])
                call.reject("Failed to generate response: \(error.localizedDescription)")
            }
        }
    }
}
#endif

// Download delegate class to handle progress updates
class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var plugin: CAPPlugin?

    init(plugin: CAPPlugin) {
        self.plugin = plugin
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {

        if totalBytesExpectedToWrite > 0 {
            let progress = Int((Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) * 100)

            plugin?.notifyListeners("downloadProgress", data: [
                "progress": progress,
                "downloadedBytes": totalBytesWritten,
                "totalBytes": totalBytesExpectedToWrite
            ])
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Handled in the completion handler
    }

}
