import Foundation
import Capacitor
#if canImport(FoundationModels)
import FoundationModels
#endif
#if canImport(LiteRTLM)
import LiteRTLM
#endif
#if canImport(MediaPipeTasksGenAI)
import MediaPipeTasksGenAI
#endif

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */

@objc(LLMPlugin)
public class LLMPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.1.3"
    private let liteRtTopP: Float = 0.95

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
        case liteRtLm
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

    #if canImport(LiteRTLM)
    private var liteRtEngine: LiteRTLM.Engine?
    private var liteRtChats: [String: LiteRTLM.Conversation] = [:]
    private var liteRtTopk: Int = 40
    private var liteRtTemperature: Float = 0.8
    private var liteRtRandomSeed: Int = 0
    #endif

    #if COCOAPODS || canImport(MediaPipeTasksGenAI)
    private var llmInference: LlmInference?
    private var mediaPipeChats: [String: LlmInference.Session] = [:]
    private var mediaPipeTopk: Int = 40
    private var mediaPipeTemperature: Float = 0.8
    private var mediaPipeRandomSeed: Int = 0
    #endif

    @objc func setModel(_ call: CAPPluginCall) {
        guard let path = call.getString("path") else {
            call.reject("Path is required")
            return
        }

        let maxTokens = call.getInt("maxTokens") ?? 2048
        let topk = call.getInt("topk") ?? 40
        let temperature = call.getFloat("temperature") ?? 0.8
        let randomSeed = call.getInt("randomSeed") ?? 0
        let modelType = call.getString("modelType")
        let backend = call.getString("backend")

        modelPath = path
        isReady = false
        clearChatSessions()
        #if canImport(LiteRTLM)
        liteRtEngine = nil
        #endif
        #if COCOAPODS || canImport(MediaPipeTasksGenAI)
        llmInference = nil
        #endif

        if path.lowercased() == "apple intelligence" {
            currentModelType = .appleIntelligence
            isReady = true
            notifyListeners("readinessChange", data: ["readiness": "ready"])
            call.resolve()
            return
        }

        let resolvedModelType = resolveModelType(path: path, modelType: modelType)
        switch resolveModelKind(path: path, modelType: modelType) {
        case .appleIntelligence:
            currentModelType = .appleIntelligence
            isReady = true
            notifyListeners("readinessChange", data: ["readiness": "ready"])
            call.resolve()

        case .liteRtLm:
            #if canImport(LiteRTLM)
            Task {
                do {
                    let modelURL = try resolveModelURL(path: path, modelType: modelType)
                    let engine = try await initializeLiteRtEngine(
                        modelURL: modelURL,
                        maxTokens: maxTokens,
                        backend: backend
                    )
                    liteRtEngine = engine
                    liteRtTopk = topk
                    liteRtTemperature = temperature
                    liteRtRandomSeed = randomSeed
                    currentModelType = .liteRtLm
                    isReady = true
                    notifyListeners("readinessChange", data: ["readiness": "ready"])
                    call.resolve()
                } catch {
                    let message = "Failed to load model: \(error.localizedDescription)"
                    notifyListeners("readinessChange", data: ["readiness": message])
                    call.reject(message)
                }
            }
            #else
            let message = resolvedModelType == "litertlm"
                ? "LiteRT-LM on iOS is available only when this plugin is integrated through Swift Package Manager."
                : "This custom model format is unavailable on iOS in CocoaPods builds. Use Apple Intelligence or integrate the plugin through Swift Package Manager for LiteRT-LM support."
            call.reject(message)
            #endif

        case .mediaPipe:
            #if canImport(MediaPipeTasksGenAI)
            Task {
                do {
                    let modelURL = try resolveModelURL(path: path, modelType: modelType)
                    let options = LlmInference.Options(modelPath: modelURL.path)
                    options.maxTokens = maxTokens
                    options.maxTopk = topk

                    llmInference = try LlmInference(options: options)
                    mediaPipeTopk = topk
                    mediaPipeTemperature = temperature
                    mediaPipeRandomSeed = randomSeed
                    currentModelType = .mediaPipe
                    isReady = true
                    notifyListeners("readinessChange", data: ["readiness": "ready"])
                    call.resolve()
                } catch {
                    let message = "Failed to load model: \(error.localizedDescription)"
                    notifyListeners("readinessChange", data: ["readiness": message])
                    call.reject(message)
                }
            }
            #else
            call.reject("MediaPipe is not available. For iOS custom .litertlm models, integrate the plugin through Swift Package Manager to use LiteRT-LM.")
            #endif
        }
    }

    @objc func createChat(_ call: CAPPluginCall) {
        switch currentModelType {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                let instructions = call.getString("instructions")
                let session = LanguageModelSession(instructions: instructions)
                let id = UUID().uuidString
                appleChats[id] = session
                call.resolve(["id": id])
            } else {
                call.reject("Apple Intelligence requires iOS 26.0 or later")
            }
            #else
            call.reject("Apple Intelligence is not available on this device")
            #endif

        case .liteRtLm:
            #if canImport(LiteRTLM)
            Task {
                do {
                    guard let engine = liteRtEngine else {
                        call.reject("LiteRT-LM engine not loaded")
                        return
                    }

                    let conversationConfig = try makeLiteRtConversationConfig(instructions: call.getString("instructions"))
                    let conversation = try await engine.createConversation(with: conversationConfig)
                    let id = UUID().uuidString
                    liteRtChats[id] = conversation
                    call.resolve(["id": id])
                } catch {
                    call.reject("Failed to create LiteRT-LM chat: \(error.localizedDescription)")
                }
            }
            #else
            call.reject("LiteRT-LM on iOS is available only when this plugin is integrated through Swift Package Manager.")
            #endif

        case .mediaPipe:
            #if COCOAPODS || canImport(MediaPipeTasksGenAI)
            guard let inference = llmInference else {
                call.reject("Model not loaded")
                return
            }

            do {
                let session = try LlmInference.Session(llmInference: inference, options: makeMediaPipeSessionOptions())
                let id = UUID().uuidString
                mediaPipeChats[id] = session
                call.resolve(["id": id])
            } catch {
                call.reject("Failed to create chat: \(error.localizedDescription)")
            }
            #else
            call.reject("MediaPipe is not available. Please install via CocoaPods.")
            #endif
        }
    }

    @objc func getReadiness(_ call: CAPPluginCall) {
        let readiness = getReadinessStatus()
        call.resolve(["readiness": readiness])
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
            }
            return "Apple Intelligence requires iOS 26.0 or later"
            #else
            return "Apple Intelligence is not available on this device"
            #endif

        case .liteRtLm, .mediaPipe:
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

        case .liteRtLm:
            #if canImport(LiteRTLM)
            guard let conversation = liteRtChats[chatId] else {
                call.reject("chat not found")
                return
            }

            streamLiteRtResponse(chatId: chatId, message: message, conversation: conversation, call: call)
            #else
            call.reject("LiteRT-LM on iOS is available only when this plugin is integrated through Swift Package Manager.")
            #endif

        case .mediaPipe:
            #if COCOAPODS || canImport(MediaPipeTasksGenAI)
            guard llmInference != nil else {
                call.reject("Model not loaded")
                return
            }

            guard let session = mediaPipeChats[chatId] else {
                call.reject("chat not found")
                return
            }

            streamMediaPipeResponse(chatId: chatId, message: message, session: session, call: call)
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

        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            call.reject("Could not access documents directory")
            return
        }

        let destinationURL = documentsPath.appendingPathComponent(filename)
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
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.moveItem(at: tempURL, to: destinationURL)

                var result = [
                    "path": destinationURL.path
                ]

                if let companionUrlString = call.getString("companionUrl"),
                   let companionUrl = URL(string: companionUrlString) {
                    let companionFilename = companionUrl.lastPathComponent
                    let companionDestination = documentsPath.appendingPathComponent(companionFilename)

                    do {
                        let companionData = try Data(contentsOf: companionUrl)
                        try companionData.write(to: companionDestination)
                        result["companionPath"] = companionDestination.path
                    } catch {
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

    private func clearChatSessions() {
        #if canImport(FoundationModels)
        appleChats.removeAll()
        #endif
        #if canImport(LiteRTLM)
        liteRtChats.removeAll()
        #endif
        #if COCOAPODS || canImport(MediaPipeTasksGenAI)
        mediaPipeChats.removeAll()
        #endif
    }

    private func resolveModelKind(path: String, modelType: String?) -> ModelType {
        let resolvedModelType = resolveModelType(path: path, modelType: modelType)
        switch resolvedModelType {
        case "litertlm":
            return .liteRtLm
        case "task":
            return .mediaPipe
        default:
            return .mediaPipe
        }
    }

    private func resolveModelType(path: String, modelType: String?) -> String {
        if let modelType, !modelType.isEmpty {
            return stripURLSuffix(modelType).lowercased()
        }

        let normalizedPath = stripURLSuffix(path)
        let pathExtension = (normalizedPath as NSString).pathExtension
        return pathExtension.lowercased()
    }

    private func stripURLSuffix(_ value: String) -> String {
        let queryIndex = value.firstIndex(of: "?")
        let fragmentIndex = value.firstIndex(of: "#")
        let cutoff = [queryIndex, fragmentIndex].compactMap { $0 }.min() ?? value.endIndex
        return String(value[..<cutoff])
    }

    private func resolveModelURL(path: String, modelType: String?) throws -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        let fileName: String
        let fileExtension: String

        if let modelType, !modelType.isEmpty {
            fileName = (path as NSString).deletingPathExtension
            fileExtension = stripURLSuffix(modelType)
        } else {
            let normalizedPath = stripURLSuffix(path)
            fileName = (normalizedPath as NSString).deletingPathExtension
            fileExtension = (normalizedPath as NSString).pathExtension
        }

        let fallbackExtension = fileExtension.isEmpty ? "bin" : fileExtension
        guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: fallbackExtension) else {
            throw NSError(
                domain: "CapgoLLM",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Model file not found in bundle: \(path)"]
            )
        }

        return URL(fileURLWithPath: bundlePath)
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
            return content
        }

        if let rawContentProperty = mirror.children.first(where: { $0.label == "rawContent" }),
           let rawContent = rawContentProperty.value as? String {
            return rawContent
        }

        return "\(chunk)"
    }
}
#endif

