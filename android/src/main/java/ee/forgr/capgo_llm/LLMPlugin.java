package ee.forgr.capgo_llm;

import com.getcapacitor.JSObject;
import com.getcapacitor.Plugin;
import com.getcapacitor.PluginCall;
import com.getcapacitor.PluginMethod;
import com.getcapacitor.annotation.CapacitorPlugin;

@CapacitorPlugin(name = "CapgoLLM")
public class LLMPlugin extends Plugin {

    private final String PLUGIN_VERSION = "7.2.3";

    private LLM llm;

    @Override
    public void load() {
        super.load();
        llm = LLM.getInstance(getContext());
    }

    @PluginMethod
    public void createChat(PluginCall call) {
        try {
            String chatId = llm.createChat();
            JSObject ret = new JSObject();
            ret.put("id", chatId);
            call.resolve(ret);
        } catch (Exception e) {
            call.reject("Failed to create chat", e);
        }
    }

    @PluginMethod
    public void sendMessage(PluginCall call) {
        String chatId = call.getString("chatId");
        String message = call.getString("message");

        if (chatId == null || message == null) {
            call.reject("chatId and message are required");
            return;
        }

        llm.sendMessage(
            chatId,
            message,
            new LLM.MessageCallback() {
                @Override
                public void onTextReceived(String chatId, String text, boolean isChunk) {
                    JSObject event = new JSObject();
                    event.put("text", text);
                    event.put("chatId", chatId);
                    event.put("isChunk", isChunk);
                    notifyListeners("textFromAi", event);
                }

                @Override
                public void onComplete(String chatId) {
                    JSObject event = new JSObject();
                    event.put("chatId", chatId);
                    notifyListeners("aiFinished", event);
                }

                @Override
                public void onError(String error) {
                    call.reject("Failed to send message", error);
                }
            }
        );

        call.resolve();
    }

    @PluginMethod
    public void getReadiness(PluginCall call) {
        String readiness = llm.getReadiness();
        JSObject ret = new JSObject();
        ret.put("readiness", readiness);
        call.resolve(ret);

        // Also notify listeners
        JSObject readinessData = new JSObject();
        readinessData.put("readiness", readiness);
        notifyListeners("readinessChange", readinessData);
    }

    @PluginMethod
    public void setModel(PluginCall call) {
        String path = call.getString("path");

        if (path == null) {
            call.reject("path is required");
            return;
        }

        // Extract model parameters
        Integer maxTokens = call.getInt("maxTokens", 2048);
        Integer topk = call.getInt("topk", 40);
        Float temperature = call.getFloat("temperature", 0.8f);
        Integer randomSeed = call.getInt("randomSeed", 101);

        llm.setModel(
            path,
            maxTokens,
            topk,
            temperature,
            new LLM.ModelLoadCallback() {
                @Override
                public void onSuccess() {
                    // Notify readiness change
                    JSObject readinessData = new JSObject();
                    readinessData.put("readiness", "ready");
                    notifyListeners("readinessChange", readinessData);
                    call.resolve();
                }

                @Override
                public void onError(String error) {
                    // Notify readiness change
                    JSObject readinessData = new JSObject();
                    readinessData.put("readiness", "Failed to load model: " + error);
                    notifyListeners("readinessChange", readinessData);
                    call.reject("Failed to load model", error);
                }
            }
        );
    }

    @PluginMethod
    public void downloadModel(PluginCall call) {
        String url = call.getString("url");
        String companionUrl = call.getString("companionUrl");
        String filename = call.getString("filename");

        if (url == null) {
            call.reject("url is required");
            return;
        }

        // If no filename provided, extract from URL
        if (filename == null) {
            String[] parts = url.split("/");
            filename = parts[parts.length - 1];
        }

        final String finalFilename = filename;

        new Thread(() -> {
            try {
                // Download main model file
                java.io.File filesDir = getContext().getFilesDir();
                java.io.File modelFile = new java.io.File(filesDir, finalFilename);

                downloadFile(url, modelFile, (progress) -> {
                    JSObject event = new JSObject();
                    event.put("progress", progress);
                    notifyListeners("downloadProgress", event);
                });

                JSObject ret = new JSObject();
                ret.put("path", modelFile.getAbsolutePath());

                // Download companion file if provided
                if (companionUrl != null) {
                    String companionFilename = companionUrl.substring(companionUrl.lastIndexOf("/") + 1);
                    java.io.File companionFile = new java.io.File(filesDir, companionFilename);

                    downloadFile(companionUrl, companionFile, (progress) -> {
                        JSObject event = new JSObject();
                        event.put("progress", progress);
                        notifyListeners("downloadProgress", event);
                    });

                    ret.put("companionPath", companionFile.getAbsolutePath());
                }

                call.resolve(ret);
            } catch (Exception e) {
                call.reject("Failed to download model", e.getMessage());
            }
        })
            .start();
    }

    private void downloadFile(String urlString, java.io.File outputFile, ProgressCallback callback) throws Exception {
        java.net.URL url = new java.net.URL(urlString);
        java.net.HttpURLConnection connection = (java.net.HttpURLConnection) url.openConnection();
        connection.connect();

        int fileLength = connection.getContentLength();
        java.io.InputStream input = new java.io.BufferedInputStream(connection.getInputStream());
        java.io.FileOutputStream output = new java.io.FileOutputStream(outputFile);

        byte[] data = new byte[4096];
        long total = 0;
        int count;

        while ((count = input.read(data)) != -1) {
            total += count;
            if (fileLength > 0 && callback != null) {
                callback.onProgress((int) ((total * 100) / fileLength));
            }
            output.write(data, 0, count);
        }

        output.flush();
        output.close();
        input.close();
    }

    interface ProgressCallback {
        void onProgress(int percentage);
    }

    @PluginMethod
    public void getPluginVersion(final PluginCall call) {
        try {
            final JSObject ret = new JSObject();
            ret.put("version", this.PLUGIN_VERSION);
            call.resolve(ret);
        } catch (final Exception e) {
            call.reject("Could not get plugin version", e);
        }
    }
}
