package ee.forgr.capgo_llm;

import java.util.Locale;

public final class GeminiNanoBackendSelection {

    private GeminiNanoBackendSelection() {}

    public static boolean isGeminiNanoModel(String path, String modelType) {
        return isGeminiNanoSystemName(modelType) || isGeminiNanoSystemName(path);
    }

    public static boolean shouldUseAgentBackend(String modelType, String androidGeminiBackend) {
        if (!isNullOrBlank(modelType)) {
            if ("gemininanoagent".equals(normalizeSystemModelName(modelType))) {
                return true;
            }
        }

        return androidGeminiBackend != null && "agent".equalsIgnoreCase(androidGeminiBackend.trim());
    }

    private static boolean isGeminiNanoSystemName(String value) {
        if (isNullOrBlank(value)) {
            return false;
        }

        String normalized = normalizeSystemModelName(value);
        return "gemininano".equals(normalized) || "gemininanoagent".equals(normalized);
    }

    private static String normalizeSystemModelName(String value) {
        return stripUrlSuffix(value).toLowerCase(Locale.ROOT).replace("-", "").replace("_", "").replace(" ", "");
    }

    private static boolean isNullOrBlank(String value) {
        return value == null || value.trim().isEmpty();
    }

    private static String stripUrlSuffix(String value) {
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
}
