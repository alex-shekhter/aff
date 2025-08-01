/**
 *
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * The AFFAsync module provides a framework for creating robust, stateful, multi-transaction
 * asynchronous processes using patterns like Saga and Retry for eventual consistency.
 * It uses a Provider pattern for data persistence, which can be overridden at runtime.
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
public abstract inherited sharing class AFFAsync {
  //================================================================================
  // Data Transfer Objects (DTOs) - Pure state containers
  //================================================================================

  /**
   * The ChunkState class holds the state for a single unit of work within a larger step.
   */
  public inherited sharing class ChunkState {
    public String chunkId { get; set; }
    public String parentStepId { get; set; } // Foreign Key to the parent StepState SObject ID
    public Integer chunkIndex { get; set; }
    public String status { get; set; } // e.g., 'Pending', 'InProgress', 'Completed', 'Failed', 'Compensated'
    public Map<String, Object> payload { get; set; }
    public Object result { get; set; }
    public Map<String, Object> previousValues { get; set; }
    public Integer retryCount { get; set; }
    public String progressState { get; set; }

    public ChunkState() {
      this.status = AFFAsyncConsts.STATUS_PENDING;
    }
  }

  /**
   * The StepState class is used to report the progress and status of an asynchronous step.
   * It now manages a collection of chunks.
   */
  public inherited sharing class StepState {
    public String stepId { get; set; }
    public String parentJobId { get; set; }
    public Integer stepIndex { get; set; }
    public String status { get; set; }
    public String stepExecutorName { get; set; }
    public Map<String, Object> payload { get; set; }
    public Object result { get; set; } // Can be an aggregation of chunk results
    public Map<String, Object> previousValues { get; set; }
    public Integer retryCount { get; set; }
    public String progressState { get; set; }
    // Chunking properties
    public Integer currentChunkIndex { get; set; }
    public Integer totalChunks { get; set; }
    public List<ChunkState> chunks { get; set; }

    public StepState() {
      this.chunks = new List<ChunkState>();
      this.currentChunkIndex = 0;
      this.totalChunks = 0;
      this.status = AFFAsyncConsts.STATUS_PENDING;
    }

    public StepState(
      Integer stepIndex,
      String stepExecutorName,
      Map<String, Object> payload
    ) {
      this(); // Chain to default constructor
      this.stepIndex = stepIndex;
      this.stepExecutorName = stepExecutorName;
      this.payload = payload;
    }
  }

  /**
   * The JobState class is used to report the progress and status of an asynchronous job.
   */
  public inherited sharing class JobState {
    public String jobId { get; set; }
    public String status { get; set; }
    public String direction { get; set; }
    public Integer currentStepIndex { get; set; }
    public Integer totalSteps { get; set; }
    public String finalErrorDetails { get; set; }
    public List<StepState> steps { get; set; }
    public String finalizerClassName { get; set; }
    public Boolean finalizerExecuted { get; set; }

    public JobState() {
      this.steps = new List<StepState>();
      this.status = AFFAsyncConsts.STATUS_NEW;
      this.direction = AFFAsyncConsts.DIRECTION_DOWN;
      this.currentStepIndex = 0;
      this.finalizerExecuted = false;
    }
  }

  /**
   * The StepCompletionState class reports the progress of a single execution (which may be a chunk).
   */
  public inherited sharing class StepCompletionState {
    public Boolean isChunkCompleted { get; private set; }
    public Object partialResult { get; private set; }
    public String nextStepProgressState { get; private set; }
    public Map<String, Object> previousValues { get; private set; }
    public ChunkState nextChunk { get; private set; }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public StepCompletionState(
      Boolean isChunkCompleted,
      Object partialResult,
      String nextStepProgressState,
      ChunkState nextChunk,
      Map<String, Object> previousValues
    ) {
      this.isChunkCompleted = isChunkCompleted;
      this.partialResult = partialResult;
      this.nextStepProgressState = nextStepProgressState;
      this.nextChunk = nextChunk;
      this.previousValues = previousValues;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public StepCompletionState(
      Boolean isChunkCompleted,
      Object partialResult,
      String nextStepProgressState,
      ChunkState nextChunk
    ) {
      this(
        isChunkCompleted,
        partialResult,
        nextStepProgressState,
        nextChunk,
        null
      );
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public StepCompletionState(
      Boolean isChunkCompleted,
      Object partialResult,
      String nextStepProgressState,
      Map<String, Object> previousValues
    ) {
      this(
        isChunkCompleted,
        partialResult,
        nextStepProgressState,
        null,
        previousValues
      );
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public StepCompletionState(
      Boolean isChunkCompleted,
      Object partialResult,
      String nextStepProgressState
    ) {
      this(isChunkCompleted, partialResult, nextStepProgressState, null, null);
    }
  }

  //================================================================================
  // Custom Exceptions
  //================================================================================
  public inherited sharing class PermanentFailureException extends Exception {
  }
  public inherited sharing class StepInitializationException extends Exception {
  }
  public inherited sharing class IllegalArgumentException extends Exception {
  }
  public inherited sharing class PublishingException extends Exception {
    public List<JobState> successfulJobs { get; private set; }
    public List<JobState> failedJobs { get; private set; }
    public Map<Integer, List<Database.Error>> errorsByJobIndex {
      get;
      private set;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public PublishingException(
      String message,
      List<JobState> successfulJobs,
      List<JobState> failedJobs,
      Map<Integer, List<Database.Error>> errorsByJobIndex
    ) {
      setMessage(message);
      this.successfulJobs = successfulJobs;
      this.failedJobs = failedJobs;
      this.errorsByJobIndex = errorsByJobIndex;
    }
  }

  //================================================================================
  // Core Interfaces (The Framework Contracts)
  //================================================================================
  public interface Provider {
    JobState createJob(JobState job);
    JobState getJobState();
    StepState getStepState(Integer stepIndex);
    ChunkState getChunkState(Integer stepIndex, Integer chunkIndex);
    void saveJob(JobState job);
    void saveStep(StepState step);
    void saveChunk(ChunkState chunk);
    void insertChunks(List<ChunkState> chunks);
    void invalidateCache();
  }

  public interface Context {
    JobState getJobState();
    StepState getStepState();
    ChunkState getChunkState();
    Provider getProvider();
  }

  public interface Step {
    StepCompletionState execute(Context context);
    StepCompletionState compensate(Context context);
  }

  public interface Aggregatable {
    Object aggregate(List<ChunkState> chunks);
  }

  public interface BatchAggregatable {
    Object startAggregation(Context context);
    Object executeAggregation(
      Context context,
      Object currentState,
      List<ChunkState> chunkBatch
    );
    Object finishAggregation(Context context, Object finalState);
  }

  public interface Finalizable {
    void onFinish(JobState finalJobState);
  }

  public interface Action {
    Object call();
  }

  public interface Retrier {
    Object execute(Action action);
  }

  public interface StepExecutor {
    Object execute(Context context);
    Object compensate(Context context);
    Step getStepInstance(Context context);
  }

  public interface Orchestrator {
    void run();
  }

  public interface Engine {
    void start(List<JobState> jobs);
  }

  // public interface LimitAwareEngine extends Engine {
  //   Integer getRemainingAsyncCalls();
  // }

  public interface LimitAwareBatchOrchestrator {
    void run(List<JobState> data);
  }

  public interface BatchProvider {
    List<JobState> createJobs(List<JobState> jobs);
    List<JobState> saveJobs(List<JobState> data);
    List<StepState> saveSteps(List<StepState> data);
    List<ChunkState> saveChunks(List<ChunkState> data);
    List<ChunkState> insertChunks(List<ChunkState> data);
    Map<Id, JobState> getJobStates(List<Id> jobIds);
  }

  /* ===============================================================
      SObject Data Conversion Utilities
  =============================================================== */

  // --- Job Conversion ---
  private static AFF_Job__c jobToAffJob(JobState job) {
    return new AFF_Job__c(
      Id = job.jobId,
      Status__c = job.status,
      Direction__c = job.direction,
      Total_Steps__c = job.totalSteps,
      Current_Step_Index__c = job.currentStepIndex,
      Final_Error_Details__c = job.finalErrorDetails,
      Finalizer_Class_Name__c = job.finalizerClassName,
      Finalizer_Executed__c = job.finalizerExecuted
    );
  }

  private static JobState affJobToJobState(AFF_Job__c jobRecord) {
    if (jobRecord == null) {
      return null;
    }
    JobState job = new JobState();
    job.jobId = jobRecord.Id;
    job.status = jobRecord.Status__c;
    job.direction = jobRecord.Direction__c;
    job.totalSteps = (Integer) jobRecord.Total_Steps__c;
    job.currentStepIndex = (Integer) jobRecord.Current_Step_Index__c;
    job.finalErrorDetails = jobRecord.Final_Error_Details__c;
    job.finalizerClassName = jobRecord.Finalizer_Class_Name__c;
    job.finalizerExecuted = jobRecord.Finalizer_Executed__c;
    return job;
  }

  // --- Step Conversion ---
  private static AFF_Job_Step__c stepStateToAffJobStep(StepState step) {
    return new AFF_Job_Step__c(
      Id = step.stepId,
      Status__c = step.status,
      Step_Executor_Name__c = step.stepExecutorName,
      Step_Index__c = step.stepIndex,
      Payload__c = (step.payload == null) ? null : JSON.serialize(step.payload),
      Result__c = (step.result == null) ? null : JSON.serialize(step.result),
      Previous_Values_JSON__c = (step.previousValues == null)
        ? null
        : JSON.serialize(step.previousValues),
      Retry_Count__c = step.retryCount,
      Step_Progress_State__c = step.progressState,
      Current_Chunk_Index__c = step.currentChunkIndex,
      Total_Chunks__c = step.totalChunks
    );
  }

  private static List<AFF_Job_Step__c> stepStatesToAffJobSteps(
    List<StepState> steps
  ) {
    List<AFF_Job_Step__c> jobSteps = new List<AFF_Job_Step__c>();
    for (StepState step : steps) {
      jobSteps.add(stepStateToAffJobStep(step));
    }
    return jobSteps;
  }

  private static StepState affJobStepToStepState(AFF_Job_Step__c stepRecord) {
    StepState step = new StepState();
    step.stepId = stepRecord.Id;
    step.parentJobId = stepRecord.AFF_Job__c;
    step.stepExecutorName = stepRecord.Step_Executor_Name__c;
    step.stepIndex = (Integer) stepRecord.Step_Index__c;
    step.status = stepRecord.Status__c;
    step.result = (stepRecord.Result__c == null)
      ? null
      : JSON.deserializeUntyped(stepRecord.Result__c);
    step.previousValues = (stepRecord.Previous_Values_JSON__c == null)
      ? null
      : (Map<String, Object>) JSON.deserializeUntyped(
          stepRecord.Previous_Values_JSON__c
        );
    step.retryCount = (Integer) stepRecord.Retry_Count__c;
    step.progressState = stepRecord.Step_Progress_State__c;
    step.payload = (stepRecord.Payload__c == null)
      ? null
      : (Map<String, Object>) JSON.deserializeUntyped(stepRecord.Payload__c);
    step.currentChunkIndex = (Integer) stepRecord.Current_Chunk_Index__c;
    step.totalChunks = (Integer) stepRecord.Total_Chunks__c;
    return step;
  }

  // --- Chunk Conversion ---
  private static AFF_Job_Step_Chunk__c chunkStateToAffJobStepChunk(
    ChunkState chunk
  ) {
    return new AFF_Job_Step_Chunk__c(
      Id = chunk.chunkId,
      Chunk_Index__c = chunk.chunkIndex,
      Status__c = chunk.status,
      Payload__c = (chunk.payload == null)
        ? null
        : JSON.serialize(chunk.payload),
      Result__c = (chunk.result == null) ? null : JSON.serialize(chunk.result),
      Previous_Values_JSON__c = (chunk.previousValues == null)
        ? null
        : JSON.serialize(chunk.previousValues),
      Retry_Count__c = chunk.retryCount,
      Progress_State__c = chunk.progressState
    );
  }

  private static List<AFF_Job_Step_Chunk__c> chunkStatesToAffJobStepChunks(
    List<ChunkState> chunks
  ) {
    List<AFF_Job_Step_Chunk__c> records = new List<AFF_Job_Step_Chunk__c>();
    for (ChunkState chunk : chunks) {
      records.add(chunkStateToAffJobStepChunk(chunk));
    }
    return records;
  }

  private static ChunkState affJobStepChunkToChunkState(
    AFF_Job_Step_Chunk__c chunkRecord
  ) {
    ChunkState chunk = new ChunkState();
    chunk.chunkId = chunkRecord.Id;
    chunk.parentStepId = chunkRecord.AFF_Job_Step__c;
    chunk.chunkIndex = (Integer) chunkRecord.Chunk_Index__c;
    chunk.status = chunkRecord.Status__c;
    chunk.payload = (chunkRecord.Payload__c == null)
      ? null
      : (Map<String, Object>) JSON.deserializeUntyped(chunkRecord.Payload__c);
    chunk.result = (chunkRecord.Result__c == null)
      ? null
      : JSON.deserializeUntyped(chunkRecord.Result__c);
    chunk.previousValues = (chunkRecord.Previous_Values_JSON__c == null)
      ? null
      : (Map<String, Object>) JSON.deserializeUntyped(
          chunkRecord.Previous_Values_JSON__c
        );
    chunk.retryCount = (Integer) chunkRecord.Retry_Count__c;
    chunk.progressState = chunkRecord.Progress_State__c;
    return chunk;
  }

  //================================================================================
  // Provider Setup and Dependency Injection
  //================================================================================
  private static Provider sProviderInstance;

  public static void setProvider(Provider newProvider) {
    sProviderInstance = newProvider;
  }

  public static Provider getProvider() {
    if (sProviderInstance == null) {
      sProviderInstance = new SObjectProviderImpl();
    }
    return sProviderInstance;
  }

  //================================================================================
  // Default Implementations (Out-of-the-Box Functionality)
  //================================================================================

  public inherited sharing class SObjectProviderImpl implements Provider {
    private Id jobId;
    private JobState job;
    private Boolean isPreloaded = false;

    public SObjectProviderImpl(JobState preloadedJob) {
      this.job = preloadedJob;
      this.jobId = (preloadedJob == null) ? null : preloadedJob.jobId;
      this.isPreloaded = true;
    }

    public SObjectProviderImpl(Id jobId) {
      this.jobId = jobId;
    }

    @SuppressWarnings('PMD.EmptyStatementBlock')
    public SObjectProviderImpl() {
    }

    public JobState createJob(JobState jobState) {
      if (jobState == null) {
        throw new IllegalArgumentException(AFFAsyncConsts.ERROR_JOB_STATE_NULL);
      }

      AFF_Job__c jobRecord = jobToAffJob(jobState);
      insert as System jobRecord;
      jobState.jobId = jobRecord.Id;

      if (jobState.steps != null && !jobState.steps.isEmpty()) {
        List<AFF_Job_Step__c> stepRecords = new List<AFF_Job_Step__c>();
        for (StepState step : jobState.steps) {
          step.parentJobId = jobState.jobId;
          AFF_Job_Step__c stepRecord = stepStateToAffJobStep(step);
          stepRecord.AFF_Job__c = jobState.jobId;
          stepRecords.add(stepRecord);
        }
        insert as System stepRecords;

        for (Integer i = 0; i < jobState.steps.size(); i++) {
          jobState.steps[i].stepId = stepRecords[i].Id;
        }
      }
      return jobState;
    }

    public void invalidateCache() {
      if (!this.isPreloaded) {
        this.job = null;
      }
    }

    public JobState getJobState() {
      if (job == null) {
        job = loadJobAndSteps();
      }
      return job;
    }

    public StepState getStepState(Integer stepIndex) {
      if (
        stepIndex == null ||
        getJobState() == null ||
        getJobState().steps == null ||
        stepIndex >= getJobState().steps.size() ||
        stepIndex < 0
      ) {
        return null;
      }
      return getJobState().steps[stepIndex];
    }

    public ChunkState getChunkState(Integer stepIndex, Integer chunkIndex) {
      StepState step = getStepState(stepIndex);
      if (step == null || chunkIndex == null || chunkIndex < 0) {
        return null;
      }

      List<AFF_Job_Step_Chunk__c> chunkRecords = [
        SELECT
          Id,
          AFF_Job_Step__c,
          Chunk_Index__c,
          Status__c,
          Payload__c,
          Result__c,
          Previous_Values_JSON__c,
          Retry_Count__c,
          Progress_State__c
        FROM AFF_Job_Step_Chunk__c
        WHERE AFF_Job_Step__c = :step.stepId AND Chunk_Index__c = :chunkIndex
        WITH SYSTEM_MODE
        LIMIT 1
      ];
      return chunkRecords.isEmpty()
        ? null
        : affJobStepChunkToChunkState(chunkRecords[0]);
    }

    public List<ChunkState> getAllChunkStatesForStep(Id stepId) {
      if (stepId == null) {
        return new List<ChunkState>();
      }
      List<ChunkState> chunks = new List<ChunkState>();

      for (AFF_Job_Step_Chunk__c chunkRecord : [
        SELECT
          Id,
          AFF_Job_Step__c,
          Chunk_Index__c,
          Status__c,
          Payload__c,
          Result__c,
          Previous_Values_JSON__c,
          Retry_Count__c,
          Progress_State__c
        FROM AFF_Job_Step_Chunk__c
        WHERE AFF_Job_Step__c = :stepId
        WITH SYSTEM_MODE
        ORDER BY Chunk_Index__c ASC
      ]) {
        chunks.add(affJobStepChunkToChunkState(chunkRecord));
      }
      return chunks;
    }

    private JobState loadJobAndSteps() {
      if (this.jobId == null) {
        throw new IllegalArgumentException(AFFAsyncConsts.ERROR_JOB_ID_NULL);
      }

      AFF_Job__c record = [
        SELECT
          Id,
          Status__c,
          Direction__c,
          Current_Step_Index__c,
          Total_Steps__c,
          Final_Error_Details__c,
          Finalizer_Class_Name__c,
          Finalizer_Executed__c,
          (
            SELECT
              Id,
              AFF_Job__c,
              Status__c,
              Step_Executor_Name__c,
              Payload__c,
              Result__c,
              Previous_Values_JSON__c,
              Retry_Count__c,
              Step_Progress_State__c,
              Current_Chunk_Index__c,
              Total_Chunks__c,
              Step_Index__c
            FROM AFF_Job_Steps__r
            ORDER BY Step_Index__c ASC
          )
        FROM AFF_Job__c
        WHERE Id = :jobId
        WITH SYSTEM_MODE
        LIMIT 1
      ];

      job = affJobToJobState(record);
      if (job == null) {
        return null;
      }
      job.steps = new List<StepState>();

      if (record.AFF_Job_Steps__r != null) {
        for (AFF_Job_Step__c stepRecord : record.AFF_Job_Steps__r) {
          job.steps.add(affJobStepToStepState(stepRecord));
        }
      }
      return job;
    }

    public void saveJob(JobState job) {
      update as System jobToAffJob(job);
    }

    public void saveStep(StepState step) {
      update as System stepStateToAffJobStep(step);
    }

    public void saveChunk(ChunkState chunk) {
      update as System chunkStateToAffJobStepChunk(chunk);
    }

    public void insertChunks(List<ChunkState> chunks) {
      if (chunks == null || chunks.isEmpty()) {
        return;
      }
      List<AFF_Job_Step_Chunk__c> recordsToInsert = new List<AFF_Job_Step_Chunk__c>();
      for (ChunkState chunk : chunks) {
        AFF_Job_Step_Chunk__c newRecord = chunkStateToAffJobStepChunk(chunk);
        newRecord.AFF_Job_Step__c = chunk.parentStepId;
        recordsToInsert.add(newRecord);
      }
      insert as System recordsToInsert;

      for (Integer i = 0; i < chunks.size(); i++) {
        chunks.get(i).chunkId = recordsToInsert.get(i).Id;
      }
    }
  }

  public inherited sharing class DefaultBatchProviderImpl implements BatchProvider {
    public List<JobState> createJobs(List<JobState> jobs) {
      if (jobs == null || jobs.isEmpty()) {
        return jobs;
      }

      List<AFF_Job__c> jobsToInsert = new List<AFF_Job__c>();
      for (JobState jobDto : jobs) {
        jobsToInsert.add(jobToAffJob(jobDto));
      }
      insert as System jobsToInsert;

      List<AFF_Job_Step__c> stepsToInsert = new List<AFF_Job_Step__c>();
      List<StepState> allStepDtos = new List<StepState>();

      for (Integer i = 0; i < jobs.size(); i++) {
        JobState jobDto = jobs[i];
        AFF_Job__c jobRecord = jobsToInsert[i];
        jobDto.jobId = jobRecord.Id;

        if (jobDto.steps != null && !jobDto.steps.isEmpty()) {
          for (StepState stepDto : jobDto.steps) {
            stepDto.parentJobId = jobRecord.Id;
            AFF_Job_Step__c stepSObject = stepStateToAffJobStep(stepDto);
            stepSObject.AFF_Job__c = jobRecord.Id;
            stepsToInsert.add(stepSObject);
            allStepDtos.add(stepDto);
          }
        }
      }

      if (!stepsToInsert.isEmpty()) {
        insert as System stepsToInsert;
        for (Integer i = 0; i < stepsToInsert.size(); i++) {
          allStepDtos[i].stepId = stepsToInsert[i].Id;
        }
      }
      return jobs;
    }

    public List<StepState> saveSteps(List<StepState> steps) {
      if (steps == null || steps.isEmpty()) {
        return steps;
      }
      update as System stepStatesToAffJobSteps(steps);
      return steps;
    }

    public List<ChunkState> saveChunks(List<ChunkState> chunks) {
      if (chunks == null || chunks.isEmpty()) {
        return chunks;
      }
      update as System chunkStatesToAffJobStepChunks(chunks);
      return chunks;
    }

    @SuppressWarnings('PMD.AvoidDeeplyNestedIfStmts')
    public List<JobState> saveJobs(List<JobState> jobs) {
      if (jobs == null || jobs.isEmpty()) {
        return jobs;
      }
      List<AFF_Job__c> affJobs = new List<AFF_Job__c>();
      List<AFF_Job_Step__c> jobSteps = new List<AFF_Job_Step__c>();
      List<AFF_Job_Step_Chunk__c> chunks = new List<AFF_Job_Step_Chunk__c>();
      for (JobState job : jobs) {
        if (String.isNotBlank(job.jobId)) {
          affJobs.add(jobToAffJob(job));
          if (job.steps != null) {
            for (StepState step : job.steps) {
              if (String.isNotBlank(step.stepId)) {
                jobSteps.add(stepStateToAffJobStep(step));
                if (step.chunks != null) {
                  for (ChunkState chunk : step.chunks) {
                    if (String.isNotBlank(chunk.chunkId)) {
                      chunks.add(chunkStateToAffJobStepChunk(chunk));
                    }
                  }
                }
              }
            }
          }
        }
      }
      if (!affJobs.isEmpty()) {
        update as System affJobs;
      }
      if (!jobSteps.isEmpty()) {
        update as System jobSteps;
      }
      if (!chunks.isEmpty()) {
        update as System chunks;
      }
      return jobs;
    }

    public List<ChunkState> insertChunks(List<ChunkState> chunks) {
      if (chunks == null || chunks.isEmpty()) {
        return chunks;
      }
      List<AFF_Job_Step_Chunk__c> newChunkRecords = new List<AFF_Job_Step_Chunk__c>();
      for (ChunkState chunk : chunks) {
        AFF_Job_Step_Chunk__c newRecord = chunkStateToAffJobStepChunk(chunk);
        newRecord.AFF_Job_Step__c = chunk.parentStepId;
        newChunkRecords.add(newRecord);
      }
      insert as System newChunkRecords;
      for (Integer i = 0; i < chunks.size(); i++) {
        chunks[i].chunkId = newChunkRecords[i].Id;
      }
      return chunks;
    }

    public Map<Id, JobState> getJobStates(List<Id> jobIds) {
      if (jobIds == null || jobIds.isEmpty()) {
        return new Map<Id, JobState>();
      }

      Map<Id, JobState> jobStatesById = new Map<Id, JobState>();

      List<AFF_Job__c> records = [
        SELECT
          Id,
          Status__c,
          Direction__c,
          Current_Step_Index__c,
          Total_Steps__c,
          Final_Error_Details__c,
          Finalizer_Class_Name__c,
          Finalizer_Executed__c,
          (
            SELECT
              Id,
              AFF_Job__c,
              Status__c,
              Step_Executor_Name__c,
              Payload__c,
              Result__c,
              Previous_Values_JSON__c,
              Retry_Count__c,
              Step_Progress_State__c,
              Current_Chunk_Index__c,
              Total_Chunks__c,
              Step_Index__c
            FROM AFF_Job_Steps__r
            ORDER BY Step_Index__c ASC
          )
        FROM AFF_Job__c
        WHERE Id IN :jobIds
        WITH SYSTEM_MODE
      ];

      for (AFF_Job__c record : records) {
        JobState job = affJobToJobState(record);
        job.steps = new List<StepState>();
        if (record.AFF_Job_Steps__r != null) {
          for (AFF_Job_Step__c stepRecord : record.AFF_Job_Steps__r) {
            job.steps.add(affJobStepToStepState(stepRecord));
          }
        }
        jobStatesById.put(job.jobId, job);
      }

      return jobStatesById;
    }
  }

  public inherited sharing class DefaultContextImpl implements Context {
    private Provider provider;

    public DefaultContextImpl(Provider provider) {
      this.provider = provider;
    }

    public JobState getJobState() {
      return this.provider.getJobState();
    }

    public StepState getStepState() {
      if (getJobState() == null) {
        return null;
      }
      return this.provider.getStepState(getJobState().currentStepIndex);
    }

    public ChunkState getChunkState() {
      StepState currentStep = getStepState();
      if (
        currentStep == null ||
        currentStep.currentChunkIndex == null ||
        currentStep.currentChunkIndex < 0
      ) {
        return null;
      }

      return this.provider.getChunkState(
        getJobState().currentStepIndex,
        currentStep.currentChunkIndex
      );
    }

    public Provider getProvider() {
      return this.provider;
    }
  }

  public inherited sharing class FixedAttemptsRetrierImpl implements Retrier {
    private final Integer maxAttempts;

    public FixedAttemptsRetrierImpl(Integer maxAttempts) {
      this.maxAttempts = maxAttempts;
    }

    public Object execute(Action action) {
      Exception lastException;
      for (Integer i = 0; i < this.maxAttempts; i++) {
        try {
          return action.call();
        } catch (Exception e) {
          lastException = e;
        }
      }
      throw new PermanentFailureException(
        AFFAsyncConsts.ERROR_PERMANENT_FAILURE_PREFIX +
          this.maxAttempts +
          AFFAsyncConsts.ERROR_PERMANENT_FAILURE_SUFFIX,
        lastException
      );
    }
  }

  public inherited sharing class DefaultDynamicStepExecutorImpl implements StepExecutor {
    public DefaultDynamicStepExecutorImpl() {
      // constructor remains for consistency, but no longer initializes a logger
    }

    private Step instantiateStep(String className) {
      try {
        Type t = Type.forName(className);
        if (t == null) {
          throw new StepInitializationException(
            AFFAsyncConsts.ERROR_COULD_NOT_FIND_CLASS + className
          );
        }
        return (Step) t.newInstance();
      } catch (Exception e) {
        throw new StepInitializationException(
          AFFAsyncConsts.ERROR_COULD_NOT_INSTANTIATE_STEP + className,
          e
        );
      }
    }

    public Step getStepInstance(Context context) {
      return instantiateStep(context.getStepState().stepExecutorName);
    }

    public Object execute(Context context) {
      return getStepInstance(context).execute(context);
    }

    public Object compensate(Context context) {
      return getStepInstance(context).compensate(context);
    }
  }

  private interface StateHandler {
    void handle(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step
    );
  }

  private inherited sharing class ExecuteStepHandler implements StateHandler {
    public void handle(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step
    ) {
      if (step.status == AFFAsyncConsts.STATUS_PENDING) {
        step.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
      }

      StepCompletionState completion = (StepCompletionState) orchestrator.retrier.execute(
        new ExecutionAction(orchestrator.stepExecutor, orchestrator.context)
      );

      ChunkState executionRecordChunk = this.createExecutionRecord(
        step,
        completion
      );
      orchestrator.context.getProvider()
        .insertChunks(new List<ChunkState>{ executionRecordChunk });

      step.totalChunks = (step.totalChunks == null) ? 1 : step.totalChunks + 1;

      if (completion.nextChunk != null) {
        this.handleChunkInProgress(orchestrator, job, step, completion);
      } else {
        this.handleStepCompletion(orchestrator, job, step, completion);
      }
    }

    private ChunkState createExecutionRecord(
      StepState step,
      StepCompletionState completion
    ) {
      ChunkState record = new ChunkState();
      record.parentStepId = step.stepId;
      record.chunkIndex = (step.totalChunks == null) ? 0 : step.totalChunks;
      record.result = completion.partialResult;
      record.status = AFFAsyncConsts.STATUS_COMPLETED;
      record.previousValues = completion.previousValues;
      return record;
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private void handleChunkInProgress(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step,
      StepCompletionState completion
    ) {
      step.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
      step.currentChunkIndex = (step.currentChunkIndex == null)
        ? 1
        : step.currentChunkIndex + 1;
      step.progressState = completion.nextStepProgressState;
      // orchestrator.nextStepEngine.start(new List<JobState>{ job });
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    private void handleStepCompletion(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step,
      StepCompletionState completion
    ) {
      step.status = AFFAsyncConsts.STATUS_COMPLETED;
      step.progressState = completion.nextStepProgressState;

      Step stepInstance = orchestrator.stepExecutor.getStepInstance(
        orchestrator.context
      );

      if (stepInstance instanceof BatchAggregatable) {
        step.result = this.performBatchAggregation(
          orchestrator,
          step,
          (BatchAggregatable) stepInstance
        );
      } else if (stepInstance instanceof Aggregatable) {
        step.result = this.performLegacyAggregation(
          orchestrator,
          (Aggregatable) stepInstance
        );
      } else {
        step.result = completion.partialResult;
      }
      orchestrator.advanceJob(job);
    }

    private Object performBatchAggregation(
      DefaultOrchestratorImpl orchestrator,
      StepState step,
      BatchAggregatable aggregatableStep
    ) {
      Object aggregationState = aggregatableStep.startAggregation(
        orchestrator.context
      );
      List<ChunkState> chunkBatchDTOs = new List<ChunkState>();
      for (AFF_Job_Step_Chunk__c chunkRecord : [
        SELECT
          Id,
          AFF_Job_Step__c,
          Chunk_Index__c,
          Status__c,
          Payload__c,
          Result__c,
          Previous_Values_JSON__c,
          Retry_Count__c,
          Progress_State__c
        FROM AFF_Job_Step_Chunk__c
        WHERE
          AFF_Job_Step__c = :step.stepId
          AND Status__c = :AFFAsyncConsts.STATUS_COMPLETED
        WITH SYSTEM_MODE
        ORDER BY Chunk_Index__c ASC
      ]) {
        chunkBatchDTOs.add(affJobStepChunkToChunkState(chunkRecord));
        if (chunkBatchDTOs.size() == 200) {
          aggregationState = aggregatableStep.executeAggregation(
            orchestrator.context,
            aggregationState,
            chunkBatchDTOs
          );
          chunkBatchDTOs.clear();
        }
      }
      if (!chunkBatchDTOs.isEmpty()) {
        aggregationState = aggregatableStep.executeAggregation(
          orchestrator.context,
          aggregationState,
          chunkBatchDTOs
        );
      }
      return aggregatableStep.finishAggregation(
        orchestrator.context,
        aggregationState
      );
    }

    private Object performLegacyAggregation(
      DefaultOrchestratorImpl orchestrator,
      Aggregatable aggregatableStep
    ) {
      AFFAsync.SObjectProviderImpl provider = (AFFAsync.SObjectProviderImpl) orchestrator.context
        .getProvider();
      Id stepId = orchestrator.context.getStepState().stepId;
      List<ChunkState> allChunks = provider.getAllChunkStatesForStep(stepId);
      return aggregatableStep.aggregate(allChunks);
    }
  }

  private inherited sharing class CompensateStepHandler implements StateHandler {
    public void handle(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step
    ) {
      if (step.status == AFFAsyncConsts.STATUS_COMPLETED) {
        step.status = AFFAsyncConsts.STATUS_COMPENSATING;
        step.progressState = null;
        step.totalChunks = 0;
        step.currentChunkIndex = 0;
      }

      StepCompletionState completion = (StepCompletionState) orchestrator.retrier.execute(
        new CompensationAction(orchestrator.stepExecutor, orchestrator.context)
      );

      ChunkState compensationChunk = new ChunkState();
      compensationChunk.parentStepId = step.stepId;
      compensationChunk.chunkIndex = (step.totalChunks == null)
        ? 0
        : step.totalChunks;
      compensationChunk.result = completion.partialResult;
      compensationChunk.status = AFFAsyncConsts.STATUS_COMPENSATED;
      orchestrator.context.getProvider()
        .insertChunks(new List<ChunkState>{ compensationChunk });

      step.totalChunks = (step.totalChunks == null) ? 1 : step.totalChunks + 1;

      if (completion.nextChunk != null) {
        step.progressState = completion.nextStepProgressState;
        // orchestrator.nextStepEngine.start(new List<JobState>{ job });
      } else {
        step.status = AFFAsyncConsts.STATUS_COMPENSATED;
        orchestrator.regressJob(job);
      }
    }
  }

  private inherited sharing class SkipCompensationHandler implements StateHandler {
    public void handle(
      DefaultOrchestratorImpl orchestrator,
      JobState job,
      StepState step
    ) {
      step.status = AFFAsyncConsts.STATUS_COMPENSATED;
      orchestrator.regressJob(job);
    }
  }

  public inherited sharing virtual class DefaultOrchestratorImpl implements Orchestrator {
    private final Map<String, StateHandler> transitions;
    protected final Context context;
    protected final StepExecutor stepExecutor;
    protected final Retrier retrier;
    protected final Engine nextStepEngine;
    private Boolean isStandalone = true;

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public DefaultOrchestratorImpl(
      Context ctx,
      StepExecutor exec,
      Retrier r,
      Engine engine
    ) {
      this(ctx, exec, r, engine, true); // Default to saving state
    }

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public DefaultOrchestratorImpl(
      Context ctx,
      StepExecutor exec,
      Retrier r,
      Engine engine,
      Boolean isStandalone
    ) {
      this.context = ctx;
      this.stepExecutor = exec;
      this.retrier = r;
      this.nextStepEngine = engine;
      this.isStandalone = isStandalone;

      this.transitions = new Map<String, StateHandler>{
        AFFAsyncConsts.STATE_KEY_DOWN_PENDING => new ExecuteStepHandler(),
        AFFAsyncConsts.STATE_KEY_DOWN_IN_PROGRESS => new ExecuteStepHandler(),
        AFFAsyncConsts.STATE_KEY_UP_COMPLETED => new CompensateStepHandler(),
        AFFAsyncConsts.STATE_KEY_UP_IN_PROGRESS => new CompensateStepHandler(),
        AFFAsyncConsts.STATE_KEY_UP_COMPENSATING => new CompensateStepHandler(),
        AFFAsyncConsts.STATE_KEY_UP_FAILED => new SkipCompensationHandler()
      };
    }

    public virtual void run() {
      this.context.getProvider().invalidateCache();
      JobState job = this.context.getJobState();
      StepState step = null;

      try {
        if (job.status == AFFAsyncConsts.STATUS_NEW) {
          job.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
        }

        if (this.isJobInTerminalState(job)) {
          return;
        }
        step = this.context.getProvider().getStepState(job.currentStepIndex);
        if (step == null) {
          return;
        }

        String stateKey = job.direction + '_' + step.status;
        StateHandler handler = this.transitions.get(stateKey);

        if (handler != null) {
          handler.handle(this, job, step);
        } else {
          String error =
            AFFAsyncConsts.ERROR_UNKNOWN_STATE_TRANSITION + stateKey;
          job.finalErrorDetails = error;
          job.status = AFFAsyncConsts.STATUS_FAILED;
          this.invokeFinalizer(job);
        }
      } catch (PermanentFailureException pfe) {
        // If the cause of the permanent failure is NOT another permanent failure,
        // it means the retrier escalated a reversible exception. In this case,
        // we should treat it as reversible and start compensation.
        if (
          pfe.getCause() != null &&
          !(pfe.getCause() instanceof PermanentFailureException)
        ) {
          this.handleReversibleFailure(job, step, pfe);
        } else {
          this.handlePermanentFailure(job, step, pfe);
        }
      } catch (Exception e) {
        this.handleReversibleFailure(job, step, e);
      } finally {
        if (this.isStandalone) {
          if (step != null) {
            this.context.getProvider().saveStep(step);
          }
          if (job != null) {
            this.context.getProvider().saveJob(job);
          }
        }
      }
    }

    private void invokeFinalizer(JobState job) {
      if (
        String.isNotBlank(job.finalizerClassName) &&
        job.finalizerExecuted != true
      ) {
        try {
          Type t = Type.forName(job.finalizerClassName);
          if (t != null) {
            Finalizable finalizer = (Finalizable) t.newInstance();
            finalizer.onFinish(job);
            job.finalizerExecuted = true;
          }
        } catch (Exception e) {
          System.debug(
            LoggingLevel.ERROR,
            'Failed to invoke finalizer class: ' +
              job.finalizerClassName +
              '. Error: ' +
              e.getMessage()
          );
        }
      }
    }

    private void advanceJob(JobState job) {
      job.currentStepIndex++;
      if (job.currentStepIndex >= job.totalSteps) {
        job.status = AFFAsyncConsts.STATUS_COMPLETED;
        this.invokeFinalizer(job);
      } else {
        if (isStandalone) {
          this.nextStepEngine.start(new List<JobState>{ job });
        }
      }
    }

    private void regressJob(JobState job) {
      job.currentStepIndex--;
      if (job.currentStepIndex < 0) {
        if (job.status != AFFAsyncConsts.STATUS_COMPENSATION_FAILED) {
          job.status = AFFAsyncConsts.STATUS_FAILED;
        }
        this.invokeFinalizer(job);
      } else {
        if (isStandalone) {
          this.nextStepEngine.start(new List<JobState>{ job });
        }
      }
    }

    private void handlePermanentFailure(
      JobState job,
      StepState step,
      Exception e
    ) {
      AFFError.SerializableError error = AFFError.marshal(e);
      error.message = 'PERMANENT FAILURE: ' + error.message;
      job.finalErrorDetails = error.serialize();
      if (step != null) {
        step.status = AFFAsyncConsts.STATUS_FAILED;
      }
      if (job.direction == AFFAsyncConsts.DIRECTION_UP) {
        job.status = AFFAsyncConsts.STATUS_COMPENSATION_FAILED;
      } else {
        job.status = AFFAsyncConsts.STATUS_FAILED;
      }
      this.invokeFinalizer(job);
    }

    private void handleReversibleFailure(
      JobState job,
      StepState step,
      Exception e
    ) {
      AFFError.SerializableError error = AFFError.marshal(e);
      error.message = 'REVERSIBLE FAILURE: ' + error.message;
      job.finalErrorDetails = error.serialize();
      if (job.direction == AFFAsyncConsts.DIRECTION_DOWN) {
        if (step != null) {
          step.status = AFFAsyncConsts.STATUS_FAILED;
        }
        job.status = AFFAsyncConsts.STATUS_AWAITING_COMPENSATION;
        job.direction = AFFAsyncConsts.DIRECTION_UP;
        this.nextStepEngine.start(new List<JobState>{ job });
      } else {
        if (step != null) {
          step.status = AFFAsyncConsts.STATUS_COMPENSATION_FAILED;
        }
        job.status = AFFAsyncConsts.STATUS_COMPENSATION_FAILED;
        this.invokeFinalizer(job);
      }
    }

    private Boolean isJobInTerminalState(JobState job) {
      return (job == null ||
      job.status == AFFAsyncConsts.STATUS_COMPLETED ||
      job.status == AFFAsyncConsts.STATUS_FAILED ||
      job.status == AFFAsyncConsts.STATUS_COMPENSATION_FAILED);
    }
  }

  public inherited sharing class DefaultLimitAwareBatchOrchestratorImpl implements LimitAwareBatchOrchestrator {
    protected StepExecutor exec;
    protected Retrier retrier;
    protected Engine engine;
    protected Engine retryEngine;

    @SuppressWarnings('PMD.ExcessiveParameterList')
    public DefaultLimitAwareBatchOrchestratorImpl(
      StepExecutor exec,
      Retrier r,
      Engine engine,
      Engine retryEngine
    ) {
      this.exec = exec;
      this.retrier = r;
      this.engine = engine;
      this.retryEngine = retryEngine;
    }

    @SuppressWarnings('PMD.NcssMethodCount')
    public virtual void run(List<JobState> jobs) {
      if (jobs == null || jobs.isEmpty()) {
        throw new IllegalArgumentException(
          AFFAsyncConsts.ERROR_JOBS_LIST_INVALID
        );
      }

      AFFLimit.Budget budget = new AFFLimit.Budget(80);
      List<JobState> jobsToProcess = new List<JobState>(jobs);
      List<JobState> jobsToRequeue = new List<JobState>();

      Map<Id, JobState> processedJobsToSave = new Map<Id, JobState>();
      Map<Id, StepState> processedStepsToSave = new Map<Id, StepState>();

      BatchProvider batchProvider = new DefaultBatchProviderImpl();

      List<Id> allJobIds = new List<Id>();
      for (JobState job : jobsToProcess) {
        allJobIds.add(job.jobId);
      }
      Map<Id, JobState> jobStatesById = batchProvider.getJobStates(allJobIds);

      try {
        while (!jobsToProcess.isEmpty()) {
          if (!budget.canContinue()) {
            jobsToRequeue.addAll(jobsToProcess);
            break;
          }

          JobState currentJob = jobsToProcess.get(0);

          try {
            JobState preloadedJobState = jobStatesById.get(currentJob.jobId);
            if (preloadedJobState == null) {
              System.debug(
                LoggingLevel.ERROR,
                'Could not find pre-loaded job state for ID: ' +
                currentJob.jobId
              );
              jobsToProcess.remove(0);
              continue;
            }

            Context ctx = new DefaultContextImpl(
              new SObjectProviderImpl(preloadedJobState)
            );
            Orchestrator singleUnitOrchestrator = new DefaultOrchestratorImpl(
              ctx,
              exec,
              retrier,
              engine,
              false
            );

            singleUnitOrchestrator.run();

            JobState finalJobState = ctx.getJobState();

            jobStatesById.put(finalJobState.jobId, finalJobState);
            processedJobsToSave.put(finalJobState.jobId, finalJobState);

            if (
              finalJobState.currentStepIndex >= 0 &&
              finalJobState.currentStepIndex < finalJobState.steps.size()
            ) {
              StepState processedStep = finalJobState.steps[
                finalJobState.currentStepIndex
              ];
              if (
                processedStep != null && String.isNotBlank(processedStep.stepId)
              ) {
                processedStepsToSave.put(processedStep.stepId, processedStep);
              }
            }

            Boolean isJobFinished =
              finalJobState.status == AFFAsyncConsts.STATUS_COMPLETED ||
              finalJobState.status == AFFAsyncConsts.STATUS_FAILED ||
              finalJobState.status == AFFAsyncConsts.STATUS_COMPENSATION_FAILED;

            if (isJobFinished) {
              jobsToProcess.remove(0);
            } else {
              jobsToProcess.set(0, finalJobState);
            }
          } catch (Exception e) {
            System.debug(
              LoggingLevel.ERROR,
              'Critical orchestrator failure for job ' +
                currentJob.jobId +
                ': ' +
                e.getMessage() +
                '; ' + e.getStackTraceString()
            );
            currentJob.status = AFFAsyncConsts.STATUS_FAILED;
            AFFError.SerializableError error = AFFError.marshal(e);
            error.message = 'CRITICAL ORCHESTRATOR FAILURE: ' + error.message;
            currentJob.finalErrorDetails = error.serialize();
            processedJobsToSave.put(currentJob.jobId, currentJob);
            jobsToProcess.remove(0);
          }
        }
      } finally {
        try {
          if (!processedStepsToSave.isEmpty()) {
            batchProvider.saveSteps(processedStepsToSave.values());
          }
          if (!processedJobsToSave.isEmpty()) {
            batchProvider.saveJobs(processedJobsToSave.values());
          }
        } catch (Exception e) {
          System.debug(
            LoggingLevel.ERROR,
            'Failed to save state at end of transaction: ' +
              e.getMessage() +
              '; ' +
              e.getStackTraceString()
          );
          Map<Id, JobState> requeueMap = new Map<Id, JobState>();
          for (JobState j : jobsToRequeue) {
            requeueMap.put(j.jobId, j);
          }
          for (JobState j : processedJobsToSave.values()) {
            requeueMap.put(j.jobId, j);
          }
          jobsToRequeue = requeueMap.values();
        }

        if (!jobsToRequeue.isEmpty()) {
          System.debug(
            'Re-queueing ' +
              jobsToRequeue.size() +
              ' jobs due to budget limits or errors.'
          );
          retryEngine.start(jobsToRequeue);
        }
      }
    }
  }

  public inherited sharing class ExecutionAction implements Action {
    private StepExecutor exec;
    private Context ctx;
    public ExecutionAction(StepExecutor exec, Context ctx) {
      this.exec = exec;
      this.ctx = ctx;
    }
    public Object call() {
      return this.exec.execute(this.ctx);
    }
  }

  public inherited sharing class CompensationAction implements Action {
    private StepExecutor exec;
    private Context ctx;
    public CompensationAction(StepExecutor exec, Context ctx) {
      this.exec = exec;
      this.ctx = ctx;
    }
    public Object call() {
      return this.exec.compensate(this.ctx);
    }
  }
}
