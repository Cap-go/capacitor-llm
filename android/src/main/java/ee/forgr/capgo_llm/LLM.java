package ee.forgr.capgo_llm;

import android.content.Context;
import com.google.mediapipe.tasks.genai.llminference.LlmInference;
import com.google.mediapipe.tasks.genai.llminference.LlmInference.LlmInferenceOptions;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import org.pytorch.executorch.extension.llm.LlmCallback;
import org.pytorch.executorch.extension.llm.LlmModule;

public class LLM {

    private enum Engine {
        MEDIAPIPE,
        EXECUTORCH
    }

    private static LLM instance;
    private LlmInference mediaPipeInference;
    private LlmModule executorchModule;
    private Map<String, ChatSession> chatSessions;
    private boolean isReady = false;
    private Context context;
    private Executor executor;
    private String modelPath = null;
    private String tokenizerPath = null;
    private Engine currentEngine = Engine.MEDIAPIPE;

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

    // Model parameters
    private Integer maxTokens = 2048;
    private Integer sequenceLength = 2048;
    private Integer topk = 40;
    private Float temperature = 0.1f;
    private String modelType = null;

    public void setModel(
        String path,
        String engine,
        String modelType,
        String tokenizerPath,
        List<String> specialTokens,
        Integer maxTokens,
        Integer sequenceLength,
        Integer topk,
        Float temperature,
        ModelLoadCallback callback
    ) {
        this.modelPath = path;
        this.tokenizerPath = tokenizerPath;
        this.modelType = modelType;
        this.maxTokens = maxTokens;
        this.sequenceLength = sequenceLength != null ? sequenceLength : maxTokens;
        this.topk = topk;
        this.temperature = temperature;
        try {
            this.currentEngine = resolveEngine(engine, path, tokenizerPath);
        } catch (IllegalArgumentException e) {
            isReady = false;
            if (callback != null) {
                callback.onError(e.getMessage());
            }
            return;
        }
        isReady = false;

        releaseCurrentModel();

        android.util.Log.d(
            "LLM",
            "setModel called with engine: " +
                currentEngine +
                ", path: " +
                path +
                ", tokenizerPath: " +
                tokenizerPath +
                ", maxTokens: " +
                maxTokens +
                ", sequenceLength: " +
                this.sequenceLength +
                ", topk: " +
                topk +
                ", temperature: " +
                temperature +
                ", specialTokens: " +
                (specialTokens == null ? 0 : specialTokens.size())
        );
        initializeModel(callback);
    }

    private Engine resolveEngine(String engine, String path, String tokenizerPath) {
        String normalizedEngine = engine == null ? "auto" : engine.toLowerCase(Locale.US);
        if ("executorch".equals(normalizedEngine)) {
            return Engine.EXECUTORCH;
        }
        if ("mediapipe".equals(normalizedEngine)) {
            return Engine.MEDIAPIPE;
        }
        if ("apple".equals(normalizedEngine)) {
            throw new IllegalArgumentException("Apple Intelligence is only available on iOS");
        }
        if (tokenizerPath != null && !tokenizerPath.isEmpty()) {
            return Engine.EXECUTORCH;
        }
        if (path != null && path.toLowerCase(Locale.US).endsWith(".pte")) {
            return Engine.EXECUTORCH;
        }
        return Engine.MEDIAPIPE;
    }

