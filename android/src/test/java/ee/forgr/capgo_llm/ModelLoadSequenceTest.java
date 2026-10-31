package ee.forgr.capgo_llm;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ModelLoadSequenceTest {

    @Test
    public void supersededLoadIdIsNotCurrentAfterNewerRequest() {
        ModelLoadSequence sequence = new ModelLoadSequence();
        long firstLoadId = sequence.nextLoadId();
        assertTrue(sequence.isCurrentLoad(firstLoadId));

        long secondLoadId = sequence.nextLoadId();
        assertFalse(sequence.isCurrentLoad(firstLoadId));
        assertTrue(sequence.isCurrentLoad(secondLoadId));
    }
}
