/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description Test class for AFFAsyncEng, focusing on the PlatformEventEngine,
 * PlatformEventExecutor, and the DefaultLimitAwareBatchOrchestrator.
 */
@IsTest
private class AFFAsyncEngTest {
  //============================================================================
  //== Mock Implementations
  //============================================================================

  /**
   * @description Mock publisher that simulates successful event publishing.
   */
  private class MockSuccessEventBusPublisher implements AFFAsyncEng.EventBusPublisher {
    public List<Database.SaveResult> publish(List<SObject> events) {
      List<Database.SaveResult> results = new List<Database.SaveResult>();
      for (SObject e : events) {
        Database.SaveResult sr = (Database.SaveResult) JSON.deserialize(
          '{"success":true,"id":"e00000000000001AAA"}',
          Database.SaveResult.class
        );
        results.add(sr);
      }
      return results;
    }
  }

  /**
   * @description Mock publisher that reliably fails to publish events.
   */
  private class MockFailingEventBusPublisher implements AFFAsyncEng.EventBusPublisher {
    public List<Database.SaveResult> publish(List<SObject> events) {
      List<Database.SaveResult> results = new List<Database.SaveResult>();
      for (SObject e : events) {
        Database.Error error = (Database.Error) JSON.deserialize(
          '{"message":"The event could not be published.","statusCode":"PLATFORM_EVENT_PUBLISH_FAILED"}',
          Database.Error.class
        );
        Database.SaveResult sr = (Database.SaveResult) JSON.deserialize(
          '{"success":false}',
          Database.SaveResult.class
        );
        results.add(sr);
      }
      return results;
    }
  }

  /**
   * @description Mock engine to capture re-enqueued jobs for verification.
   */
  public class MockEngine implements AFFAsync.Engine {
    public List<AFFAsync.JobState> startedJobs = new List<AFFAsync.JobState>();
    public void start(List<AFFAsync.JobState> jobs) {
      if (jobs != null) {
        this.startedJobs.addAll(jobs);
      }
    }
  }

  //============================================================================
  //== Test Setup Helpers
  //============================================================================

  private static AFFAsync.JobState createJob(
    String stepExecutorName,
    Integer totalSteps,
    Integer currentStep
  ) {
    AFFAsync.JobState job = new AFFAsync.JobState();
    job.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
    job.direction = AFFAsyncConsts.DIRECTION_DOWN;
    job.currentStepIndex = currentStep;
    job.totalSteps = totalSteps;

    for (Integer i = 0; i < totalSteps; i++) {
      AFFAsync.StepState step = new AFFAsync.StepState();
      step.stepIndex = i;
      if (i == currentStep) {
        step.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
      } else {
        step.status = AFFAsyncConsts.STATUS_PENDING;
      }
      step.stepExecutorName = stepExecutorName;
      job.steps.add(step);
    }

    AFFAsync.SObjectProviderImpl provider = new AFFAsync.SObjectProviderImpl();
    return provider.createJob(job);
  }

  private static AFFAsync.JobState createTwoStepJob(
    String step1Executor,
    String step2Executor
  ) {
    AFFAsync.JobState job = new AFFAsync.JobState();
    job.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
    job.direction = AFFAsyncConsts.DIRECTION_DOWN;
    job.currentStepIndex = 0;
    job.totalSteps = 2;

    AFFAsync.StepState step1 = new AFFAsync.StepState(0, step1Executor, null);
    step1.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
    job.steps.add(step1);

    AFFAsync.StepState step2 = new AFFAsync.StepState(1, step2Executor, null);
    job.steps.add(step2);

    AFFAsync.SObjectProviderImpl provider = new AFFAsync.SObjectProviderImpl();
    return provider.createJob(job);
  }

  //============================================================================
  //== PlatformEventEngine Tests
  //============================================================================

  @IsTest
  static void testPlatformEngineSuccess() {
    AFFAsync.JobState testJob = createJob(
      AFFAsyncEng.MockStep.class.getName(),
      1,
      0
    );
    AFFAsyncEng.PlatformEventEngine engine = new AFFAsyncEng.PlatformEventEngine(
      new MockSuccessEventBusPublisher()
    );

    Test.startTest();
    engine.start(new List<AFFAsync.JobState>{ testJob });
    Test.stopTest();

    System.assert(
      true,
      'Happy path for PlatformEventEngine should not throw an exception.'
    );
  }