#if canImport(LiteRTLM)
private extension LLMPlugin {
    func initializeLiteRtEngine(
        modelURL: URL,
        maxTokens: Int,
        backend: String?
    ) async throws -> LiteRTLM.Engine {
        guard let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw NSError(
                domain: "CapgoLLM",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Could not access the iOS caches directory for LiteRT-LM."]
            )
        }

        let cacheDir = cacheDirectory.path
        let makeConfig = { (selectedBackend: LiteRTLM.Backend) throws -> LiteRTLM.EngineConfig in
            try LiteRTLM.EngineConfig(
                modelPath: modelURL.path,
                backend: selectedBackend,
                maxNumTokens: maxTokens,
                cacheDir: cacheDir
            )
        }

        let configs: [LiteRTLM.EngineConfig]
        switch backend?.lowercased() {
        case "cpu":
            configs = [try makeConfig(.cpu())]
        case "gpu":
            configs = [try makeConfig(.gpu), try makeConfig(.cpu())]
        default:
            configs = [try makeConfig(.cpu()), try makeConfig(.gpu)]
        }

        var lastError: Error?
        for config in configs {
            let engine = LiteRTLM.Engine(engineConfig: config)
            do {
                try await engine.initialize()
                return engine
            } catch {
                lastError = error
            }
        }

