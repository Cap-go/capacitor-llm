package ee.forgr.capgo_llm.agent;

import android.content.Context;

final class GeminiNanoAgentClientImpl implements GeminiNanoAgentClient {

    private static final String DISABLED_MESSAGE =
        "ML Kit GenAI Agent (genai-agent) is not included in this build. " +
        "Set capacitorLLM.genaiAgent.include=true in android/gradle.properties " +
        "or enable CapgoLLM.android.genaiAgent in capacitor.config.ts, then run cap sync.";

    GeminiNanoAgentClientImpl(Context context) {}

    @Override
    public boolean isCompiledIn() {
        return false;
    }

    @Override
    public void initialize(String instructions, InitCallback callback) {
        callback.onError(DISABLED_MESSAGE);
    }

    @Override
    public void sendMessage(String sessionId, String message, MessageCallback callback) {
        callback.onError(DISABLED_MESSAGE);
    }

    @Override
    public void closeSession(String sessionId) {}

    @Override
    public void shutdown() {}
}