  @IsTest
  static void testPlatformEngineFailureThrowsException() {
    AFFAsync.JobState testJob = createJob(
      AFFAsyncEng.MockStep.class.getName(),
      1,
      0
    );
    AFFAsyncEng.PlatformEventEngine engine = new AFFAsyncEng.PlatformEventEngine(
      new MockFailingEventBusPublisher()
    );

    Exception caughtException = null;
    Test.startTest();
    try {
      engine.start(new List<AFFAsync.JobState>{ testJob });
    } catch (AFFAsync.PublishingException e) {
      caughtException = e;
    }
    Test.stopTest();

    System.assertNotEquals(
      null,
      caughtException,
      'A PublishingException should have been thrown.'
    );
    AFFAsync.PublishingException pubEx = (AFFAsync.PublishingException) caughtException;
    System.assertEquals(
      1,
      pubEx.failedJobs.size(),
      'There should be one failed job.'
    );
    System.assertEquals(
      0,
      pubEx.successfulJobs.size(),
      'There should be no successful jobs.'
    );
  }

  @IsTest
  static void testPlatformEngineEdgeCases() {
    AFFAsyncEng.PlatformEventEngine engine = new AFFAsyncEng.PlatformEventEngine(
      new MockSuccessEventBusPublisher()
    );
    Test.startTest();
    // Test with null and empty lists - should not throw an exception
    engine.start(null);
    engine.start(new List<AFFAsync.JobState>());

    // Test with a job that has a blank ID - should be skipped
    AFFAsync.JobState jobWithNoId = new AFFAsync.JobState();
    engine.start(new List<AFFAsync.JobState>{ jobWithNoId });
    Test.stopTest();
    System.assert(
      true,
      'Test passed if no exceptions were thrown for edge cases.'
    );
  }

  //============================================================================
  //== PlatformEventExecutor & Batch Orchestrator Tests
  //============================================================================