        throw lastError ?? NSError(
            domain: "CapgoLLM",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Failed to initialize LiteRT-LM on iOS."]
        )
    }

    func makeLiteRtConversationConfig(instructions: String?) throws -> LiteRTLM.ConversationConfig {
        let sampler = try LiteRTLM.SamplerConfig(
            topK: liteRtTopk,
            topP: liteRtTopP,
            temperature: liteRtTemperature,
            seed: liteRtRandomSeed
        )

        let systemMessage: LiteRTLM.Message?
        if let instructions, !instructions.isEmpty {
            systemMessage = LiteRTLM.Message(instructions, role: .system)
        } else {
            systemMessage = nil
        }

        return LiteRTLM.ConversationConfig(
            systemMessage: systemMessage,
            samplerConfig: sampler
        )
    }

    func streamLiteRtResponse(chatId: String, message: String, conversation: LiteRTLM.Conversation, call: CAPPluginCall) {
        Task {
            do {
                for try await chunk in conversation.sendMessageStream(LiteRTLM.Message(message)) {
                    let textChunk = chunk.toString
                    if !textChunk.isEmpty {
                        notifyListeners("textFromAi", data: [
                            "chatId": chatId,
                            "text": textChunk,
                            "isChunk": true
                        ])
                    }
                }

                notifyListeners("aiFinished", data: ["chatId": chatId])
                call.resolve()
            } catch {
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

#if COCOAPODS || canImport(MediaPipeTasksGenAI)
private extension LLMPlugin {
    func makeMediaPipeSessionOptions() -> LlmInference.Session.Options {
        let options = LlmInference.Session.Options()
        options.topk = mediaPipeTopk
        options.temperature = mediaPipeTemperature
        options.randomSeed = mediaPipeRandomSeed
        return options
    }

    func streamMediaPipeResponse(chatId: String, message: String, session: LlmInference.Session, call: CAPPluginCall) {
        Task {
            do {
                try session.addQueryChunk(inputText: message)
                let resultStream = session.generateResponseAsync()

                for try await partialResult in resultStream {
                    notifyListeners("textFromAi", data: [
                        "chatId": chatId,
                        "text": partialResult,
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
                call.reject("Failed to generate response: \(error.localizedDescription)")
            }
        }
    }
}
#endif

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
        // Handled in the completion handler.
    }
}
