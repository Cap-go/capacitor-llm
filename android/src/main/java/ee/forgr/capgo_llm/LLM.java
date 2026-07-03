package ee.forgr.capgo_llm;

import android.content.Context;
import android.os.Build;
import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Content;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.SamplerConfig;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;
import com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions;
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession;
import com.google.mlkit.genai.common.FeatureStatus;
import com.google.mlkit.genai.common.StreamingCallback;
import com.google.mlkit.genai.prompt.Candidate;
import com.google.mlkit.genai.prompt.GenerateContentRequest;
import com.google.mlkit.genai.prompt.GenerateContentResponse;
import com.google.mlkit.genai.prompt.Generation;
import com.google.mlkit.genai.prompt.TextPart;
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Collections;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CancellationException;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

public class LLM {

    private enum BackendType {
        LITERT,
        MEDIAPIPE,
        GEMINI_NANO
    }

    private static final double DEFAULT_TOP_P = 0.95d;
    private static LLM instance;

    private final Context context;
    private final Executor executor;
    private final Map<String, ChatSession> chatSessions;

    private Engine engine;
    private GenerativeModelFutures geminiNanoModel;
    private LlmInference llmInference;
    private boolean isReady = false;
    private String modelPath = null;
    private String modelType = null;
    private BackendType activeBackend = BackendType.LITERT;
    private long currentLoadId = 0L;

    private Integer maxTokens = 2048;
    private Integer topk = 40;
    private Float temperature = 0.1f;
    private Integer randomSeed = 101;

    private LLM(Context context) {
        this.context = context;
        this.chatSessions = new ConcurrentHashMap<>();
        this.executor = Executors.newSingleThreadExecutor();
    }

    public static LLM getInstance(Context context) {
        if (instance == null) {
            instance = new LLM(context);
        }
        return instance;
    }

    public void setModel(
        String path,
        String modelType,
        Integer maxTokens,
        Integer topk,
        Float temperature,
        Integer randomSeed,
        ModelLoadCallback callback
    ) {
        ModelLoadRequest request = nextLoadRequest(path, modelType, maxTokens, topk, temperature, randomSeed);
        resetModelState();

        android.util.Log.d(
            "LLM",
            "setModel called with path: " +
                request.modelPath +
                ", modelType: " +
                request.modelType +
                ", maxTokens: " +
                request.maxTokens +
                ", topk: " +
                request.topk +
                ", temperature: " +
                request.temperature
        );
        initializeModel(request, callback);
    }

    private synchronized ModelLoadRequest nextLoadRequest(
        String path,
        String modelType,
        Integer maxTokens,
        Integer topk,
        Float temperature,
        Integer randomSeed
    ) {
        currentLoadId += 1;
        return new ModelLoadRequest(path, modelType, maxTokens, topk, temperature, randomSeed, currentLoadId);
    }

    private synchronized boolean isCurrentLoad(long loadId) {
        return loadId == currentLoadId;
    }

    private void initializeModel(ModelLoadRequest request, ModelLoadCallback callback) {
        if (request.modelPath == null) {
            if (callback != null) {
                callback.onError("Model path not set");
            }
            return;
        }

        executor.execute(() -> {
            try {
                if (!isCurrentLoad(request.loadId)) {
                    notifySupersededLoad(callback);
                    return;
                }

                BackendType backend = resolveBackend(request.modelPath, request.modelType);
                String actualPath = backend == BackendType.GEMINI_NANO ? request.modelPath : resolveModelPath(request.modelPath, backend);

                android.util.Log.d("LLM", "Resolved model path: " + actualPath + " using backend: " + backend);

                if (backend == BackendType.LITERT) {
                    Engine loadedEngine = initializeLiteRtModel(actualPath, request);
                    if (!isCurrentLoad(request.loadId)) {
                        closeEngine(loadedEngine);
                        notifySupersededLoad(callback);
                        return;
                    }
                    applyLoadedModel(request, backend, loadedEngine, null, null);
                } else {
                    if (backend == BackendType.GEMINI_NANO) {
                        initializeGeminiNanoModel(request, callback);
                        return;
                    }

                    LlmInference loadedInference = initializeMediaPipeModel(actualPath, request);
                    if (!isCurrentLoad(request.loadId)) {
                        closeLlmInference(loadedInference);
                        notifySupersededLoad(callback);
                        return;
                    }
                    applyLoadedModel(request, backend, null, loadedInference, null);
                }

                if (callback != null) {
                    callback.onSuccess();
                }
            } catch (Exception exception) {
                if (!isCurrentLoad(request.loadId)) {
                    notifySupersededLoad(callback);
                    return;
                }

                android.util.Log.e("LLM", "Failed to initialize model", exception);
                resetModelState();

                if (callback != null) {
                    callback.onError(exception.getMessage());
                }
            }
        });
    }