    private void releaseCurrentModel() {
        if (mediaPipeInference != null) {
            try {
                mediaPipeInference.close();
            } catch (Exception e) {
                android.util.Log.w("LLM", "Failed to close MediaPipe inference: " + e.getMessage());
            } finally {
                mediaPipeInference = null;
            }
        }

        if (executorchModule != null) {
            try {
                executorchModule.stop();
            } catch (Exception e) {
                android.util.Log.w("LLM", "Failed to stop ExecuTorch module: " + e.getMessage());
            } finally {
                executorchModule = null;
            }
        }
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
                if (currentEngine == Engine.EXECUTORCH) {
                    initializeExecutorchModel();
                } else {
                    initializeMediaPipeModel();
                }
                isReady = true;

                if (callback != null) {
                    callback.onSuccess();
                }
            } catch (Exception e) {
                isReady = false;
                e.printStackTrace();
                if (callback != null) {
                    callback.onError(e.getMessage());
                }
            }
        });
    }

    private void initializeMediaPipeModel() throws Exception {
        String actualPath = resolveModelPath(modelPath, true);
        android.util.Log.d("LLM", "Final MediaPipe model path: " + actualPath);

        LlmInferenceOptions.Builder optionsBuilder = LlmInferenceOptions.builder()
            .setModelPath(actualPath)
            .setMaxTokens(maxTokens)
            .setMaxTopK(topk);

        LlmInferenceOptions options = optionsBuilder.build();
        mediaPipeInference = LlmInference.createFromOptions(context, options);
    }

    private void initializeExecutorchModel() throws Exception {
        if (tokenizerPath == null || tokenizerPath.isEmpty()) {
            throw new RuntimeException("tokenizerPath is required for ExecuTorch models");
        }

        String actualModelPath = resolveModelPath(modelPath, false);
        String actualTokenizerPath = resolveModelPath(tokenizerPath, false);
        int executorModelType = resolveExecutorchModelType(modelType);

        android.util.Log.d("LLM", "Final ExecuTorch model path: " + actualModelPath);
        android.util.Log.d("LLM", "Final ExecuTorch tokenizer path: " + actualTokenizerPath);

        executorchModule = new LlmModule(executorModelType, actualModelPath, actualTokenizerPath, temperature);
        executorchModule.load();
    }

    private int resolveExecutorchModelType(String modelType) {
        if (modelType == null) {
            return LlmModule.MODEL_TYPE_TEXT;
        }
        String normalized = modelType.toLowerCase(Locale.US);
        if ("text-vision".equals(normalized) || "vision".equals(normalized)) {
            return LlmModule.MODEL_TYPE_TEXT_VISION;
        }
        if ("multimodal".equals(normalized)) {
            return LlmModule.MODEL_TYPE_MULTIMODAL;
        }
        return LlmModule.MODEL_TYPE_TEXT;
    }

    private String resolveModelPath(String path, boolean copyMediaPipeCompanion) throws Exception {
        android.util.Log.d("LLM", "Original model path: " + path);

        if (!path.startsWith("/android_asset/")) {
            return path;
        }

        String assetPath = path.substring("/android_asset/".length());
        android.util.Log.d("LLM", "Asset path: " + assetPath);

        try (java.io.InputStream is = context.getAssets().open(assetPath)) {
            android.util.Log.d("LLM", "Asset exists: " + assetPath);
        } catch (Exception e) {
            android.util.Log.e("LLM", "Asset not found: " + assetPath, e);
            throw new RuntimeException("Asset not found: " + assetPath);
        }

        java.io.File cacheDir = context.getCacheDir();
        java.io.File modelFile = new java.io.File(cacheDir, assetPath);
        java.io.File parent = modelFile.getParentFile();
        if (parent != null) {
            parent.mkdirs();
        }

        copyAssetToFile(assetPath, modelFile);
        android.util.Log.d("LLM", "Copied asset to: " + modelFile.getAbsolutePath());

        if (copyMediaPipeCompanion && assetPath.endsWith(".task")) {
            copyOptionalCompanion(assetPath, cacheDir);
        }

        return modelFile.getAbsolutePath();
    }

    private void copyOptionalCompanion(String assetPath, java.io.File cacheDir) {
        String litertlmPath = assetPath.replace(".task", ".litertlm");
        try (java.io.InputStream litertlmIs = context.getAssets().open(litertlmPath)) {
            java.io.File litertlmFile = new java.io.File(cacheDir, litertlmPath);
            java.io.File parent = litertlmFile.getParentFile();
            if (parent != null) {
                parent.mkdirs();
            }
            copyAssetToFile(litertlmPath, litertlmFile);
            android.util.Log.d("LLM", "Also copied companion file: " + litertlmFile.getAbsolutePath());
        } catch (Exception e) {
            android.util.Log.d("LLM", "No companion .litertlm file found");
        }
    }

    private void copyAssetToFile(String assetPath, java.io.File destFile) throws Exception {
        try (
            java.io.InputStream is = context.getAssets().open(assetPath);
            java.io.FileOutputStream fos = new java.io.FileOutputStream(destFile)
        ) {
            byte[] buffer = new byte[4096];
            int length;
            while ((length = is.read(buffer)) > 0) {
                fos.write(buffer, 0, length);
            }
        }
    }

    public String createChat() {
        String chatId = UUID.randomUUID().toString();
        ChatSession session = new ChatSession();
        chatSessions.put(chatId, session);
        return chatId;
    }

    public void sendMessage(String chatId, String message, MessageCallback callback) {
        ChatSession session = chatSessions.get(chatId);
        if (session == null) {
            callback.onError("Chat session not found");
            return;
        }

        if (!isReady) {
            callback.onError("Model not ready");
            return;
        }

        if (currentEngine == Engine.EXECUTORCH) {
            sendExecutorchMessage(chatId, message, session, callback);
        } else {
            sendMediaPipeMessage(chatId, message, session, callback);
        }
    }

    private void sendExecutorchMessage(String chatId, String message, ChatSession session, MessageCallback callback) {
        if (executorchModule == null) {
            callback.onError("ExecuTorch model not ready");
            return;
        }

        executor.execute(() -> {
            try {
                session.addMessage("user", message);
                String fullPrompt = session.buildPrompt(message);
                AtomicBoolean completed = new AtomicBoolean(false);
                StringBuilder fullResponse = new StringBuilder();

                executorchModule.resetContext();
                int errorCode = executorchModule.generate(
                    fullPrompt,
                    sequenceLength,
                    new LlmCallback() {
                        @Override
                        public void onResult(String result) {
                            if (result == null || result.isEmpty()) {
                                return;
                            }
                            callback.onTextReceived(chatId, result, true);
                            fullResponse.append(result);
                        }

                        @Override
                        public void onStats(String stats) {
                            if (completed.compareAndSet(false, true)) {
                                session.addMessage("assistant", fullResponse.toString());
                                callback.onComplete(chatId);
                            }
                        }
                    },
                    false,
                    temperature,
                    0,
                    0
                );

                if (errorCode != 0) {
                    completed.set(true);
                    callback.onError("ExecuTorch error " + errorCode);
                } else if (completed.compareAndSet(false, true)) {
                    session.addMessage("assistant", fullResponse.toString());
                    callback.onComplete(chatId);
                }
            } catch (Exception e) {
                callback.onError(e.getMessage());
            }
        });
    }

    private void sendMediaPipeMessage(String chatId, String message, ChatSession session, MessageCallback callback) {
        if (mediaPipeInference == null) {
            callback.onError("MediaPipe model not ready");
            return;
        }

        executor.execute(() -> {
            try {
                // Add user message to history
                session.addMessage("user", message);

                // Build the full prompt with chat history
                String fullPrompt = session.buildPrompt(message);
                android.util.Log.d("LLM", "Full prompt: " + fullPrompt);

                // Create a session with proper options
                com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.LlmInferenceSessionOptions sessionOptions =
                    com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.LlmInferenceSessionOptions.builder()
                        .setTopK(topk)
                        .setTemperature(temperature)
                        .build();

                com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession inferenceSession =
                    com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession.createFromOptions(mediaPipeInference, sessionOptions);

                // Add the query
                inferenceSession.addQueryChunk(fullPrompt);

                // Use streaming API
                final StringBuilder fullResponse = new StringBuilder();

                com.google.mediapipe.tasks.genai.llminference.ProgressListener<String> resultListener =
                    new com.google.mediapipe.tasks.genai.llminference.ProgressListener<String>() {
                        private StringBuilder buffer = new StringBuilder();
                        private boolean hasStarted = false;
                        private final AtomicBoolean completed = new AtomicBoolean(false);

                        @Override
                        public void run(String partialResult, boolean done) {
                            android.util.Log.d("LLM", "Partial result: " + partialResult + ", done: " + done);

                            // Accumulate in buffer
                            buffer.append(partialResult);

                            // Process buffer when we have enough content or when done
                            String content = buffer.toString();

                            // Check if we can process some content
                            StringBuilder toSend = new StringBuilder();
                            int i = 0;
                            while (i < content.length()) {
                                // Check for escape sequence
                                if (i < content.length() - 1 && content.charAt(i) == '\\' && content.charAt(i + 1) == 'n') {
                                    toSend.append('\n');
                                    i += 2;
                                } else if (i == content.length() - 1 && content.charAt(i) == '\\' && !done) {
                                    // We have a backslash at the end and more chunks coming - wait for next chunk
                                    break;
                                } else {
                                    toSend.append(content.charAt(i));
                                    i++;
                                }
                            }

                            // Update buffer to contain only unprocessed content
                            buffer = new StringBuilder(content.substring(i));

                            // Send processed content if any
                            String chunk = toSend.toString();

                            // Remove leading newline from the very first content
                            if (!hasStarted && chunk.length() > 0) {
                                chunk = chunk.replaceFirst("^\\n", "");
                                hasStarted = true;
                            }

                            if (!chunk.isEmpty()) {
                                callback.onTextReceived(chatId, chunk, true);
                                fullResponse.append(chunk);
                            }

                            if (done && completed.compareAndSet(false, true)) {
                                if (buffer.length() > 0) {
                                    String remaining = buffer.toString();
                                    callback.onTextReceived(chatId, remaining, true);
                                    fullResponse.append(remaining);
                                    buffer = new StringBuilder();
                                }

                                session.addMessage("assistant", fullResponse.toString());
                                callback.onComplete(chatId);

                                try {
                                    inferenceSession.close();
                                } catch (Exception e) {
                                    android.util.Log.e("LLM", "Failed to close session: " + e.getMessage());
                                }
                            }
                        }
                    };

                inferenceSession.generateResponseAsync(resultListener);
            } catch (Exception e) {
                callback.onError(e.getMessage());
            }
        });
    }

    public String getReadiness() {
        return isReady ? "ready" : "not_ready";
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

    // Inner class to manage chat sessions
    private static class ChatSession {

        private StringBuilder history;

        ChatSession() {
            this.history = new StringBuilder();
        }

        void addMessage(String role, String content) {
            // Store messages in a cleaner format for history
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
            // Keep compatibility with the previous MediaPipe path: callers pass a fully formatted prompt when needed.
            return newMessage;
        }
    }
}
