package ee.forgr.capgo_llm.agent

import android.content.Context
import com.google.mlkit.genai.agent.Agent
import com.google.mlkit.genai.agent.AgentRunner
import com.google.mlkit.genai.agent.textTokens
import com.google.mlkit.genai.prompt.Content
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class GeminiNanoAgentClientImpl(context: Context) : GeminiNanoAgentClient {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var runner: AgentRunner? = null

    override fun isCompiledIn(): Boolean = true

    override fun initialize(instructions: String?, callback: GeminiNanoAgentClient.InitCallback) {
        scope.launch {
            try {
                shutdownRunnerOnly()
                val agent =
                    Agent.builder()
                        .setName("CapgoLLM")
                        .setInstructions(
                            instructions?.takeIf { it.isNotBlank() }
                                ?: "You are a helpful on-device assistant.",
                        )
                        .build()
                runner = AgentRunner(agent)
                callback.onSuccess()
            } catch (exception: Exception) {
                callback.onError(exception.message ?: "Failed to initialize Gemini Nano agent")
            }
        }
    }

    override fun sendMessage(
        sessionId: String,
        message: String,
        callback: GeminiNanoAgentClient.MessageCallback,
    ) {
        val activeRunner = runner
        if (activeRunner == null) {
            callback.onError("Gemini Nano agent is not initialized")
            return
        }

        scope.launch {
            try {
                val session = activeRunner.getOrCreateSession(sessionId)
                val prompt = Content.builder().text(message).build()
                session
                    .runAsync(prompt)
                    .textTokens()
                    .collect { token ->
                        if (token.isNotEmpty()) {
                            callback.onText(token)
                        }
                    }
                callback.onComplete()
            } catch (exception: Exception) {
                callback.onError(exception.message ?: "Gemini Nano agent generation failed")
            }
        }
    }

    override fun closeSession(sessionId: String) {
        val activeRunner = runner ?: return
        scope.launch {
            try {
                activeRunner.deleteSession(sessionId)
            } catch (_: Exception) {
                // Best effort cleanup.
            }
        }
    }

    override fun shutdown() {
        scope.launch {
            shutdownRunnerOnly()
        }
    }

    private fun shutdownRunnerOnly() {
        try {
            runner?.close()
        } catch (_: Exception) {
            // Best effort cleanup.
        } finally {
            runner = null
        }
    }
}
