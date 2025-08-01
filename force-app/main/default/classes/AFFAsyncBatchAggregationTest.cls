/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description Test class for AFFAsync Batch Aggregation
 */
@isTest
@SuppressWarnings('PMD.ExcessiveParameterList')
private class AFFAsyncBatchAggregationTest {
  /* ===============================================================
      Test Data Factory
  =============================================================== */
  private static AFF_Job__c createJob(
    String status,
    String direction,
    Integer currentStepIndex,
    Integer totalSteps
  ) {
    return new AFF_Job__c(
      Status__c = status,
      Direction__c = direction,
      Current_Step_Index__c = currentStepIndex,
      Total_Steps__c = totalSteps
    );
  }

  private static AFF_Job_Step__c createStep(
    Id jobId,
    Integer stepIndex,
    String status,
    String executorName
  ) {
    return new AFF_Job_Step__c(
      AFF_Job__c = jobId,
      Step_Index__c = stepIndex,
      Status__c = status,
      Step_Executor_Name__c = executorName
    );
  }

  /* ===============================================================
      Mock Implementations for Testing
  =============================================================== */

  /**
   * @description A mock engine to capture re-enqueued jobs.
   */
  public class MockEngine implements AFFAsync.Engine {
    public List<AFFAsync.JobState> startedJobs = new List<AFFAsync.JobState>();
    public void start(List<AFFAsync.JobState> jobs) {
      if (jobs != null) {
        this.startedJobs.addAll(jobs);
      }
    }
  }

  /**
   * @description A test step that now correctly simulates a multi-chunk process.
   * It aggregates chunk results using the scalable BatchAggregatable interface.
   */
  public class BatchAggregatingStep implements AFFAsync.Step, AFFAsync.BatchAggregatable {
    // Define the total number of chunks this step will generate.
    @SuppressWarnings('PMD.FieldNamingConventions')
    private final Integer TOTAL_CHUNKS_TO_CREATE = 3;
    @SuppressWarnings('PMD.FieldNamingConventions')
    private final List<String> CHUNK_RESULTS = new List<String>{
      'Result-A',
      'Result-B',
      'Result-C'
    };

    // --- Main execution logic ---
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      AFFAsync.StepState step = context.getStepState();

      // Determine the current progress based on the number of chunks already created.
      Integer currentChunkNumber = (step.totalChunks == null)
        ? 0
        : step.totalChunks;

      String currentResult = CHUNK_RESULTS[currentChunkNumber];

      // Check if this is the final chunk.
      if (currentChunkNumber >= TOTAL_CHUNKS_TO_CREATE - 1) {
        // This is the last chunk. Return a state with no next chunk to trigger aggregation.
        return new AFFAsync.StepCompletionState(
          true,
          currentResult,
          'Finished'
        );
      } else {
        // There are more chunks to process. Return a state with a nextChunk DTO.
        AFFAsync.ChunkState nextChunk = new AFFAsync.ChunkState();
        return new AFFAsync.StepCompletionState(
          true,
          currentResult,
          'InProgress-' + (currentChunkNumber + 1),
          nextChunk
        );
      }
    }

    // Not used in this test path
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      return null;
    }

    // --- BatchAggregatable Implementation ---
    public Object startAggregation(AFFAsync.Context context) {
      return new List<String>();
    }

    public Object executeAggregation(
      AFFAsync.Context context,
      Object currentState,
      List<AFFAsync.ChunkState> chunkBatch
    ) {
      List<String> aggregatedResults = (List<String>) currentState;
      for (AFFAsync.ChunkState chunk : chunkBatch) {
        if (chunk.result != null) {
          aggregatedResults.add((String) chunk.result);
        }
      }
      return aggregatedResults;
    }

    public Object finishAggregation(
      AFFAsync.Context context,
      Object finalState
    ) {
      List<String> allResults = (List<String>) finalState;
      return String.join(allResults, ',');
    }
  }

  /* ===============================================================
      Test Method
  =============================================================== */

  /**
   * @description Tests the full lifecycle of a chunked, batch-aggregatable step.
   * This test now correctly simulates multiple orchestrator runs to generate
   * each chunk before triggering the final aggregation.
   */
  @isTest
  static void testBatchAggregationStepLifecycle() {
    // SETUP
    // 1. Create the parent Job and Step records. The step starts with 0 chunks.
    AFF_Job__c job = createJob('InProgress', 'Down', 0, 1);
    insert job;
    AFF_Job_Step__c step = createStep(
      job.Id,
      0,
      'InProgress',
      BatchAggregatingStep.class.getName()
    );
    insert step;

    // 2. Setup the orchestrator components.
    MockEngine mockEngine = new MockEngine();
    AFFAsync.Provider provider = new AFFAsync.SObjectProviderImpl(job.Id);
    AFFAsync.Context ctx = new AFFAsync.DefaultContextImpl(provider);
    AFFAsync.StepExecutor exec = new AFFAsync.DefaultDynamicStepExecutorImpl();
    AFFAsync.Retrier retrier = new AFFAsync.FixedAttemptsRetrierImpl(1);
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      ctx,
      exec,
      retrier,
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    // Simulate the execution of each chunk through separate orchestrator runs.
    // Run 1: Creates chunk for Result-A and re-enqueues the job.
    orchestrator.run();
    // Run 2: Creates chunk for Result-B and re-enqueues the job.
    orchestrator.run();
    // Run 3: Creates chunk for Result-C, sees it's the final chunk, and performs aggregation.
    orchestrator.run();
    Test.stopTest();

    // VERIFY
    // 1. Check that the Job completed successfully and advanced.
    AFF_Job__c resultJob = [
      SELECT Status__c, Current_Step_Index__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      'Completed',
      resultJob.Status__c,
      'Job should be marked as Completed.'
    );
    System.assertEquals(
      1,
      resultJob.Current_Step_Index__c,
      'Job should have advanced to the next step index.'
    );

    // 2. Check the final aggregated result on the Step record.
    AFF_Job_Step__c resultStep = [
      SELECT Status__c, Result__c, Total_Chunks__c
      FROM AFF_Job_Step__c
      WHERE Id = :step.Id
    ];
    System.assertEquals(
      'Completed',
      resultStep.Status__c,
      'Step should be marked as Completed.'
    );
    System.assertEquals(
      3,
      resultStep.Total_Chunks__c,
      'Step should have a total of 3 chunks.'
    );

    // 3. Verify the aggregated result string.
    System.assertNotEquals(
      null,
      resultStep.Result__c,
      'Step result should not be null.'
    );
    String deserializedResult = (String) JSON.deserialize(
      resultStep.Result__c,
      String.class
    );

    System.assertEquals(
      'Result-A,Result-B,Result-C',
      deserializedResult,
      'The step result should be the correctly aggregated string from all generated chunks.'
    );
  }
}
