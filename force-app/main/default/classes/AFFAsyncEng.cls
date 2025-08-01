/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description
 * This abstract class serves as a container for various asynchronous engine
 * implementations. It provides a primitive package for different strategies
 * of invoking the saga orchestrator, such as via Platform Events or Queueables.
 * By encapsulating these engines, it allows for flexible and swappable
 * asynchronous execution mechanisms within the framework.
 */
public abstract inherited sharing class AFFAsyncEng {
  @TestVisible
  private interface EventBusPublisher {
    List<Database.SaveResult> publish(List<SObject> events);
  }

  @TestVisible
  private class EventBusPublisherImpl implements EventBusPublisher {
    public List<Database.SaveResult> publish(List<SObject> events) {
      return EventBus.publish(events);
    }
  }

  // // A conservative estimate of DML statements consumed per job in a single
  // // orchestrator transaction. This includes step logic, state updates, etc.
  // private static final Integer DMLS_PER_JOB_ESTIMATE = 6;

  public inherited sharing class PlatformEventEngine implements AFFAsync.Engine {

    @TestVisible
    private EventBusPublisher publisher;

    public PlatformEventEngine() {
      this(new EventBusPublisherImpl());
    }

    /**
     * @description Public constructor for dependency injection in tests.
     */
    @TestVisible
    public PlatformEventEngine(EventBusPublisher publisher) {
      this.publisher = publisher;
    }

    public void start(List<AFFAsync.JobState> jobs) {
      System.debug(
        'ENGINE: start() called with ' +
          (jobs == null ? 0 : jobs.size()) +
          ' jobs.'
      );
      if (jobs == null || jobs.isEmpty()) {
        return;
      }

      List<AFF_Job_Enqueue__e> eventsToPublish = new List<AFF_Job_Enqueue__e>();
      for (AFFAsync.JobState job : jobs) {
        if (String.isNotBlank(job.jobId)) {
          eventsToPublish.add(new AFF_Job_Enqueue__e(Job_Id__c = job.jobId));
        }
      }

      if (eventsToPublish.isEmpty()) {
        System.debug('ENGINE: No events to publish, returning.');
        return;
      }

      System.debug(
        'ENGINE: Prepared ' + eventsToPublish.size() + ' events for publishing.'
      );
      List<Database.SaveResult> results = this.publisher.publish(
        eventsToPublish
      );
      System.debug(
        'ENGINE: Publisher returned ' +
          (results == null ? 0 : results.size()) +
          ' results.'
      );

      List<AFFAsync.JobState> successfulJobs = new List<AFFAsync.JobState>();
      List<AFFAsync.JobState> failedJobs = new List<AFFAsync.JobState>();
      Map<Integer, List<Database.Error>> errorsByJobIndex = new Map<Integer, List<Database.Error>>();

      for (Integer i = 0; i < results.size(); i++) {
        Database.SaveResult sr = results[i];
        AFFAsync.JobState correspondingJob = jobs[i];

        System.debug(
          'ENGINE: Processing result index ' +
            i +
            '. isSuccess: ' +
            sr.isSuccess()
        );

        if (sr.isSuccess()) {
          successfulJobs.add(correspondingJob);
        } else {
          System.debug(
            'ENGINE: Adding job at index ' + i + ' to failedJobs list.'
          );
          failedJobs.add(correspondingJob);
          errorsByJobIndex.put(i, sr.getErrors());
        }
      }

      if (!failedJobs.isEmpty()) {
        System.debug(
          'ENGINE: ' +
            failedJobs.size() +
            ' failed jobs found. Throwing PublishingException...'
        );
        String msg =
          'Failed to publish ' +
          failedJobs.size() +
          ' of ' +
          jobs.size() +
          ' job events.';
        System.debug(
          LoggingLevel.ERROR,
          msg +
            ' Details: ' +
            (
              new Map<String, Object>{
                'successfulJobs' => successfulJobs,
                'failedJobs' => failedJobs,
                'errors' => errorsByJobIndex
              }
            )
        );
        throw new AFFAsync.PublishingException(
          msg,
          successfulJobs,
          failedJobs,
          errorsByJobIndex
        );
      }
      System.debug(
        'ENGINE: No failed jobs found. Exiting start() method normally.'
      );
    }

    // public Integer getRemainingAsyncCalls() {
    //   // Calculate remaining calls based on the most restrictive limit:
    //   // either the number of DML statements or the number of event bus publish calls.

    //   // 1. Calculate remaining based on DML statements limit.
    //   Integer remainingDml =
    //     Limits.getLimitDmlStatements() - Limits.getDmlStatements();
    //   Integer jobsAllowedByDml = remainingDml / DMLS_PER_JOB_ESTIMATE;

    //   // 2. Calculate remaining based on Event Bus publish limit.
    //   Integer remainingPublishCalls =
    //     Limits.getLimitPublishImmediateDML() - Limits.getPublishImmediateDML();

    //   // 3. Return the smaller of the two to be safe.
    //   Integer remaining = Math.min(jobsAllowedByDml, remainingPublishCalls);

    //   System.debug(
    //     'Remaining Calls Calculation: DML-allowed=' +
    //       jobsAllowedByDml +
    //       ', Publish-allowed=' +
    //       remainingPublishCalls +
    //       ', Returning Min=' +
    //       remaining
    //   );

    //   return Math.max(0, remaining);
    // }
  }

  public inherited sharing class PlatformEventExecutor implements AFFBase.Executor {
    private List<AFFAsync.JobState> jobsToProcess;

    public PlatformEventExecutor(List<AFF_Job_Enqueue__e> jobEnqueues) {
      jobsToProcess = new List<AFFAsync.JobState>();
      if (jobEnqueues == null || jobEnqueues.isEmpty()) {
        System.debug(
          'PlatformEventExecutor.PlatformEventExecutor no jobs to process'
        );
        return;
      }
      for (AFF_Job_Enqueue__e jobEnqueue : jobEnqueues) {
        AFFAsync.JobState job = new AFFAsync.JobState();
        job.jobId = jobEnqueue.Job_Id__c;
        jobsToProcess.add(job);
      }
      System.debug('jobsToProcess: ' + JSON.serialize(jobsToProcess));
    }

    public void execute() {
      System.debug(
        'PlatformEventExecutor.execute entered with jobsToProcess: ' +
        jobsToProcess
      );
      if (jobsToProcess.isEmpty()) {
        return;
      }
      AFFAsync.StepExecutor executor = new AFFAsync.DefaultDynamicStepExecutorImpl();
      AFFAsync.Retrier retrier = new AFFAsync.FixedAttemptsRetrierImpl(3);
      AFFAsync.Engine engine = new AFFAsyncEng.PlatformEventEngine();
      AFFAsync.Engine retryEngine = new AFFAsyncEng.PlatformEventEngine();
      AFFAsync.LimitAwareBatchOrchestrator orchestrator = new AFFAsync.DefaultLimitAwareBatchOrchestratorImpl(
        executor,
        retrier,
        engine,
        retryEngine
      );
      orchestrator.run(jobsToProcess);
      System.debug('PlatformEventExecutor.execute completed');
    }
  }

  @TestVisible
  public static Boolean mockStepExecuteCalledFlag = false;
  @TestVisible
  public static Boolean mockStepCompensateCalledFlag = false;
  @TestVisible
  public static Boolean mockFailingStepExecuteCalledFlag = false;
  @TestVisible
  public static Boolean mockBatchAggregatableCompensateCalledFlag = false;

  @TestVisible
  private class TestException extends Exception {
  }

  @TestVisible
  public class MockStep implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      mockStepExecuteCalledFlag = true;
      return new AFFAsync.StepCompletionState(true, 'Mock Success', null);
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      mockStepCompensateCalledFlag = true;
      return new AFFAsync.StepCompletionState(true, 'Mock Compensated', null);
    }
  }

  @TestVisible
  public class FailingMockStep implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      mockFailingStepExecuteCalledFlag = true;
      throw new TestException('Intentional failure for testing compensation');
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      return new AFFAsync.StepCompletionState(true, 'Mock Compensated', null);
    }
  }

  @TestVisible
  public class FailingCompensationMockStep implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      return new AFFAsync.StepCompletionState(true, 'Success', null);
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      throw new TestException('Intentional compensation failure.');
    }
  }

  @TestVisible
  public class BatchAggregatableMockStep implements AFFAsync.Step, AFFAsync.BatchAggregatable {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      return new AFFAsync.StepCompletionState(true, null, null);
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      mockBatchAggregatableCompensateCalledFlag = true;
      return new AFFAsync.StepCompletionState(true, null, null);
    }
    public Object startAggregation(AFFAsync.Context context) {
      return 0;
    }
    public Object executeAggregation(
      AFFAsync.Context context,
      Object currentState,
      List<AFFAsync.ChunkState> chunkBatch
    ) {
      Decimal currentSum = (Decimal) currentState;
      for (AFFAsync.ChunkState chunk : chunkBatch) {
        if (chunk.result instanceof Decimal) {
          currentSum += (Decimal) chunk.result;
        }
      }
      return currentSum;
    }
    public Object finishAggregation(
      AFFAsync.Context context,
      Object finalState
    ) {
      return finalState;
    }
  }
}
