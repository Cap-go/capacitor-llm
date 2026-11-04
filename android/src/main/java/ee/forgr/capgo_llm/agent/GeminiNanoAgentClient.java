package ee.forgr.capgo_llm.agent;

import android.content.Context;

/**
 * Optional ML Kit GenAI Agent backend ({@code com.google.mlkit:genai-agent}).
 * Real implementation is compiled only when {@code capacitorLLM.genaiAgent.include=true}.
 */
public interface GeminiNanoAgentClient {
    interface InitCallback {
        void onSuccess();

        void onError(String error);
    }

    interface MessageCallback {
        void onText(String token);

        void onComplete();

        void onError(String error);
    }

    boolean isCompiledIn();

    void initialize(String instructions, InitCallback callback);

    void sendMessage(String sessionId, String message, MessageCallback callback);

    void closeSession(String sessionId);

    void shutdown();

    static GeminiNanoAgentClient create(Context context) {
        return new GeminiNanoAgentClientImpl(context);
    }
}