    private void notifySupersededLoad(ModelLoadCallback callback) {
        if (callback != null) {
            callback.onError("Model load was superseded by a newer request");
        }
    }

    private synchronized void applyLoadedModel(
        ModelLoadRequest request,
        BackendType backend,
        Engine loadedEngine,
        LlmInference loadedInference,
        GenerativeModelFutures loadedGeminiNanoModel
    ) {
        modelPath = request.modelPath;
        modelType = request.modelType;
        maxTokens = request.maxTokens;
        topk = request.topk;
        temperature = request.temperature;
        randomSeed = request.randomSeed;
        activeBackend = backend;
        engine = loadedEngine;
        llmInference = loadedInference;
        geminiNanoModel = loadedGeminiNanoModel;
        isReady = true;
    }

    private Engine initializeLiteRtModel(String actualPath, ModelLoadRequest request) {
        EngineConfig config = new EngineConfig(
            actualPath,
            new Backend.CPU(),
            new Backend.CPU(),
            new Backend.CPU(),
            request.maxTokens,
            context.getCacheDir().getAbsolutePath()
        );
        Engine loadedEngine = new Engine(config);
        loadedEngine.initialize();
        return loadedEngine;
    }

    private LlmInference initializeMediaPipeModel(String actualPath, ModelLoadRequest request) {
        LlmInferenceOptions options = LlmInferenceOptions.builder()
            .setModelPath(actualPath)
            .setMaxTokens(request.maxTokens)
            .setMaxTopK(request.topk)
            .build();
        return LlmInference.createFromOptions(context, options);
    }

