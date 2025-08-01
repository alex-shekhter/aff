/**
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 *  
 * @description Test class for the DefaultBatchProviderImpl, which handles
 * batch database operations for the AFFAsync framework.
 */
@isTest
private class AFFAsyncBatchProviderTest {
  @isTest
  static void testCreateAndGetJobs() {
    AFFAsync.BatchProvider provider = new AFFAsync.DefaultBatchProviderImpl();
    List<AFFAsync.JobState> jobsToCreate = new List<AFFAsync.JobState>();
    for (Integer i = 0; i < 2; i++) {
      AFFAsync.JobState job = new AFFAsync.JobState();
      job.steps.add(new AFFAsync.StepState(0, 'Step' + i, null));
      job.totalSteps = 1;
      jobsToCreate.add(job);
    }

    Test.startTest();
    List<AFFAsync.JobState> createdJobs = provider.createJobs(jobsToCreate);
    Test.stopTest();

    System.assertEquals(2, createdJobs.size(), 'Should create 2 jobs.');
    System.assertNotEquals(
      null,
      createdJobs[0].jobId,
      'Job ID should be populated.'
    );
    System.assertNotEquals(
      null,
      createdJobs[0].steps[0].stepId,
      'Step ID should be populated.'
    );

    List<Id> jobIds = new List<Id>{
      createdJobs[0].jobId,
      createdJobs[1].jobId
    };
    Map<Id, AFFAsync.JobState> retrievedJobs = provider.getJobStates(jobIds);
    System.assertEquals(2, retrievedJobs.size(), 'Should retrieve 2 jobs.');
    System.assert(
      retrievedJobs.containsKey(createdJobs[0].jobId),
      'Retrieved jobs should contain the first job.'
    );
  }

  @isTest
  static void testSaveOperations() {
    AFFAsync.BatchProvider provider = new AFFAsync.DefaultBatchProviderImpl();
    AFFAsync.JobState job = new AFFAsync.JobState();
    job.steps.add(new AFFAsync.StepState(0, 'TestStep', null));
    job.totalSteps = 1;
    job = provider.createJobs(new List<AFFAsync.JobState>{ job })[0];

    job.status = AFFAsyncConsts.STATUS_IN_PROGRESS;
    job.steps[0].status = AFFAsyncConsts.STATUS_IN_PROGRESS;

    AFFAsync.ChunkState chunk = new AFFAsync.ChunkState();
    chunk.parentStepId = job.steps[0].stepId;
    chunk.chunkIndex = 0;
    provider.insertChunks(new List<AFFAsync.ChunkState>{ chunk });
    chunk.status = AFFAsyncConsts.STATUS_COMPLETED;

    job.steps[0].chunks = new List<AFFAsync.ChunkState>{ chunk };

    Test.startTest();
    provider.saveJobs(new List<AFFAsync.JobState>{ job });
    provider.saveSteps(new List<AFFAsync.StepState>{ job.steps[0] });
    provider.saveChunks(new List<AFFAsync.ChunkState>{ chunk });
    Test.stopTest();

    AFF_Job__c updatedJob = [
      SELECT Status__c
      FROM AFF_Job__c
      WHERE Id = :job.jobId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_IN_PROGRESS,
      updatedJob.Status__c,
      'Job status should be updated.'
    );

    AFF_Job_Step__c updatedStep = [
      SELECT Status__c
      FROM AFF_Job_Step__c
      WHERE Id = :job.steps[0].stepId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_IN_PROGRESS,
      updatedStep.Status__c,
      'Step status should be updated.'
    );

    AFF_Job_Step_Chunk__c updatedChunk = [
      SELECT Status__c
      FROM AFF_Job_Step_Chunk__c
      WHERE Id = :chunk.chunkId
    ];
    System.assertEquals(
      AFFAsyncConsts.STATUS_COMPLETED,
      updatedChunk.Status__c,
      'Chunk status should be updated.'
    );
  }

  @isTest
  static void testProviderEdgeCases() {
    AFFAsync.BatchProvider provider = new AFFAsync.DefaultBatchProviderImpl();

    Test.startTest();
    // Test null/empty lists
    System.assertEquals(
      null,
      provider.createJobs(null),
      'createJobs(null) should return null.'
    );
    System.assertEquals(
      0,
      provider.createJobs(new List<AFFAsync.JobState>()).size(),
      'createJobs([]) should return empty list.'
    );
    System.assertEquals(
      0,
      provider.getJobStates(new List<Id>()).size(),
      'getJobStates([]) should return empty map.'
    );
    System.assertEquals(
      null,
      provider.saveJobs(null),
      'saveJobs(null) should return null.'
    );
    System.assertEquals(
      null,
      provider.saveSteps(null),
      'saveSteps(null) should return null.'
    );
    System.assertEquals(
      null,
      provider.saveChunks(null),
      'saveChunks(null) should return null.'
    );
    System.assertEquals(
      null,
      provider.insertChunks(null),
      'insertChunks(null) should return null.'
    );
    Test.stopTest();
  }
}
