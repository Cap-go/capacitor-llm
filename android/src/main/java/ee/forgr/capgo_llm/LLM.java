package ee.forgr.capgo_llm;

import android.content.Context;
import com.google.ai.edge.litertlm.Backend;
import com.google.ai.edge.litertlm.Content;
import com.google.ai.edge.litertlm.Conversation;
import com.google.ai.edge.litertlm.ConversationConfig;
import com.google.ai.edge.litertlm.Engine;
import com.google.ai.edge.litertlm.EngineConfig;
import com.google.ai.edge.litertlm.Message;
import com.google.ai.edge.litertlm.SamplerConfig;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;
import com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

public class LLM {

    private enum BackendType {
        LITERT,
        MEDIAPIPE
    }

    private static final double DEFAULT_TOP_P = 0.95d;
    private static LLM instance;

    private final Context context;
    private final Executor executor;
    private final Map<String, ChatSession> chatSessions;

    private Engine engine;
    private LlmInference llmInference;
    private boolean isReady = false;
    private String modelPath = null;
    private String modelType = null;
    private BackendType activeBackend = BackendType.LITERT;

    private Integer maxTokens = 2048;
    private Integer topk = 40;
    private Float temperature = 0.1f;
    private Integer randomSeed = 101;

    private LLM(Context context) {
        this.context = context;
        this.chatSessions = new HashMap<>();
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
        this.modelPath = path;
        this.modelType = modelType;
        this.maxTokens = maxTokens;
        this.topk = topk;
        this.temperature = temperature;
        this.randomSeed = randomSeed;

        resetModelState();

        android.util.Log.d(
            "LLM",
            "setModel called with path: " +
                path +
                ", modelType: " +
                modelType +
                ", maxTokens: " +
                maxTokens +
                ", topk: " +
                topk +
                ", temperature: " +
                temperature
        );
        initializeModel(callback);
    }

    private void initializeModel(ModelLoadCallback callback) {
        if (modelPath == null) {
            if (callback != null) {
                callback.onError("Model path not set");
            }
            return;
        }

        executor.execute(() -> {
            try {
                activeBackend = resolveBackend(modelPath, modelType);
                String actualPath = resolveModelPath(modelPath, activeBackend);

                android.util.Log.d("LLM", "Resolved model path: " + actualPath + " using backend: " + activeBackend);

                if (activeBackend == BackendType.LITERT) {
                    initializeLiteRtModel(actualPath);
                } else {
                    initializeMediaPipeModel(actualPath);
                }

                isReady = true;

                if (callback != null) {
                    callback.onSuccess();
                }
            } catch (Exception exception) {
                android.util.Log.e("LLM", "Failed to initialize model", exception);
                resetModelState();

                if (callback != null) {
                    callback.onError(exception.getMessage());
                }
            }
        });
    }

    private void initializeLiteRtModel(String actualPath) {
        EngineConfig config = new EngineConfig(
            actualPath,
            new Backend.CPU(),
            new Backend.CPU(),
            new Backend.CPU(),
            maxTokens,
            context.getCacheDir().getAbsolutePath()
        );
        engine = new Engine(config);
        engine.initialize();
    }

    private void initializeMediaPipeModel(String actualPath) {
        LlmInferenceOptions options = LlmInferenceOptions.builder()
            .setModelPath(actualPath)
            .setMaxTokens(maxTokens)
            .setMaxTopK(topk)
            .build();
        llmInference = LlmInference.createFromOptions(context, options);
    }

    private BackendType resolveBackend(String path, String modelType) {
        return "litertlm".equals(normalizeModelType(path, modelType)) ? BackendType.LITERT : BackendType.MEDIAPIPE;
    }

    private String normalizeModelType(String path, String modelType) {
        if (modelType != null && !modelType.isBlank()) {
            return modelType.toLowerCase();
        }

        int extensionIndex = path.lastIndexOf('.');
        if (extensionIndex == -1 || extensionIndex == path.length() - 1) {
            return "";
        }

        return path.substring(extensionIndex + 1).toLowerCase();
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

    public String createChat() {
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
        ChatSession session = chatSessions.get(chatId);
        if (session == null) {
            throw new IllegalStateException("Chat session not found");
        }

        if (!isReady) {
            throw new IllegalStateException("Model not ready");
        }

        if (session.backendType == BackendType.LITERT) {
            sendMessageWithLiteRt(chatId, message, session, callback);
            return;
        }

        if (llmInference == null) {
            throw new IllegalStateException("MediaPipe model not ready");
        }

        sendMessageWithMediaPipe(chatId, message, session, callback);
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

    private void sendMessageWithMediaPipe(String chatId, String message, ChatSession session, MessageCallback callback) {
        executor.execute(() -> {
            try {
                session.addMessage("user", message);

                String fullPrompt = session.buildPrompt(message);
                android.util.Log.d("LLM", "Full prompt: " + fullPrompt);

                com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.LlmInferenceSessionOptions sessionOptions =
                    com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.LlmInferenceSessionOptions.builder()
                        .setTopK(topk)
                        .setTemperature(temperature)
                        .build();

                com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession inferenceSession =
                    com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.createFromOptions(llmInference, sessionOptions);

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

                                try {
                                    inferenceSession.close();
                                } catch (Exception exception) {
                                    android.util.Log.e("LLM", "Failed to close MediaPipe session", exception);
                                }
                            }
                        }
                    };

                inferenceSession.generateResponseAsync(resultListener);
            } catch (Exception exception) {
                callback.onError(exception.getMessage());
            }
        });
    }

    public String getReadiness() {
        return isReady ? "ready" : "not_ready";
    }

    private void resetModelState() {
        clearChatSessions();

        if (engine != null) {
            try {
                engine.close();
            } catch (Exception exception) {
                android.util.Log.w("LLM", "Failed to close LiteRT-LM engine", exception);
            }
            engine = null;
        }

        llmInference = null;
        isReady = false;
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

        String buildPrompt(String newMessage) {
            return newMessage;
        }
    }
}
