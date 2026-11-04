package ee.forgr.capgo_llm;

final class ModelLoadSequence {

    private long currentLoadId;

    synchronized long nextLoadId() {
        currentLoadId += 1;
        return currentLoadId;
    }

    synchronized boolean isCurrentLoad(long loadId) {
        return loadId == currentLoadId;
    }
}
