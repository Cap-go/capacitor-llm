import Foundation
import Capacitor
import ObjectiveC
import Darwin
#if canImport(FoundationModels)
import FoundationModels
#endif
// For CocoaPods, MediaPipeTasksGenAI should always be available
// For SPM, we need conditional import when SPM support is added
#if canImport(MediaPipeTasksGenAI) && !targetEnvironment(macCatalyst)
import MediaPipeTasksGenAI
#endif

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */

@objc(LLMPlugin)
public class LLMPlugin: CAPPlugin, CAPBridgedPlugin {
    private let pluginVersion: String = "8.0.18"
    #if targetEnvironment(macCatalyst)
    private let catalystNotSupportedMessage = "CapgoLLM is not available on Mac Catalyst. Use an iOS/iPadOS target instead."
    #endif
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
        case execuTorch
    }

    private final class ExecuTorchChatSession {
        private var turns: [(role: String, content: String)] = []

        func buildPrompt(userMessage: String) -> String {
            var parts = turns.map { "\($0.role): \($0.content)" }
            parts.append("User: \(userMessage)")
            parts.append("Assistant:")
            return parts.joined(separator: "\n")
        }

        func addTurn(userMessage: String, assistantMessage: String) {
            turns.append((role: "User", content: userMessage))
            turns.append((role: "Assistant", content: assistantMessage))
        }
    }

    private var currentModelType: ModelType = .appleIntelligence
    private var isReady = false
    private var modelPath: String?

    #if canImport(FoundationModels)
    private var appleModel: Any? = {
        // `SystemLanguageModel.default` is not functional for an iOS/iPadOS
        // binary running "Designed for iPad" on Apple Silicon Mac, and
        // touching it there crashes the app during plugin instantiation —
        // before any of the app's own platform checks get a chance to run,
        // since Capacitor eagerly instantiates every registered plugin at
        // bridge startup. Skip it in that environment, same as the existing
        // Mac Catalyst guard below.
        if ProcessInfo.processInfo.isiOSAppOnMac {
            return nil
        }
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default
        } else {
            return nil
        }
    }()

    private var appleChats: [String: Any] = [:]
    #endif

    #if !targetEnvironment(macCatalyst) && (COCOAPODS || canImport(MediaPipeTasksGenAI))
    private var llmInference: LlmInference?
    #endif

    private var execuTorchRunner: DynamicExecuTorchRunner?
    private var execuTorchChats: [String: ExecuTorchChatSession] = [:]
    private let execuTorchGenerationLock = NSLock()
    private let execuTorchNotLinkedMessage = "ExecuTorch is not linked in this iOS app. " +
        "It is not installed by CocoaPods; add the ExecuTorch Swift Package products " +
        "to the app target on iOS 17+ or choose another engine."
    private var execuTorchIsGenerating = false

    @objc func setModel(_ call: CAPPluginCall) {
        guard let path = call.getString("path") else {
            call.reject("Path is required")
            return
        }

        #if targetEnvironment(macCatalyst)
        call.reject(catalystNotSupportedMessage)
        return
        #endif

        print("[CapgoLLM] Setting model path: \(path)")

        // Extract model parameters
        let maxTokens = call.getInt("maxTokens") ?? 2048
        let topk = call.getInt("topk") ?? 40
        let temperature = call.getFloat("temperature") ?? 0.8
        let modelType = call.getString("modelType") // Optional model type parameter
        let engine = call.getString("engine")?.lowercased() ?? "auto"
        let tokenizerPath = call.getString("tokenizerPath")
        let specialTokens = call.getArray("specialTokens", String.self) ?? []
        let sequenceLength = call.getInt("sequenceLength") ?? maxTokens

        guard sequenceLength > 0 else {
            call.reject("sequenceLength must be > 0")
            return
        }

        guard !isExecuTorchGenerating() else {
            call.reject("Cannot switch model while ExecuTorch is generating. Wait for aiFinished.")
            return
        }

        modelPath = path
        execuTorchChats.removeAll()
        #if !targetEnvironment(macCatalyst) && (COCOAPODS || canImport(MediaPipeTasksGenAI))
        llmInference = nil
        #endif
        execuTorchRunner = nil
        isReady = false

        // Check if user wants to use Apple Intelligence
        if engine == "apple" || path.lowercased() == "apple intelligence" {
            print("[CapgoLLM] Switching to Apple Intelligence")
            execuTorchRunner = nil
            currentModelType = .appleIntelligence
            isReady = true
            notifyListeners("readinessChange", data: ["readiness": "ready"])
            call.resolve()
            return
        }

        if shouldUseExecuTorch(engine: engine, path: path, tokenizerPath: tokenizerPath) {
            currentModelType = .execuTorch
            setExecuTorchModel(
                call,
                path: path,
                tokenizerPath: tokenizerPath,
                modelType: modelType,
                specialTokens: specialTokens,
                sequenceLength: sequenceLength,
                temperature: temperature
            )
            return
        }

        #if !targetEnvironment(macCatalyst) && canImport(MediaPipeTasksGenAI)
        currentModelType = .mediaPipe
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
                        } else {
                            print("[CapgoLLM] Found companion file at path: \(companionPath!)")
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
                llmInference = nil
                isReady = false
                print("[CapgoLLM] Error loading model: \(error.localizedDescription)")
                notifyListeners("readinessChange", data: ["readiness": "Failed to load model: \(error.localizedDescription)"])
                call.reject("Failed to load model: \(error.localizedDescription)")
            }
        }
        #else
        call.reject("MediaPipe is not available on this platform. Please install via CocoaPods on iOS.")
        #endif
    }

    private func shouldUseExecuTorch(engine: String, path: String, tokenizerPath: String?) -> Bool {
        if path.lowercased() == "apple intelligence" {
            return false
        }
        if engine == "executorch" {
            return true
        }
        if engine == "apple" || engine == "mediapipe" {
            return false
        }
        if tokenizerPath?.isEmpty == false {
            return true
        }
        return path.lowercased().hasSuffix(".pte")
    }

    private func setExecuTorchModel(
        _ call: CAPPluginCall,
        path: String,
        tokenizerPath: String?,
        modelType: String?,
        specialTokens: [String],
        sequenceLength: Int,
        temperature: Float
    ) {
        execuTorchRunner = nil

        guard sequenceLength > 0 else {
            call.reject("sequenceLength must be > 0")
            return
        }

        guard DynamicExecuTorchRunner.isAvailable else {
            isReady = false
            notifyListeners("readinessChange", data: ["readiness": execuTorchNotLinkedMessage])
            call.reject(execuTorchNotLinkedMessage)
            return
        }

        guard let tokenizerPath = tokenizerPath, !tokenizerPath.isEmpty else {
            call.reject("tokenizerPath is required for ExecuTorch models")
            return
        }

        Task {
            do {
                let modelURL = try resolveModelURL(path: path, modelType: modelType, defaultExtension: "pte")
                let tokenizerURL = try resolveModelURL(path: tokenizerPath, modelType: nil, defaultExtension: "model")

                print("[CapgoLLM] Initializing ExecuTorch with model at: \(modelURL.path)")
                print("[CapgoLLM] Initializing ExecuTorch with tokenizer at: \(tokenizerURL.path)")

                execuTorchRunner = try DynamicExecuTorchRunner(
                    modelPath: modelURL.path,
                    tokenizerPath: tokenizerURL.path,
                    specialTokens: specialTokens,
                    sequenceLength: sequenceLength,
                    temperature: Double(temperature)
                )
                currentModelType = .execuTorch
                isReady = true

                notifyListeners("readinessChange", data: ["readiness": "ready"])
                call.resolve()
            } catch {
                execuTorchRunner = nil
                isReady = false
                print("[CapgoLLM] Error loading ExecuTorch model: \(error.localizedDescription)")
                notifyListeners("readinessChange", data: ["readiness": "Failed to load ExecuTorch model: \(error.localizedDescription)"])
                call.reject("Failed to load ExecuTorch model: \(error.localizedDescription)")
            }
        }
    }

    private func resolveModelURL(path: String, modelType: String?, defaultExtension: String) throws -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }

        let fileName: String
        let fileExtension: String

        if let providedType = modelType, !providedType.isEmpty {
            fileName = (path as NSString).deletingPathExtension
            fileExtension = providedType
        } else {
            fileName = (path as NSString).deletingPathExtension
            let extractedExtension = (path as NSString).pathExtension
            fileExtension = extractedExtension.isEmpty ? defaultExtension : extractedExtension
        }

        guard let bundlePath = Bundle.main.path(forResource: fileName, ofType: fileExtension) else {
            throw NSError(
                domain: "CapgoLLM",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Model file not found in bundle: \(path)"]
            )
        }

        return URL(fileURLWithPath: bundlePath)
    }

    @objc func createChat(_ call: CAPPluginCall) {
        #if targetEnvironment(macCatalyst)
        call.reject(catalystNotSupportedMessage)
        return
        #endif

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
            #if !targetEnvironment(macCatalyst) && (COCOAPODS || canImport(MediaPipeTasksGenAI))
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
            call.reject("MediaPipe is not available on this platform. Please install via CocoaPods on iOS.")
            #endif

        case .execuTorch:
            guard execuTorchRunner != nil else {
                call.reject("ExecuTorch model not loaded")
                return
            }
            let id = UUID().uuidString
            execuTorchChats[id] = ExecuTorchChatSession()
            print("[CapgoLLM] Created ExecuTorch chat with ID: \(id)")
            call.resolve([
                "id": id
            ])
        }
    }

    @objc func getReadiness(_ call: CAPPluginCall) {
        #if targetEnvironment(macCatalyst)
        call.resolve(["readiness": "unsupported_on_maccatalyst"])
        notifyListeners("readinessChange", data: ["readiness": "unsupported_on_maccatalyst"])
        return
        #endif

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

        case .execuTorch:
            return isReady ? "ready" : "not_ready"
        }
    }

    @objc func sendMessage(_ call: CAPPluginCall) {
        #if targetEnvironment(macCatalyst)
        call.reject(catalystNotSupportedMessage)
        return
        #endif

        let chatId = call.getString("chatId", "")
        guard let message = call.getString("message") else {
            call.reject("message not found")
            return
        }

        switch currentModelType {
        case .appleIntelligence:
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *), let model = appleModel as? SystemLanguageModel {
                switch model.availability {
                case .available:
                    break
                case .unavailable(.deviceNotEligible):
                    call.reject("error deviceNotEligible error")
                    return
                case .unavailable(.appleIntelligenceNotEnabled):
                    call.reject("error appleIntelligenceNotEnabled error")
                    return
                case .unavailable(.modelNotReady):
                    call.reject("error modelNotReady error")
                    return
                case .unavailable(let other):
                    call.reject("error \(other) error")
                    return
                }

                guard let chat = appleChats[chatId] as? LanguageModelSession else {
                    call.reject("chat not found")
                    return
                }

                if chat.isResponding {
                    call.reject("chat is responding, please wait before asking new questions")
                    return
                }

                Task {
                    do {
                        let stream = chat.streamResponse(to: message)
                        for try await chunk in stream {
                            print("[CapgoLLM] Chunk type: \(type(of: chunk))")

                            // Extract content from Snapshot object using Mirror reflection
                            let textChunk: String
                            let mirror = Mirror(reflecting: chunk)

                            // Try to find content property
                            if let contentProperty = mirror.children.first(where: { $0.label == "content" }),
                               let content = contentProperty.value as? String {
                                textChunk = content
                                print("[CapgoLLM] Extracted content: \(content)")
                            } else {
                                // Fallback: try rawContent
                                if let rawContentProperty = mirror.children.first(where: { $0.label == "rawContent" }),
                                   let rawContent = rawContentProperty.value as? String {
                                    textChunk = rawContent
                                    print("[CapgoLLM] Extracted rawContent: \(rawContent)")
                                } else {
                                    // Final fallback
                                    textChunk = "\(chunk)"
                                    print("[CapgoLLM] Fallback to string conversion: \(textChunk)")
                                }
                            }
                            let data: [String: Any] = [
                                "chatId": chatId as String,
                                "text": textChunk as String,
                                "isChunk": true
                            ]
                            self.notifyListeners("textFromAi", data: data)
                        }
                        let finishData: [String: Any] = ["chatId": chatId as String]
                        self.notifyListeners("aiFinished", data: finishData)
                        call.resolve()
                    } catch {
                        call.reject("Failed to get response: \(error.localizedDescription)")
                    }
                }
            } else {
                call.reject("Apple Intelligence requires iOS 26.0 or later")
            }
            #else
            call.reject("Apple Intelligence is not available on this device")
            #endif

        case .mediaPipe:
            #if !targetEnvironment(macCatalyst) && (COCOAPODS || canImport(MediaPipeTasksGenAI))
            guard let inference = llmInference else {
                call.reject("Model not loaded")
                return
            }

            Task {
                do {
                    print("[CapgoLLM] Attempting to generate streaming response for message: \(message)")

                    // Use native streaming API
                    let resultStream = inference.generateResponseAsync(inputText: message)

                    var fullResponse = ""

                    for try await partialResult in resultStream {
                        print("[CapgoLLM] Partial result: \(partialResult)")

                        // Send the chunk
                        self.notifyListeners("textFromAi", data: [
                            "chatId": chatId,
                            "text": partialResult,
                            "isChunk": true
                        ])

                        // Accumulate for history (if needed)
                        fullResponse += partialResult
                    }

                    print("[CapgoLLM] Streaming complete. Full response: \(fullResponse)")

                    self.notifyListeners("aiFinished", data: ["chatId": chatId])
                    call.resolve()

                } catch {
                    print("[CapgoLLM] Error details: \(error)")
                    call.reject("Failed to generate response: \(error.localizedDescription)")
                }
            }
            #else
            call.reject("MediaPipe is not available on this platform. Please install via CocoaPods on iOS.")
            #endif

        case .execuTorch:
            guard isReady, let runner = execuTorchRunner else {
                call.reject("ExecuTorch model not loaded")
                return
            }
            guard let chat = execuTorchChats[chatId] else {
                call.reject("chat not found")
                return
            }
            guard beginExecuTorchGeneration() else {
                call.reject("ExecuTorch is already generating. Wait for aiFinished before sending another message.")
                return
            }

            Task {
                defer {
                    self.finishExecuTorchGeneration()
                }

                do {
                    let prompt = chat.buildPrompt(userMessage: message)
                    var fullResponse = ""
                    print("[CapgoLLM] Attempting to generate ExecuTorch response for message: \(message)")
                    try runner.generate(prompt) { token in
                        self.notifyListeners("textFromAi", data: [
                            "chatId": chatId,
                            "text": token,
                            "isChunk": true
                        ])
                        fullResponse += token
                    }
                    chat.addTurn(userMessage: message, assistantMessage: fullResponse)
                    self.notifyListeners("aiFinished", data: ["chatId": chatId])
                    call.resolve()
                } catch {
                    print("[CapgoLLM] ExecuTorch error details: \(error)")
                    call.reject("Failed to generate ExecuTorch response: \(error.localizedDescription)")
                }
            }
        }
    }

    private func isExecuTorchGenerating() -> Bool {
        execuTorchGenerationLock.lock()
        defer { execuTorchGenerationLock.unlock() }
        return execuTorchIsGenerating
    }

    private func beginExecuTorchGeneration() -> Bool {
        execuTorchGenerationLock.lock()
        defer { execuTorchGenerationLock.unlock() }

        if execuTorchIsGenerating {
            return false
        }

        execuTorchIsGenerating = true
        return true
    }

    private func finishExecuTorchGeneration() {
        execuTorchGenerationLock.lock()
        execuTorchIsGenerating = false
        execuTorchGenerationLock.unlock()
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
        let downloadTask = session.downloadTask(with: url) { [weak self] (tempURL, _, error) in
            guard let self = self else { return }

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

private typealias ExecuTorchAllocFunction = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
private typealias ExecuTorchInitRunnerFunction = @convention(c) (
    AnyObject,
    Selector,
    NSString,
    NSString,
    NSArray
) -> Unmanaged<AnyObject>
private typealias ExecuTorchLoadFunction = @convention(c) (
    AnyObject,
    Selector,
    UnsafeMutablePointer<NSError?>
) -> Bool
private typealias ExecuTorchConfigBlock = @convention(block) (NSObject) -> Void
private typealias ExecuTorchInitConfigFunction = @convention(c) (
    AnyObject,
    Selector,
    ExecuTorchConfigBlock
) -> Unmanaged<AnyObject>
private typealias ExecuTorchTokenCallback = @convention(block) (NSString) -> Void
private typealias ExecuTorchGenerateFunction = @convention(c) (
    AnyObject,
    Selector,
    NSString,
    AnyObject,
    ExecuTorchTokenCallback,
    UnsafeMutablePointer<NSError?>
) -> Bool
private typealias ExecuTorchVoidFunction = @convention(c) (AnyObject, Selector) -> Void

private final class DynamicExecuTorchRunner {
    private static let runnerInitSelector = NSSelectorFromString("initWithModelPath:tokenizerPath:specialTokens:")
    private static let runnerLoadSelector = NSSelectorFromString("loadWithError:")
    private static let runnerResetSelector = NSSelectorFromString("reset")
    private static let runnerGenerateSelector = NSSelectorFromString("generateWithPrompt:config:tokenCallback:error:")
    private static let configInitSelector = NSSelectorFromString("initWithBlock:")

    static var isAvailable: Bool {
        guard let runnerClass = findClass("ExecuTorchLLMTextRunner"),
              let configClass = findClass("ExecuTorchLLMConfig") else {
            return false
        }

        return hasInstanceMethod(runnerClass, runnerInitSelector) &&
            hasInstanceMethod(runnerClass, runnerLoadSelector) &&
            hasInstanceMethod(runnerClass, runnerResetSelector) &&
            hasInstanceMethod(runnerClass, runnerGenerateSelector) &&
            hasInstanceMethod(configClass, configInitSelector)
    }

    private let runner: AnyObject
    private let sequenceLength: Int
    private let temperature: Double

    init(
        modelPath: String,
        tokenizerPath: String,
        specialTokens: [String],
        sequenceLength: Int,
        temperature: Double
    ) throws {
        guard let runnerClass = Self.findClass("ExecuTorchLLMTextRunner") else {
            throw Self.error("ExecuTorchLLMTextRunner was not found. Link ExecuTorch in the app target.")
        }
        try Self.requireInstanceMethod(Self.runnerInitSelector, on: runnerClass)
        try Self.requireInstanceMethod(Self.runnerLoadSelector, on: runnerClass)

        let alloc: ExecuTorchAllocFunction = try Self.objcMessage()
        let initRunner: ExecuTorchInitRunnerFunction = try Self.objcMessage()
        let load: ExecuTorchLoadFunction = try Self.objcMessage()

        let allocatedRunner = alloc(runnerClass, NSSelectorFromString("alloc")).takeRetainedValue()
        runner = initRunner(
            allocatedRunner,
            Self.runnerInitSelector,
            modelPath as NSString,
            tokenizerPath as NSString,
            specialTokens as NSArray
        ).takeRetainedValue()
        self.sequenceLength = sequenceLength
        self.temperature = temperature

        var loadError: NSError?
        guard load(runner, Self.runnerLoadSelector, &loadError) else {
            throw loadError ?? Self.error("ExecuTorch model failed to load")
        }
    }

    func generate(_ prompt: String, tokenCallback: @escaping (String) -> Void) throws {
        guard let configClass = Self.findClass("ExecuTorchLLMConfig") else {
            throw Self.error("ExecuTorchLLMConfig was not found. Link ExecuTorch in the app target.")
        }
        guard let runnerClass = object_getClass(runner) else {
            throw Self.error("ExecuTorch runner class was not found")
        }
        try Self.requireInstanceMethod(Self.runnerResetSelector, on: runnerClass)
        try Self.requireInstanceMethod(Self.runnerGenerateSelector, on: runnerClass)
        try Self.requireInstanceMethod(Self.configInitSelector, on: configClass)

        let sendVoid: ExecuTorchVoidFunction = try Self.objcMessage()
        let alloc: ExecuTorchAllocFunction = try Self.objcMessage()
        let initConfig: ExecuTorchInitConfigFunction = try Self.objcMessage()
        let generate: ExecuTorchGenerateFunction = try Self.objcMessage()

        sendVoid(runner, Self.runnerResetSelector)

        let allocatedConfig = alloc(configClass, NSSelectorFromString("alloc")).takeRetainedValue()
        let configBlock: ExecuTorchConfigBlock = { [temperature, sequenceLength] config in
            config.setValue(temperature, forKey: "temperature")
            config.setValue(sequenceLength, forKey: "sequenceLength")
        }
        let config = initConfig(
            allocatedConfig,
            Self.configInitSelector,
            configBlock
        ).takeRetainedValue()

        let callback: ExecuTorchTokenCallback = { token in
            tokenCallback(token as String)
        }
        var generateError: NSError?
        guard generate(
            runner,
            Self.runnerGenerateSelector,
            prompt as NSString,
            config,
            callback,
            &generateError
        ) else {
            throw generateError ?? Self.error("ExecuTorch generation failed")
        }
    }

    private static func objcMessage<Function>() throws -> Function {
        guard let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "objc_msgSend") else {
            throw error("Unable to resolve objc_msgSend")
        }
        return unsafeBitCast(symbol, to: Function.self)
    }

    private static func requireInstanceMethod(_ selector: Selector, on cls: AnyClass) throws {
        guard hasInstanceMethod(cls, selector) else {
            throw error("ExecuTorch API selector missing: \(NSStringFromSelector(selector))")
        }
    }

    private static func hasInstanceMethod(_ cls: AnyClass, _ selector: Selector) -> Bool {
        class_getInstanceMethod(cls, selector) != nil
    }

    private static func findClass(_ name: String) -> AnyClass? {
        NSClassFromString(name) ?? NSClassFromString("ExecuTorchLLM.\(name)")
    }

    private static func error(_ description: String) -> NSError {
        NSError(domain: "CapgoLLM.ExecuTorch", code: 1, userInfo: [NSLocalizedDescriptionKey: description])
    }
}

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