    private void initializeGeminiNanoModel(ModelLoadRequest request, ModelLoadCallback callback) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            if (callback != null) {
                callback.onError("Gemini Nano requires Android API 26 or higher");
            }
            return;
        }

        GenerativeModelFutures loadedModel = GenerativeModelFutures.from(Generation.INSTANCE.getClient());
        ListenableFuture<Integer> statusFuture = loadedModel.checkStatus();
        statusFuture.addListener(
            () -> {
                try {
                    if (!isCurrentLoad(request.loadId)) {
                        notifySupersededLoad(callback);
                        return;
                    }

                    Integer status = statusFuture.get();
                    if (status == FeatureStatus.AVAILABLE) {
                        applyLoadedModel(request, BackendType.GEMINI_NANO, null, null, loadedModel);
                        if (callback != null) {
                            callback.onSuccess();
                        }
                        return;
                    }

                    resetModelState();
                    if (callback != null) {
                        callback.onError("Gemini Nano is " + geminiNanoStatusName(status) + " on this device");
                    }
                } catch (CancellationException | ExecutionException exception) {
                    resetModelState();
                    if (callback != null) {
                        callback.onError(exception.getMessage());
                    }
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    resetModelState();
                    if (callback != null) {
                        callback.onError(exception.getMessage());
                    }
                }
            },
            executor
        );
    }

    private String geminiNanoStatusName(Integer status) {
        if (status == null) {
            return "unknown";
        }

        switch (status) {
            case FeatureStatus.UNAVAILABLE:
                return "unavailable";
            case FeatureStatus.DOWNLOADABLE:
                return "downloadable but not downloaded";
            case FeatureStatus.DOWNLOADING:
                return "downloading";
            case FeatureStatus.AVAILABLE:
                return "available";
            default:
                return "unknown";
        }
    }

    private BackendType resolveBackend(String path, String modelType) {
        if (isGeminiNanoModel(path, modelType)) {
            return BackendType.GEMINI_NANO;
        }

        return "litertlm".equals(normalizeModelType(path, modelType)) ? BackendType.LITERT : BackendType.MEDIAPIPE;
    }

    private boolean isGeminiNanoModel(String path, String modelType) {
        String requestedModel = modelType != null && !modelType.isBlank() ? modelType : path;
        return "gemininano".equals(normalizeSystemModelName(requestedModel));
    }

    private String normalizeSystemModelName(String value) {
        return stripUrlSuffix(value).toLowerCase().replace("-", "").replace("_", "").replace(" ", "");
    }

    private String normalizeModelType(String path, String modelType) {
        if (modelType != null && !modelType.isBlank()) {
            return stripUrlSuffix(modelType).toLowerCase();
        }

        String normalizedPath = stripUrlSuffix(path);
        int extensionIndex = normalizedPath.lastIndexOf('.');
        if (extensionIndex == -1 || extensionIndex == normalizedPath.length() - 1) {
            return "";
        }

        return normalizedPath.substring(extensionIndex + 1).toLowerCase();
    }

    private String stripUrlSuffix(String value) {
        int cutoff = value.length();
        int queryIndex = value.indexOf('?');
        int fragmentIndex = value.indexOf('#');

        if (queryIndex >= 0 && queryIndex < cutoff) {
            cutoff = queryIndex;
        }
        if (fragmentIndex >= 0 && fragmentIndex < cutoff) {
            cutoff = fragmentIndex;
        }

        return value.substring(0, cutoff);
    }

    private String resolveModelPath(String path, BackendType backendType) throws Exception {
        if (!path.startsWith("/android_asset/")) {
            return path;
        }

        String assetPath = path.substring("/android_asset/".length());
        File cacheDir = context.getCacheDir();
        File modelFile = new File(cacheDir, assetPath);

        copyAssetToFile(assetPath, modelFile);

        if (backendType == BackendType.MEDIAPIPE && assetPath.endsWith(".task")) {
            String companionPath = assetPath.replace(".task", ".litertlm");
            try {
                copyAssetToFile(companionPath, new File(cacheDir, companionPath));
            } catch (Exception exception) {
                android.util.Log.d("LLM", "No MediaPipe companion file found for " + assetPath);
            }
        }

        return modelFile.getAbsolutePath();
    }

    private void copyAssetToFile(String assetPath, File destination) throws Exception {
        File parent = destination.getParentFile();
        if (parent != null && !parent.exists()) {
            parent.mkdirs();
        }

        try (
            InputStream inputStream = context.getAssets().open(assetPath);
            FileOutputStream outputStream = new FileOutputStream(destination)
        ) {
            byte[] buffer = new byte[8192];
            int length;
            while ((length = inputStream.read(buffer)) > 0) {
                outputStream.write(buffer, 0, length);
            }
        }
    }

    public synchronized String createChat() {
        if (!isReady) {
            throw new IllegalStateException("Model not ready");
        }

        String chatId = UUID.randomUUID().toString();
        ChatSession session;

        if (activeBackend == BackendType.LITERT) {
            if (engine == null) {
                throw new IllegalStateException("LiteRT-LM engine not initialized");
            }
            session = ChatSession.forLiteRt(createLiteRtConversation());
        } else if (activeBackend == BackendType.GEMINI_NANO) {
            if (geminiNanoModel == null) {
                throw new IllegalStateException("Gemini Nano model not initialized");
            }
            session = ChatSession.forGeminiNano();
        } else {
            if (llmInference == null) {
                throw new IllegalStateException("MediaPipe model not initialized");
            }
            session = ChatSession.forMediaPipe();
        }

        chatSessions.put(chatId, session);
        return chatId;
    }

    private Conversation createLiteRtConversation() {
        ConversationConfig defaults = new ConversationConfig();
        SamplerConfig samplerConfig = new SamplerConfig(topk, DEFAULT_TOP_P, temperature.doubleValue(), randomSeed);
        ConversationConfig config = defaults.copy(
            defaults.getSystemInstruction(),
            defaults.getInitialMessages(),
            defaults.getTools(),
            samplerConfig,
            defaults.getAutomaticToolCalling(),
            defaults.getChannels()
        );
        return engine.createConversation(config);
    }

    public void sendMessage(String chatId, String message, MessageCallback callback) {
        ChatSession session;
        LlmInference inference;
        GenerativeModelFutures nanoModel;
        Integer sessionTopk;
        Float sessionTemperature;
        Integer sessionMaxTokens;
        Integer sessionRandomSeed;
        synchronized (this) {
            session = chatSessions.get(chatId);
            if (session == null) {
                throw new IllegalStateException("Chat session not found");
            }

            if (!isReady) {
                throw new IllegalStateException("Model not ready");
            }

            inference = llmInference;
            nanoModel = geminiNanoModel;
            sessionTopk = topk;
            sessionTemperature = temperature;
            sessionMaxTokens = maxTokens;
            sessionRandomSeed = randomSeed;
        }

        if (session.backendType == BackendType.LITERT) {
            sendMessageWithLiteRt(chatId, message, session, callback);
            return;
        }

        if (session.backendType == BackendType.GEMINI_NANO) {
            if (nanoModel == null) {
                throw new IllegalStateException("Gemini Nano model not ready");
            }

            sendMessageWithGeminiNano(
                chatId,
                message,
                session,
                nanoModel,
                sessionMaxTokens,
                sessionTopk,
                sessionTemperature,
                sessionRandomSeed,
                callback
            );
            return;
        }

        if (inference == null) {
            throw new IllegalStateException("MediaPipe model not ready");
        }

        sendMessageWithMediaPipe(chatId, message, session, inference, sessionTopk, sessionTemperature, callback);
    }

    private void sendMessageWithLiteRt(String chatId, String message, ChatSession session, MessageCallback callback) {
        if (session.conversation == null) {
            throw new IllegalStateException("LiteRT-LM conversation not found");
        }

        session.conversation.sendMessageAsync(
            message,
            new com.google.ai.edge.litertlm.MessageCallback() {
                @Override
                public void onMessage(Message responseMessage) {
                    String chunk = extractText(responseMessage);
                    if (!chunk.isEmpty()) {
                        callback.onTextReceived(chatId, chunk, true);
                    }
                }

                @Override
                public void onDone() {
                    callback.onComplete(chatId);
                }

                @Override
                public void onError(Throwable throwable) {
                    callback.onError(throwable.getMessage());
                }
            },
            Collections.emptyMap()
        );
    }

    private String extractText(Message responseMessage) {
        StringBuilder builder = new StringBuilder();

        for (Content content : responseMessage.getContents().getContents()) {
            if (content instanceof Content.Text) {
                builder.append(((Content.Text) content).getText());
            }
        }

        return builder.toString();
    }

    private void sendMessageWithGeminiNano(
        String chatId,
        String message,
        ChatSession session,
        GenerativeModelFutures nanoModel,
        Integer sessionMaxTokens,
        Integer sessionTopk,
        Float sessionTemperature,
        Integer sessionRandomSeed,
        MessageCallback callback
    ) {
        synchronized (session) {
            session.addMessage("user", message);
        }

        GenerateContentRequest.Builder requestBuilder;
        synchronized (session) {
            requestBuilder = new GenerateContentRequest.Builder(new TextPart(session.buildPrompt()));
        }

        requestBuilder.setMaxOutputTokens(Math.min(sessionMaxTokens, 256));
        requestBuilder.setTopK(sessionTopk);
        requestBuilder.setTemperature(sessionTemperature);
        requestBuilder.setSeed(sessionRandomSeed);

        StringBuffer fullResponse = new StringBuffer();
        AtomicBoolean streamed = new AtomicBoolean(false);
        ListenableFuture<GenerateContentResponse> responseFuture = nanoModel.generateContent(
            requestBuilder.build(),
            new StreamingCallback() {
                @Override
                public void onNewText(String additionalText) {
                    if (additionalText == null || additionalText.isEmpty()) {
                        return;
                    }

                    streamed.set(true);
                    fullResponse.append(additionalText);
                    callback.onTextReceived(chatId, additionalText, true);
                }
            }
        );

        responseFuture.addListener(
            () -> {
                try {
                    GenerateContentResponse response = responseFuture.get();
                    if (!streamed.get()) {
                        String text = extractText(response);
                        if (!text.isEmpty()) {
                            fullResponse.append(text);
                            callback.onTextReceived(chatId, text, true);
                        }
                    }

                    synchronized (session) {
                        session.addMessage("assistant", fullResponse.toString());
                    }
                    callback.onComplete(chatId);
                } catch (CancellationException | ExecutionException exception) {
                    callback.onError(exception.getMessage());
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    callback.onError(exception.getMessage());
                }
            },
            executor
        );
    }

    private String extractText(GenerateContentResponse response) {
        if (response.getCandidates().isEmpty()) {
            return "";
        }

        Candidate candidate = response.getCandidates().get(0);
        return candidate.getText();
    }

    private void sendMessageWithMediaPipe(
        String chatId,
        String message,
        ChatSession session,
        LlmInference inference,
        Integer sessionTopk,
        Float sessionTemperature,
        MessageCallback callback
    ) {
        executor.execute(() -> {
            LlmInferenceSession inferenceSession = null;
            try {
                session.addMessage("user", message);

                String fullPrompt = session.buildPrompt();
                android.util.Log.d("LLM", "Full prompt: " + fullPrompt);

                LlmInferenceSession.LlmInferenceSessionOptions sessionOptions = LlmInferenceSession.LlmInferenceSessionOptions.builder()
                    .setTopK(sessionTopk)
                    .setTemperature(sessionTemperature)
                    .build();

                inferenceSession = LlmInferenceSession.createFromOptions(inference, sessionOptions);
                LlmInferenceSession activeSession = inferenceSession;

                inferenceSession.addQueryChunk(fullPrompt);

                final StringBuilder fullResponse = new StringBuilder();

                com.google.mediapipe.tasks.genai.llminference.ProgressListener<String> resultListener =
                    new com.google.mediapipe.tasks.genai.llminference.ProgressListener<String>() {
                        private StringBuilder buffer = new StringBuilder();
                        private boolean hasStarted = false;

                        @Override
                        public void run(String partialResult, boolean done) {
                            android.util.Log.d("LLM", "Partial result: " + partialResult + ", done: " + done);

                            buffer.append(partialResult);

                            String content = buffer.toString();
                            StringBuilder toSend = new StringBuilder();
                            int i = 0;
                            while (i < content.length()) {
                                if (i < content.length() - 1 && content.charAt(i) == '\\' && content.charAt(i + 1) == 'n') {
                                    toSend.append('\n');
                                    i += 2;
                                } else if (i == content.length() - 1 && content.charAt(i) == '\\' && !done) {
                                    break;
                                } else {
                                    toSend.append(content.charAt(i));
                                    i++;
                                }
                            }

                            buffer = new StringBuilder(content.substring(i));

                            String chunk = toSend.toString();

                            if (!hasStarted && !chunk.isEmpty()) {
                                chunk = chunk.replaceFirst("^\\n", "");
                                hasStarted = true;
                            }

                            if (!chunk.isEmpty()) {
                                callback.onTextReceived(chatId, chunk, true);
                                fullResponse.append(chunk);
                            }

                            if (done && buffer.length() > 0) {
                                String remaining = buffer.toString();
                                if (!remaining.isEmpty()) {
                                    callback.onTextReceived(chatId, remaining, true);
                                    fullResponse.append(remaining);
                                }
                            }

                            if (done) {
                                session.addMessage("assistant", fullResponse.toString());
                                callback.onComplete(chatId);
                                closeMediaPipeSession(activeSession);
                            }
                        }
                    };

                inferenceSession.generateResponseAsync(resultListener);
            } catch (Exception exception) {
                closeMediaPipeSession(inferenceSession);
                callback.onError(exception.getMessage());
            }
        });
    }

    public synchronized String getReadiness() {
        return isReady ? "ready" : "not_ready";
    }

    private synchronized void resetModelState() {
        clearChatSessions();

        closeEngine(engine);
        closeLlmInference(llmInference);
        engine = null;
        llmInference = null;
        geminiNanoModel = null;
        modelPath = null;
        modelType = null;
        isReady = false;
    }

    private void closeEngine(Engine loadedEngine) {
        if (loadedEngine != null) {
            try {
                loadedEngine.close();
            } catch (Exception exception) {
                android.util.Log.w("LLM", "Failed to close LiteRT-LM engine", exception);
            }
        }
    }

    private void closeMediaPipeSession(LlmInferenceSession inferenceSession) {
        if (inferenceSession != null) {
            try {
                inferenceSession.close();
            } catch (Exception exception) {
                android.util.Log.e("LLM", "Failed to close MediaPipe session", exception);
            }
        }
    }

    private void closeLlmInference(LlmInference inference) {
        if (inference != null) {
            try {
                inference.close();
            } catch (Exception exception) {
                android.util.Log.w("LLM", "Failed to close MediaPipe model", exception);
            }
        }
    }

    private void clearChatSessions() {
        for (ChatSession session : chatSessions.values()) {
            if (session.conversation != null) {
                try {
                    session.conversation.close();
                } catch (Exception exception) {
                    android.util.Log.w("LLM", "Failed to close LiteRT-LM conversation", exception);
                }
            }
        }

        chatSessions.clear();
    }

    public interface MessageCallback {
        void onTextReceived(String chatId, String text, boolean isChunk);
        void onComplete(String chatId);
        void onError(String error);
    }

    public interface ModelLoadCallback {
        void onSuccess();
        void onError(String error);
    }

    private static class ChatSession {

        private final BackendType backendType;
        private final Conversation conversation;
        private final StringBuilder history;

        private ChatSession(BackendType backendType, Conversation conversation) {
            this.backendType = backendType;
            this.conversation = conversation;
            this.history = new StringBuilder();
        }

        static ChatSession forLiteRt(Conversation conversation) {
            return new ChatSession(BackendType.LITERT, conversation);
        }

        static ChatSession forMediaPipe() {
            return new ChatSession(BackendType.MEDIAPIPE, null);
        }

        static ChatSession forGeminiNano() {
            return new ChatSession(BackendType.GEMINI_NANO, null);
        }

        void addMessage(String role, String content) {
            if (history.length() > 0) {
                history.append("\n");
            }
            if (role.equals("user")) {
                history.append("User: ").append(content);
            } else {
                history.append("Assistant: ").append(content);
            }
        }

        String buildPrompt() {
            return history.toString();
        }
    }

    private static class ModelLoadRequest {

        private final String modelPath;
        private final String modelType;
        private final Integer maxTokens;
        private final Integer topk;
        private final Float temperature;
        private final Integer randomSeed;
        private final long loadId;

        private ModelLoadRequest(
            String modelPath,
            String modelType,
            Integer maxTokens,
            Integer topk,
            Float temperature,
            Integer randomSeed,
            long loadId
        ) {
            this.modelPath = modelPath;
            this.modelType = modelType;
            this.maxTokens = maxTokens;
            this.topk = topk;
            this.temperature = temperature;
            this.randomSeed = randomSeed;
            this.loadId = loadId;
        }
    }
}
