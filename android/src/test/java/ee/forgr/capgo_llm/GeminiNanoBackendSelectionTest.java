package ee.forgr.capgo_llm;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.Locale;
import org.junit.Test;

public class GeminiNanoBackendSelectionTest {

    @Test
    public void geminiNanoAgentUnderscoreAliasSelectsAgentBackend() {
        assertTrue(GeminiNanoBackendSelection.isGeminiNanoModel("gemini_nano_agent", "gemini_nano_agent"));
        assertTrue(GeminiNanoBackendSelection.shouldUseAgentBackend("gemini_nano_agent", null));
    }

    @Test
    public void geminiNanoAgentHyphenAliasSelectsAgentBackend() {
        assertTrue(GeminiNanoBackendSelection.shouldUseAgentBackend("gemini-nano-agent", null));
    }

    @Test
    public void geminiNanoWithoutAgentSuffixUsesPromptBackend() {
        assertTrue(GeminiNanoBackendSelection.isGeminiNanoModel("gemini_nano", "gemini_nano"));
        assertFalse(GeminiNanoBackendSelection.shouldUseAgentBackend("gemini_nano", null));
    }

    @Test
    public void androidGeminiBackendAgentOverridesPromptModelType() {
        assertTrue(GeminiNanoBackendSelection.shouldUseAgentBackend("gemini_nano", "agent"));
    }

    @Test
    public void whitespaceOnlyValuesAreNotGeminiNano() {
        assertFalse(GeminiNanoBackendSelection.isGeminiNanoModel("   ", null));
        assertFalse(GeminiNanoBackendSelection.shouldUseAgentBackend("   ", null));
    }

    @Test
    public void uppercaseAgentAliasSelectsAgentBackend() {
        assertTrue(GeminiNanoBackendSelection.shouldUseAgentBackend("GEMINI-NANO-AGENT", null));
    }

    @Test
    public void turkishLocaleUppercaseAgentAliasSelectsAgentBackend() {
        Locale previous = Locale.getDefault();
        try {
            Locale.setDefault(new Locale("tr", "TR"));
            assertTrue(GeminiNanoBackendSelection.shouldUseAgentBackend("GEMINI-NANO-AGENT", null));
            assertTrue(GeminiNanoBackendSelection.isGeminiNanoModel("Gemini Nano", "GEMINI-NANO-AGENT"));
        } finally {
            Locale.setDefault(previous);
        }
    }
}
