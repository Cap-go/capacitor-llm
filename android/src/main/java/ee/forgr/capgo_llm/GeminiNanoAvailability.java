package ee.forgr.capgo_llm;

import com.google.mlkit.genai.common.FeatureStatus;

final class GeminiNanoAvailability {

    private GeminiNanoAvailability() {}

    static boolean isAvailable(Integer status) {
        return status != null && status == FeatureStatus.AVAILABLE;
    }

    static String describe(Integer status) {
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
}
