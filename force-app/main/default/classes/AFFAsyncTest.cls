/**
 *
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description
 * This test class provides comprehensive coverage for the AFFAsync framework.
 * It tests the core logic of the orchestrator, data providers, and the overall
 * job lifecycle, including execution, chunking, failure, and compensation (Saga pattern).
 */
@isTest
@SuppressWarnings('PMD.CyclomaticComplexity,PMD.ExcessiveClassLength')
private class AFFAsyncTest {
  private static Boolean mockFinalizerWasCalled = false;
  private static AFFAsync.JobState mockFinalizerFinalState;

  /* ===============================================================
      Test Data Factory
  =============================================================== */

  @SuppressWarnings('PMD.ExcessiveParameterList')
  private static AFF_Job__c createJob(
    String status,
    String direction,
    Integer currentStepIndex,
    Integer totalSteps,
    String finalizerClass,
    Boolean isFinalizerExecuted
  ) {
    return new AFF_Job__c(
      Status__c = status,
      Direction__c = direction,
      Current_Step_Index__c = currentStepIndex,
      Total_Steps__c = totalSteps,
      Finalizer_Class_Name__c = finalizerClass,
      Finalizer_Executed__c = isFinalizerExecuted
    );
  }

  @SuppressWarnings('PMD.ExcessiveParameterList')
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
      Step_Executor_Name__c = executorName,
      Current_Chunk_Index__c = 0,
      Total_Chunks__c = 0
    );
  }

  /* ===============================================================
      Mock and Stub Implementations for Testing
  =============================================================== */

  // Custom exception for testing reversible failures without breaking AFFError.marshal
  private class TestReversibleException extends Exception {
  }

  public virtual class MockEngine implements AFFAsync.Engine {
    public List<AFFAsync.JobState> startedJobs = new List<AFFAsync.JobState>();
    public void start(List<AFFAsync.JobState> jobs) {
      if (jobs != null) {
        this.startedJobs.addAll(jobs);
      }
    }
  }

  public virtual class SingleExecutionStep implements AFFAsync.Step {
    public virtual AFFAsync.StepCompletionState execute(
      AFFAsync.Context context
    ) {
      return new AFFAsync.StepCompletionState(true, 'Complete', 'FinalState');
    }
    public virtual AFFAsync.StepCompletionState compensate(
      AFFAsync.Context context
    ) {
      return new AFFAsync.StepCompletionState(
        true,
        'Compensated',
        'FinalState'
      );
    }
  }

  public class ReversibleFailingStep implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      // Throw a custom exception that won't be a PermanentFailureException
      // and won't cause issues with AFFError.marshal like a mock DmlException does.
      throw new TestReversibleException('Reversible test failure');
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      return new AFFAsync.StepCompletionState(
        true,
        'Compensated',
        'CompensatedState'
      );
    }
  }

  public virtual class MultiChunkStep implements AFFAsync.Step {
    private final Integer totalChunksToCreate = 3;
    public virtual AFFAsync.StepCompletionState execute(
      AFFAsync.Context context
    ) {
      AFFAsync.StepState step = context.getStepState();
      Integer currentProgress = (step.totalChunks == null)
        ? 0
        : step.totalChunks;

      if (currentProgress >= totalChunksToCreate - 1) {
        // Last chunk
        return new AFFAsync.StepCompletionState(
          true,
          'PartialResult-' + currentProgress,
          String.valueOf(currentProgress)
        );
      } else {
        // More chunks to come
        AFFAsync.ChunkState nextChunk = new AFFAsync.ChunkState();
        nextChunk.payload = new Map<String, Object>{
          'index' => currentProgress
        };
        return new AFFAsync.StepCompletionState(
          true,
          'PartialResult-' + currentProgress,
          String.valueOf(currentProgress),
          nextChunk
        );
      }
    }
    public virtual AFFAsync.StepCompletionState compensate(
      AFFAsync.Context context
    ) {
      return new AFFAsync.StepCompletionState(true, 'Compensated', 'CompState');
    }
  }

  public class FailingStep implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      throw new AFFAsync.PermanentFailureException('Deliberate test failure');
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      // This compensation should be skipped by the orchestrator
      return new AFFAsync.StepCompletionState(
        true,
        'Compensated',
        'CompensatedState'
      );
    }
  }

  public class FailingCompensationStep extends SingleExecutionStep {
    public override AFFAsync.StepCompletionState compensate(
      AFFAsync.Context context
    ) {
      throw new AFFAsync.PermanentFailureException(
        'Deliberate compensation failure'
      );
    }
  }

  public class AggregatingStep extends MultiChunkStep implements AFFAsync.Aggregatable {
    public Object aggregate(List<AFFAsync.ChunkState> chunks) {
      List<String> results = new List<String>();
      for (AFFAsync.ChunkState chunk : chunks) {
        if (chunk.result != null) {
          // The result is already a deserialized object, just cast it.
          results.add((String) chunk.result);
        }
      }
      return String.join(results, ',');
    }
  }

  public class MockFinalizer implements AFFAsync.Finalizable {
    public void onFinish(AFFAsync.JobState finalJobState) {
      mockFinalizerWasCalled = true;
      mockFinalizerFinalState = finalJobState;
    }
  }

  public abstract class AbstractStep implements AFFAsync.Step {
  }

  /* ===============================================================
      Test Methods
  =============================================================== */

  @isTest
  static void testInitialStatusOnCreation() {
    // 1. Setup
    AFFAsync.JobState jobDto = new AFFAsync.JobState();
    jobDto.steps.add(new AFFAsync.StepState(0, 'TestStep1', null));
    jobDto.totalSteps = jobDto.steps.size();

    // 2. Action
    Test.startTest();
    AFFAsync.Provider provider = AFFAsync.getProvider();
    provider.createJob(jobDto);
    Test.stopTest();

    // 3. Assertions
    AFF_Job__c jobInDb = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :jobDto.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_NEW,
      jobInDb.Status__c,
      'Job status should be New upon creation.'
    );

    AFF_Job_Step__c stepInDb = [
      SELECT Status__c
      FROM AFF_Job_Step__c
      WHERE AFF_Job__c = :jobDto.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_PENDING,
      stepInDb.Status__c,
      'Step status should be Pending upon creation.'
    );
  }

  @isTest
  static void testOrchestratorHandlesNewAndPendingStatuses() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      null,
      false
    );
    insert job;
    AFF_Job_Step__c step = createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );
    insert step;

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine()
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run();
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultJob.Status__c,
      'Job should complete successfully.'
    );

    AFF_Job_Step__c resultStep = [
      SELECT Status__c
      FROM AFF_Job_Step__c
      WHERE Id = :step.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultStep.Status__c,
      'Step should complete successfully.'
    );
  }

  @isTest
  static void testFinalizerIsCalledOnSuccess() {
    mockFinalizerWasCalled = false; // Reset static variable
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      MockFinalizer.class.getName(),
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine()
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run();
    Test.stopTest();

    // VERIFY
    System.assertEquals(
      true,
      mockFinalizerWasCalled,
      'Finalizer should have been called on successful completion.'
    );
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      mockFinalizerFinalState.status,
      'Finalizer should receive the job state with a Completed status.'
    );
    AFF_Job__c resultJob = [
      SELECT Finalizer_Executed__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      true,
      resultJob.Finalizer_Executed__c,
      'Finalizer_Executed__c flag should be true after execution.'
    );
  }

  @isTest
  static void testFinalizerIsCalledOnFailure() {
    mockFinalizerWasCalled = false; // Reset static variable
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      MockFinalizer.class.getName(),
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      FailingStep.class.getName()
    );

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine()
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Fails, flips to UP
    orchestrator.run(); // Compensates (skips), moves to index -1, job Failed
    Test.stopTest();

    // VERIFY
    System.assertEquals(
      true,
      mockFinalizerWasCalled,
      'Finalizer should have been called on job failure.'
    );
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      mockFinalizerFinalState.status,
      'Finalizer should receive the job state with a Failed status.'
    );
    AFF_Job__c resultJob = [
      SELECT Status__c, Finalizer_Executed__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      resultJob.Status__c,
      'Job status should be Failed.'
    );
    System.assertEquals(
      true,
      resultJob.Finalizer_Executed__c,
      'Finalizer_Executed__c flag should be true after failure.'
    );
  }

  @isTest
  static void testFinalizerIdempotency() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      MockFinalizer.class.getName(),
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine()
    );

    // EXECUTE first run
    Test.startTest();
    orchestrator.run();
    Test.stopTest();
    System.assertEquals(
      true,
      mockFinalizerWasCalled,
      'Finalizer should have been called on the first run.'
    );

    // Reset mock for second run verification
    mockFinalizerWasCalled = false;

    // EXECUTE Second Time on completed job.
    orchestrator.run();

    // VERIFY Second Run
    System.assertEquals(
      false,
      mockFinalizerWasCalled,
      'Finalizer should NOT be called again on a completed job.'
    );
  }

  @isTest
  static void testMultiStepJobSuccess() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      2,
      null,
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );
    insert createStep(
      job.Id,
      1,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );

    MockEngine mockEngine = new MockEngine();
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Process step 0, enqueues step 1
    orchestrator.run(); // Process step 1, completes job
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c, Current_Step_Index__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultJob.Status__c,
      'Job with multiple steps should complete.'
    );
    System.assertEquals(
      2,
      resultJob.Current_Step_Index__c,
      'Job index should be past the last step.'
    );
    // The engine is called to transition from step 0 to 1. It is NOT called after the last step.
    System.assertEquals(
      1,
      mockEngine.startedJobs.size(),
      'Engine should be called to advance between steps.'
    );
  }

  @isTest
  static void testReversibleFailureTriggersCompensation() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      2,
      null,
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      SingleExecutionStep.class.getName()
    );
    insert createStep(
      job.Id,
      1,
      AFFAsyncConsts.STATUS_PENDING,
      ReversibleFailingStep.class.getName()
    );

    MockEngine mockEngine = new MockEngine();
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Step 0: Success, advances to step 1
    orchestrator.run(); // Step 1: Reversible failure, flips direction to UP
    orchestrator.run(); // Step 1: Compensates successfully
    orchestrator.run(); // Step 0: Compensates successfully
    orchestrator.run(); // Final run to set terminal status
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c, Direction__c, Current_Step_Index__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      resultJob.Status__c,
      'Job should end in Failed status after compensation.'
    );
    System.assertEquals(
      AFFAsyncConsts.DIRECTION_UP,
      resultJob.Direction__c,
      'Job direction should be UP after failure.'
    );
    System.assertEquals(
      -1,
      resultJob.Current_Step_Index__c,
      'Job index should be -1 after full compensation.'
    );

    List<AFF_Job_Step__c> steps = [
      SELECT Status__c
      FROM AFF_Job_Step__c
      WHERE AFF_Job__c = :job.Id
      ORDER BY Step_Index__c
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPENSATED,
      steps[0].Status__c,
      'Step 0 should be compensated.'
    );
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPENSATED,
      steps[1].Status__c,
      'Step 1, which failed and was compensated, should have status Compensated.'
    );
  }

  @isTest
  static void testCompensationFailure() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      2,
      null,
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      FailingCompensationStep.class.getName()
    );
    insert createStep(
      job.Id,
      1,
      AFFAsyncConsts.STATUS_PENDING,
      ReversibleFailingStep.class.getName()
    );

    MockEngine mockEngine = new MockEngine();
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Step 0: Success
    orchestrator.run(); // Step 1: Fails, flips to UP, status -> AwaitingCompensation
    orchestrator.run(); // Step 1: Compensates successfully, moves to step 0
    orchestrator.run(); // Step 0: Compensation fails (PermanentFailureException)
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPENSATION_FAILED,
      resultJob.Status__c,
      'Job status should be Compensation_Failed.'
    );

    AFF_Job_Step__c resultStep = [
      SELECT Status__c
      FROM AFF_Job_Step__c
      WHERE AFF_Job__c = :job.Id AND Step_Index__c = 0
    ];
    // When a compensation step has a PERMANENT failure, the step itself is marked
    // as Failed, while the overall job is marked as Compensation_Failed.
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      resultStep.Status__c,
      'Step that fails compensation should have status Failed, even if job is Compensation_Failed.'
    );
  }

  @isTest
  static void testAggregatableStep() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      null,
      false
    );
    insert job;
    AFF_Job_Step__c step = createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      AggregatingStep.class.getName()
    );
    insert step;

    MockEngine mockEngine = new MockEngine();
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Chunk 0
    orchestrator.run(); // Chunk 1
    orchestrator.run(); // Chunk 2 (final), triggers aggregation
    Test.stopTest();

    // VERIFY
    AFF_Job_Step__c resultStep = [
      SELECT Result__c, Status__c
      FROM AFF_Job_Step__c
      WHERE Id = :step.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultStep.Status__c,
      'Aggregatable step should complete.'
    );
    String expectedResult = '"PartialResult-0,PartialResult-1,PartialResult-2"';
    System.assertEquals(
      expectedResult,
      resultStep.Result__c,
      'The chunk results should be aggregated correctly.'
    );
  }

  @isTest
  @SuppressWarnings('PMD.AvoidHardcodingId')
  static void testProviderCornerCases() {
    Test.startTest();
    // Test with a preloaded job
    AFFAsync.JobState preloadedJob = new AFFAsync.JobState();
    preloadedJob.jobId = 'a04000000000001AAA';
    AFFAsync.Provider preloadedProvider = new AFFAsync.SObjectProviderImpl(
      preloadedJob
    );
    System.assertEquals(
      preloadedJob.jobId,
      preloadedProvider.getJobState().jobId,
      'Provider should return the preloaded job state.'
    );
    preloadedProvider.invalidateCache(); // Should not null out the preloaded job

    AFFAsync.SObjectProviderImpl provider = new AFFAsync.SObjectProviderImpl();

    // createJob with null
    try {
      provider.createJob(null);
      System.assert(
        false,
        'Expected IllegalArgumentException for null job state.'
      );
    } catch (AFFAsync.IllegalArgumentException e) {
      System.assertEquals(
        AFFAsyncConsts.ERROR_JOB_STATE_NULL,
        e.getMessage(),
        'Correct exception message should be thrown for null job.'
      );
    }

    // getJobState with null ID
    try {
      provider.getJobState();
      System.assert(
        false,
        'Expected IllegalArgumentException for null job ID.'
      );
    } catch (AFFAsync.IllegalArgumentException e) {
      System.assertEquals(
        AFFAsyncConsts.ERROR_JOB_ID_NULL,
        e.getMessage(),
        'Correct exception message should be thrown for null ID.'
      );
    }

    // getStepState with invalid indices
    AFFAsync.Provider providerWithJob = new AFFAsync.SObjectProviderImpl(
      preloadedJob
    );
    System.assertEquals(
      null,
      providerWithJob.getStepState(null),
      'getStepState(null) should return null.'
    );
    System.assertEquals(
      null,
      providerWithJob.getStepState(-1),
      'getStepState with negative index should return null.'
    );
    System.assertEquals(
      null,
      providerWithJob.getStepState(100),
      'getStepState with out-of-bounds index should return null.'
    );

    // getChunkState with invalid indices
    System.assertEquals(
      null,
      providerWithJob.getChunkState(0, null),
      'getChunkState with null index should return null.'
    );
    System.assertEquals(
      null,
      providerWithJob.getChunkState(0, -1),
      'getChunkState with negative index should return null.'
    );
    Test.stopTest();
  }

  @isTest
  static void testStepExecutorInitializationFailures() {
    Test.startTest();
    AFFAsync.StepExecutor executor = new AFFAsync.DefaultDynamicStepExecutorImpl();
    AFFAsync.JobState job = new AFFAsync.JobState();
    job.steps.add(new AFFAsync.StepState());
    AFFAsync.Context ctx = new AFFAsync.DefaultContextImpl(
      new AFFAsync.SObjectProviderImpl(job)
    );

    // Test with a non-existent class. This throws a StepInitializationException, which is
    // caught and re-thrown as another StepInitializationException with the first as the cause.
    ctx.getStepState().stepExecutorName = 'NonExistentClassName';
    try {
      executor.getStepInstance(ctx);
      System.assert(
        false,
        'Expected StepInitializationException for non-existent class.'
      );
    } catch (AFFAsync.StepInitializationException e) {
      System.assert(
        e.getMessage()
          .contains(AFFAsyncConsts.ERROR_COULD_NOT_INSTANTIATE_STEP),
        'Outer exception message should be about instantiation.'
      );
      System.assert(
        e.getCause() instanceof AFFAsync.StepInitializationException,
        'Cause should be a StepInitializationException.'
      );
      System.assert(
        e.getCause()
          .getMessage()
          .contains(AFFAsyncConsts.ERROR_COULD_NOT_FIND_CLASS),
        'Inner exception message should be about class not found.'
      );
    }

    // Test with a class that cannot be instantiated (e.g., abstract)
    ctx.getStepState().stepExecutorName = AbstractStep.class.getName();
    try {
      executor.getStepInstance(ctx);
      System.assert(
        false,
        'Expected StepInitializationException for abstract class.'
      );
    } catch (AFFAsync.StepInitializationException e) {
      System.assert(
        e.getMessage()
          .contains(AFFAsyncConsts.ERROR_COULD_NOT_INSTANTIATE_STEP),
        'Exception message should indicate instantiation failure.'
      );
      System.assert(
        e.getCause() instanceof TypeException,
        'Cause should be a TypeException for abstract class.'
      );
    }
    Test.stopTest();
  }

  @isTest
  static void testFixedAttemptsRetrier() {
    Test.startTest();
    // Test success on first attempt
    AFFAsync.Retrier retrier = new AFFAsync.FixedAttemptsRetrierImpl(3);
    Object result = retrier.execute(new SuccessAction());
    System.assertEquals(
      'Success',
      result,
      'Retrier should return the result on success.'
    );

    // Test failure after all attempts
    try {
      retrier.execute(new FailingAction());
      System.assert(
        false,
        'Expected PermanentFailureException after all retries.'
      );
    } catch (AFFAsync.PermanentFailureException e) {
      System.assert(
        e.getMessage().contains(AFFAsyncConsts.ERROR_PERMANENT_FAILURE_PREFIX),
        'Exception message should indicate permanent failure after retries.'
      );
    }
    Test.stopTest();
  }

  // Helper action classes for retrier test
  private class SuccessAction implements AFFAsync.Action {
    public Object call() {
      return 'Success';
    }
  }
  private class FailingAction implements AFFAsync.Action {
    public Object call() {
      throw new DmlException('Failed');
    }
  }

  @isTest
  static void testDtoAndExceptionConstructors() {
    Test.startTest();
    // Cover various constructors for code coverage
    AFFAsync.StepCompletionState state1 = new AFFAsync.StepCompletionState(
      true,
      null,
      null,
      new AFFAsync.ChunkState()
    );
    AFFAsync.StepCompletionState state2 = new AFFAsync.StepCompletionState(
      true,
      null,
      null,
      new Map<String, Object>()
    );
    AFFAsync.StepCompletionState state3 = new AFFAsync.StepCompletionState(
      true,
      null,
      null
    );
    System.assertNotEquals(
      null,
      state1,
      'Constructor with nextChunk should not create a null object.'
    );
    System.assertNotEquals(
      null,
      state2,
      'Constructor with previousValues should not create a null object.'
    );
    System.assertNotEquals(
      null,
      state3,
      'Simple constructor should not create a null object.'
    );

    AFFAsync.PublishingException ex = new AFFAsync.PublishingException(
      'msg',
      null,
      null,
      null
    );
    System.assertEquals(
      'msg',
      ex.getMessage(),
      'Exception message should be set correctly.'
    );
    System.assertEquals(
      null,
      ex.successfulJobs,
      'successfulJobs should be set correctly.'
    );
    System.assertEquals(
      null,
      ex.failedJobs,
      'failedJobs should be set correctly.'
    );
    System.assertEquals(
      null,
      ex.errorsByJobIndex,
      'errorsByJobIndex should be set correctly.'
    );
    Test.stopTest();
  }

  // New tests for increased coverage

  @isTest
  static void testPermanentFailureInExecution() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      null,
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      FailingStep.class.getName()
    );

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1), // Retrier won't help a PermanentFailureException
      new MockEngine()
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run();
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c, Final_Error_Details__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      resultJob.Status__c,
      'Job should fail on permanent exception.'
    );
    System.assert(
      resultJob.Final_Error_Details__c.contains('PERMANENT FAILURE'),
      'Error details should indicate a permanent failure.'
    );
  }

  @isTest
  static void testPermanentFailureDuringCompensation() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      2,
      null,
      false
    );
    insert job;
    insert createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      FailingCompensationStep.class.getName()
    );
    insert createStep(
      job.Id,
      1,
      AFFAsyncConsts.STATUS_PENDING,
      ReversibleFailingStep.class.getName()
    );

    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine()
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Step 0: Success
    orchestrator.run(); // Step 1: Fails, flips to UP
    orchestrator.run(); // Step 1: Compensates successfully
    orchestrator.run(); // Step 0: Compensation fails permanently
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c, Final_Error_Details__c
      FROM AFF_Job__c
      WHERE Id = :job.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPENSATION_FAILED,
      resultJob.Status__c,
      'Job should have compensation failed status.'
    );
    System.assert(
      resultJob.Final_Error_Details__c.contains('PERMANENT FAILURE'),
      'Error details should indicate a permanent failure during compensation.'
    );
  }

  @isTest
  static void testLegacyAggregatableStep() {
    // SETUP
    AFF_Job__c job = createJob(
      AFFAsyncConsts.STATUS_NEW,
      AFFAsyncConsts.DIRECTION_DOWN,
      0,
      1,
      null,
      false
    );
    insert job;
    AFF_Job_Step__c step = createStep(
      job.Id,
      0,
      AFFAsyncConsts.STATUS_PENDING,
      AggregatingStep.class.getName()
    );
    insert step;

    MockEngine mockEngine = new MockEngine();
    AFFAsync.Orchestrator orchestrator = new AFFAsync.DefaultOrchestratorImpl(
      new AFFAsync.DefaultContextImpl(new AFFAsync.SObjectProviderImpl(job.Id)),
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      mockEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(); // Chunk 0
    orchestrator.run(); // Chunk 1
    orchestrator.run(); // Chunk 2 (final), triggers aggregation
    Test.stopTest();

    // VERIFY
    AFF_Job_Step__c resultStep = [
      SELECT Result__c, Status__c
      FROM AFF_Job_Step__c
      WHERE Id = :step.Id
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultStep.Status__c,
      'Legacy aggregatable step should complete.'
    );
    String expectedResult = '"PartialResult-0,PartialResult-1,PartialResult-2"';
    System.assertEquals(
      expectedResult,
      resultStep.Result__c,
      'The legacy aggregation result should be correct.'
    );
  }
}