  @IsTest
  static void testExecutorHappyPath() {
    AFFAsync.JobState testJob = createJob(
      AFFAsyncEng.MockStep.class.getName(),
      1,
      0
    );
    List<AFF_Job_Enqueue__e> events = new List<AFF_Job_Enqueue__e>{
      new AFF_Job_Enqueue__e(Job_Id__c = testJob.jobId)
    };
    AFFAsyncEng.PlatformEventExecutor executor = new AFFAsyncEng.PlatformEventExecutor(
      events
    );

    Test.startTest();
    executor.execute();
    Test.stopTest();

    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :testJob.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultJob.Status__c,
      'Job should be completed by the executor.'
    );
  }

  @IsTest
  static void testExecutorHandlesEmptyAndNullEvents() {
    Test.startTest();
    // Should not throw any exceptions
    AFFAsyncEng.PlatformEventExecutor executor1 = new AFFAsyncEng.PlatformEventExecutor(
      null
    );
    executor1.execute();
    AFFAsyncEng.PlatformEventExecutor executor2 = new AFFAsyncEng.PlatformEventExecutor(
      new List<AFF_Job_Enqueue__e>()
    );
    executor2.execute();
    Test.stopTest();
    System.assert(
      true,
      'Test passed if no exceptions were thrown for null/empty events.'
    );
  }

  @IsTest
  @SuppressWarnings('PMD.EmptyWhileStmt,PMD.EmptyStatementBlock')
  static void testBatchOrchestratorRequeuesOnLimit() {
    // SETUP
    List<AFFAsync.JobState> jobs = new List<AFFAsync.JobState>();
    for (Integer i = 0; i < 20; i++) {
      jobs.add(createJob(AFFAsyncEng.MockStep.class.getName(), 1, 0));
    }
    List<Id> jobIds = new List<Id>();
    for (AFFAsync.JobState job : jobs) {
      jobIds.add(job.jobId);
    }

    MockEngine mockRetryEngine = new MockEngine();
    AFFAsync.LimitAwareBatchOrchestrator orchestrator = new AFFAsync.DefaultLimitAwareBatchOrchestratorImpl(
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine(), // Main engine
      mockRetryEngine // Retry engine
    );

    // EXECUTE
    Test.startTest();
    // Consume a large portion of the CPU limit to reliably trigger the budget.
    Long startTime = System.currentTimeMillis();
    while (
      System.currentTimeMillis() - startTime < (Limits.getLimitCpuTime() * 0.9)
    ) {
      // This loop will burn CPU time until 90% of the limit is reached.
    }

    orchestrator.run(jobs);
    Test.stopTest();

    // VERIFY
    System.assert(
      mockRetryEngine.startedJobs.size() > 0,
      'Some jobs should have been re-enqueued due to limits.'
    );
    Integer completedJobs = [
      SELECT COUNT()
      FROM AFF_Job__c
      WHERE Id IN :jobIds AND Status__c = :AFFAsyncConsts.STATUS_COMPLETED
    ];
    // With the limit nearly exhausted, very few (or zero) jobs should complete.
    System.assert(
      completedJobs < 20,
      'Not all jobs should be complete when limits are hit.'
    );
  }

  @IsTest
  static void testBatchOrchestratorHandlesCriticalFailure() {
    // SETUP
    AFFAsync.JobState goodJob = createJob(
      AFFAsyncEng.MockStep.class.getName(),
      1,
      0
    );
    AFFAsync.JobState badJob = new AFFAsync.JobState(); // No ID

    List<AFFAsync.JobState> jobs = new List<AFFAsync.JobState>{
      goodJob,
      badJob
    };

    MockEngine mockRetryEngine = new MockEngine();
    AFFAsync.LimitAwareBatchOrchestrator orchestrator = new AFFAsync.DefaultLimitAwareBatchOrchestratorImpl(
      new AFFAsync.DefaultDynamicStepExecutorImpl(),
      new AFFAsync.FixedAttemptsRetrierImpl(1),
      new MockEngine(),
      mockRetryEngine
    );

    // EXECUTE
    Test.startTest();
    orchestrator.run(jobs);
    Test.stopTest();

    // VERIFY
    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :goodJob.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      resultJob.Status__c,
      'Good job should complete successfully.'
    );
    System.assertEquals(
      0,
      mockRetryEngine.startedJobs.size(),
      'No jobs should be re-enqueued after a critical failure.'
    );
  }

  //============================================================================
  //== Saga Compensation Path Tests
  //============================================================================

  @IsTest
  static void testFullSagaWithCompensationFailure() {
    AFFAsync.JobState testJob = createTwoStepJob(
      AFFAsyncEng.FailingCompensationMockStep.class.getName(),
      AFFAsyncEng.FailingMockStep.class.getName()
    );

    List<AFF_Job_Enqueue__e> events = new List<AFF_Job_Enqueue__e>{
      new AFF_Job_Enqueue__e(Job_Id__c = testJob.jobId)
    };
    AFFAsyncEng.PlatformEventExecutor executor = new AFFAsyncEng.PlatformEventExecutor(
      events
    );

    Test.startTest();
    executor.execute(); // Step 0: Success
    executor.execute(); // Step 1: Fails, flips to UP
    executor.execute(); // Step 0: Compensation fails
    Test.stopTest();

    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :testJob.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPENSATION_FAILED,
      resultJob.Status__c,
      'Job should end in Compensation_Failed status.'
    );
  }

  @IsTest
  static void testHappyPathCompensationReachesMockStep() {
    AFFAsyncEng.mockStepCompensateCalledFlag = false;
    AFFAsync.JobState testJob = createTwoStepJob(
      AFFAsyncEng.MockStep.class.getName(),
      AFFAsyncEng.FailingMockStep.class.getName()
    );

    List<AFF_Job_Enqueue__e> events = new List<AFF_Job_Enqueue__e>{
      new AFF_Job_Enqueue__e(Job_Id__c = testJob.jobId)
    };
    AFFAsyncEng.PlatformEventExecutor executor = new AFFAsyncEng.PlatformEventExecutor(
      events
    );

    Test.startTest();
    executor.execute(); // Step 0: Success
    executor.execute(); // Step 1: Fails, flips to UP
    executor.execute(); // Step 0: Compensates
    executor.execute(); // Job completes compensation
    Test.stopTest();

    System.assertEquals(
      true,
      AFFAsyncEng.mockStepCompensateCalledFlag,
      'The compensate flag on the mock step should be true.'
    );
    AFF_Job__c resultJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :testJob.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_FAILED,
      resultJob.Status__c,
      'Job should end in Failed status after successful compensation.'
    );
  }

  @IsTest
  static void testBatchAggregatableCompensationIsCalled() {
    AFFAsyncEng.mockBatchAggregatableCompensateCalledFlag = false;
    AFFAsync.JobState testJob = createTwoStepJob(
      AFFAsyncEng.BatchAggregatableMockStep.class.getName(),
      AFFAsyncEng.FailingMockStep.class.getName()
    );

    List<AFF_Job_Enqueue__e> events = new List<AFF_Job_Enqueue__e>{
      new AFF_Job_Enqueue__e(Job_Id__c = testJob.jobId)
    };
    AFFAsyncEng.PlatformEventExecutor executor = new AFFAsyncEng.PlatformEventExecutor(
      events
    );

    Test.startTest();
    executor.execute(); // Step 0: Success
    executor.execute(); // Step 1: Fails, flips to UP
    executor.execute(); // Step 0: Compensates
    Test.stopTest();

    System.assertEquals(
      true,
      AFFAsyncEng.mockBatchAggregatableCompensateCalledFlag,
      'The compensate flag on the batch aggregatable mock should be true.'
    );
  }
}
