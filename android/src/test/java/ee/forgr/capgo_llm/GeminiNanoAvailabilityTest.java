package ee.forgr.capgo_llm;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import com.google.mlkit.genai.common.FeatureStatus;
import org.junit.Test;

public class GeminiNanoAvailabilityTest {

    @Test
    public void isAvailableOnlyWhenFeatureStatusAvailable() {
        assertTrue(GeminiNanoAvailability.isAvailable(FeatureStatus.AVAILABLE));
        assertFalse(GeminiNanoAvailability.isAvailable(FeatureStatus.UNAVAILABLE));
        assertFalse(GeminiNanoAvailability.isAvailable(FeatureStatus.DOWNLOADABLE));
        assertFalse(GeminiNanoAvailability.isAvailable(null));
    }

    @Test
    public void describeMapsKnownStatuses() {
        assertTrue(GeminiNanoAvailability.describe(FeatureStatus.UNAVAILABLE).contains("unavailable"));
        assertTrue(GeminiNanoAvailability.describe(FeatureStatus.DOWNLOADABLE).contains("downloadable"));
        assertTrue(GeminiNanoAvailability.describe(FeatureStatus.DOWNLOADING).contains("downloading"));
        assertTrue(GeminiNanoAvailability.describe(null).equals("unknown"));
    }
}
