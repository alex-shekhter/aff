/**
 * @description
 * Demonstrates and validates the AFFAsync framework by managing a bulk ownership
 * change process for Accounts and their related records. This version identifies
 * demo accounts by a unique name prefix, removing the need for a custom field.
 *
 * This version has been updated to use PK Chunking for both execute and compensate
 * methods and includes an advanced, self-validating failure injection framework
 * for testing all compensation scenarios.
 */
@SuppressWarnings('PMD.CognitiveComplexity,PMD.ExcessiveClassLength')
public with sharing class AFF_DEMO_AFFAsync_AccRelOwnerChanger {
  private static final String DEMO_ACCOUNT_NAME_PREFIX = 'AFF Demo Account ';

  /**
   * @description Defines the types of failures that can be injected for testing.
   */
  public enum FailureType {
    REVERSIBLE, // Throws a generic exception to trigger compensation.
    PERMANENT, // Throws a PermanentFailureException to halt the job.
    COMPENSATION_FAIL // Succeeds on execute, fails permanently on compensate.
  }

  /**
   * @description A wrapper class to configure a failure and its expected outcome.
   */
  public class FailureConfig {
    public FailureType failureType { get; private set; }
    public String expectedJobStatus { get; private set; }

    public FailureConfig(FailureType type, String expectedStatus) {
      this.failureType = type;
      this.expectedJobStatus = expectedStatus;
    }
  }

  /**
   * @description Custom exception for this demo class.
   */
  public class DemoException extends Exception {
  }

  //================================================================================
  //== Public Static Methods (Entry Points)
  //================================================================================

  /**
   * @description Creates sample Accounts and a random number of related records.
   * @param ownerLogin The username of the user who will own the created data.
   */
  public static void setupSampleData(String ownerLogin) {
    System.debug('Setting up sample data for owner: ' + ownerLogin);
    User owner = getUserByLogin(ownerLogin);

    // 1. Create Accounts
    List<Account> accountsToInsert = new List<Account>();
    for (Integer i = 0; i < 60; i++) {
      String accountName = DEMO_ACCOUNT_NAME_PREFIX + i;
      Account acc = new Account(
        Name = accountName,
        OwnerId = owner.Id,
        BillingState = 'CA',
        ShippingState = 'CA',
        Type = 'Customer - Direct',
        Industry = 'Technology',
        AnnualRevenue = 1000000,
        NumberOfEmployees = 50 + i,
        Description = 'Sample account for AFFAsync demo.',
        Phone = '555-555-01' + String.valueOf(i).leftPad(2, '0'),
        Website = 'www.affdemo' + i + '.com',
        TickerSymbol = 'AFF' + i,
        Rating = 'Hot'
      );
      accountsToInsert.add(acc);
    }

    insert as system accountsToInsert;
    System.debug(accountsToInsert.size() + ' accounts inserted.');

    // 2. Create Related Records
    List<Contact> contactsToInsert = new List<Contact>();
    List<Opportunity> opportunitiesToInsert = new List<Opportunity>();
    List<Task> tasksToInsert = new List<Task>();

    Integer contactCount = Integer.valueOf(Math.random() * 100) + 100; // 100 to 199
    Integer oppCount = Integer.valueOf(Math.random() * 100) + 100;
    Integer taskCount = Integer.valueOf(Math.random() * 100) + 100;
    System.debug(
      'Preparing to create ' +
        contactCount +
        ' contacts, ' +
        oppCount +
        ' opportunities, and ' +
        taskCount +
        ' tasks.'
    );

    for (Integer i = 0; i < contactCount; i++) {
      contactsToInsert.add(
        new Contact(
          FirstName = 'Demo',
          LastName = 'Contact ' + i,
          OwnerId = owner.Id,
          AccountId = accountsToInsert[Math.mod(i, accountsToInsert.size())].Id
        )
      );
    }

    for (Integer i = 0; i < oppCount; i++) {
      opportunitiesToInsert.add(
        new Opportunity(
          Name = 'Demo Opp ' + i,
          StageName = 'Prospecting',
          CloseDate = Date.today().addMonths(3),
          OwnerId = owner.Id,
          AccountId = accountsToInsert[Math.mod(i, accountsToInsert.size())].Id
        )
      );
    }

    for (Integer i = 0; i < taskCount; i++) {
      tasksToInsert.add(
        new Task(
          Subject = 'Demo Task ' + i,
          Status = 'Not Started',
          Priority = 'Normal',
          OwnerId = owner.Id,
          WhatId = accountsToInsert[Math.mod(i, accountsToInsert.size())].Id
        )
      );
    }

    insert as system contactsToInsert;
    insert as system opportunitiesToInsert;
    insert as system tasksToInsert;
    System.debug('Sample data setup complete.');
  }

  /**
   * @description Starts one ownership change job for each demo account with specific failure instructions.
   * @param currentOwnerLogin The username of the current data owner.
   * @param newOwnerLogin The username of the new data owner.
   * @param failureConfigMap A map where the key is the SObject name (e.g., 'Opportunity') and the value is a FailureConfig object.
   * @return A list of IDs for the newly created AFF_Job__c records.
   */
  public static List<Id> startOwnershipChange(
    String currentOwnerLogin,
    String newOwnerLogin,
    Map<String, FailureConfig> failureConfigMap
  ) {
    System.debug(
      'Starting ownership change process from ' +
        currentOwnerLogin +
        ' to ' +
        newOwnerLogin +
        '. Failure Map: ' +
        failureConfigMap
    );

    User currentOwner = getUserByLogin(currentOwnerLogin);
    User newOwner = getUserByLogin(newOwnerLogin);

    List<Account> accountsToProcess = [
      SELECT Id
      FROM Account
      WHERE
        OwnerId = :currentOwner.Id
        AND Name LIKE :DEMO_ACCOUNT_NAME_PREFIX + '%'
      WITH SYSTEM_MODE
    ];

    if (accountsToProcess.isEmpty()) {
      System.debug(
        LoggingLevel.WARN,
        'No demo accounts found for user: ' + currentOwnerLogin
      );
      throw new DemoException(
        'No demo accounts found for user: ' + currentOwnerLogin
      );
    }
    System.debug(accountsToProcess.size() + ' accounts found for processing.');

    cleanupJobsForAccounts(new Map<Id, Account>(accountsToProcess).keySet());

    Map<String, Integer> sObjectToStepIndexMap = new Map<String, Integer>{
      'Account' => 0,
      'Contact' => 1,
      'Opportunity' => 2,
      'Task' => 3
    };

    Map<String, FailureConfig> stepFailureMap = new Map<String, FailureConfig>();
    if (failureConfigMap != null) {
      for (String sObjectName : failureConfigMap.keySet()) {
        if (sObjectToStepIndexMap.containsKey(sObjectName)) {
          stepFailureMap.put(
            String.valueOf(sObjectToStepIndexMap.get(sObjectName)),
            failureConfigMap.get(sObjectName)
          );
        }
      }
    }

    List<AFFAsync.JobState> jobsToCreate = new List<AFFAsync.JobState>();
    for (Account acc : accountsToProcess) {
      AFFAsync.JobState job = new AFFAsync.JobState();
      job.finalizerClassName = AccRelOwnerChanger_Finalizer.class.getName();

      Map<String, Object> stepPayload = new Map<String, Object>{
        'accountId' => acc.Id,
        'newOwnerId' => newOwner.Id,
        'originalOwnerId' => currentOwner.Id,
        'stepFailureMap' => stepFailureMap
      };

      job.steps.add(
        new AFFAsync.StepState(
          0,
          AccOwnerChange_Step.class.getName(),
          stepPayload
        )
      );
      job.steps.add(
        new AFFAsync.StepState(
          1,
          ContactOwnerChange_Step.class.getName(),
          stepPayload
        )
      );
      job.steps.add(
        new AFFAsync.StepState(
          2,
          OpportunityOwnerChange_Step.class.getName(),
          stepPayload
        )
      );
      job.steps.add(
        new AFFAsync.StepState(
          3,
          TaskOwnerChange_Step.class.getName(),
          stepPayload
        )
      );

      job.totalSteps = job.steps.size();
      jobsToCreate.add(job);
    }
    System.debug(jobsToCreate.size() + ' job states prepared.');

    AFFAsync.BatchProvider batchProvider = new AFFAsync.DefaultBatchProviderImpl();
    AFFAsync.Engine engine = new AFFAsyncEng.PlatformEventEngine();

    List<AFFAsync.JobState> createdJobs = batchProvider.createJobs(
      jobsToCreate
    );
    System.debug('Starting ' + createdJobs.size() + ' jobs via the engine.');
    engine.start(createdJobs);

    List<Id> jobIds = new List<Id>();
    for (AFFAsync.JobState job : createdJobs) {
      jobIds.add(job.jobId);
    }
    System.debug('Jobs started. Returning Job IDs: ' + jobIds);
    return jobIds;
  }

  /**
   * @description Validates the final state of jobs and data ownership after a test run.
   * @param failureConfigMap The failure configuration used, which contains the expected final status. Pass null for a successful execution test.
   * @param originalOwnerLogin The username of the original owner.
   * @param newOwnerLogin The username of the new owner.
   */
  public static void validateResults(
    Map<String, FailureConfig> failureConfigMap,
    String originalOwnerLogin,
    String newOwnerLogin
  ) {
    // Determine the single expected failure config for this run.
    FailureConfig config = (failureConfigMap == null ||
      failureConfigMap.isEmpty())
      ? new FailureConfig(null, AFFAsyncConsts.STATUS_COMPLETED)
      : failureConfigMap.values()[0];

    // Step 1: Discover the data and jobs for this test run.
    User originalOwner = getUserByLogin(originalOwnerLogin);
    User newOwner = getUserByLogin(newOwnerLogin);

    Set<Id> accountIds = new Map<Id, Account>(
        [
          SELECT Id
          FROM Account
          WHERE
            Name LIKE :DEMO_ACCOUNT_NAME_PREFIX + '%'
            AND (OwnerId = :originalOwner.Id
            OR OwnerId = :newOwner.Id)
          WITH SYSTEM_MODE
        ]
      )
      .keySet();
    System.assert(
      !accountIds.isEmpty(),
      'Validation failed: No demo accounts found for the specified users.'
    );

    List<AFF_Job__c> jobs = findJobsForAccounts(accountIds);
    System.assert(
      !jobs.isEmpty(),
      'Validation failed: No jobs found for the demo accounts.'
    );

    // Step 2: Validate Job Status
    String expectedStatus = config.expectedJobStatus;
    System.debug(
      'Validating ' +
        jobs.size() +
        ' jobs. Expected final status: ' +
        expectedStatus
    );
    System.assertEquals(
      accountIds.size(),
      jobs.size(),
      'The number of jobs found (' +
        jobs.size() +
        ') does not match the number of accounts (' +
        accountIds.size() +
        ').'
    );

    for (AFF_Job__c job : jobs) {
      System.assertEquals(
        expectedStatus,
        job.Status__c,
        'Job ' + job.Id + ' did not end in the expected status.'
      );
    }
    System.debug(
      'Validation successful: All ' +
        jobs.size() +
        ' jobs ended with status ' +
        expectedStatus
    );

    // Step 3: Validate Data Ownership State based on the test scenario
    System.debug(
      'Validating data ownership based on failure type: ' + config.failureType
    );

    if (config.failureType == null) {
      // USE CASE 1: Successful Execution
      System.debug('Expecting data to be owned by new owner: ' + newOwnerLogin);
      validateAllRecordsOwnedBy(newOwner.Id, accountIds, 'new owner');
    } else if (config.failureType == FailureType.REVERSIBLE) {
      // USE CASE 2: Successful Compensation
      System.debug(
        'Expecting data to be owned by original owner: ' + originalOwnerLogin
      );
      validateAllRecordsOwnedBy(originalOwner.Id, accountIds, 'original owner');
    } else if (config.failureType == FailureType.PERMANENT) {
      // USE CASE 4: Permanent Failure
      System.debug('Expecting INCONSISTENT data state.');
      String failingStepName = new List<String>(failureConfigMap.keySet())[0];
      validateInconsistentState(
        originalOwner.Id,
        newOwner.Id,
        accountIds,
        failingStepName
      );
    } else if (config.failureType == FailureType.COMPENSATION_FAIL) {
      // USE CASE 3: Failed Compensation
      System.debug(
        'Expecting INCONSISTENT data state from failed compensation.'
      );
      String failingStepName = '';
      for (String key : failureConfigMap.keySet()) {
        if (
          failureConfigMap.get(key).failureType == FailureType.COMPENSATION_FAIL
        ) {
          failingStepName = key;
          break;
        }
      }
      validateInconsistentStateAfterCompFailure(
        originalOwner.Id,
        newOwner.Id,
        accountIds,
        failingStepName
      );
    }
  }

  private static void hardDeleteSObjs(List<SObject> objs) {
    if (objs == null || objs.isEmpty()) {
      return;
    }
    List<Id> idsToEmpty = new List<Id>();
    for (SObject o : objs) {
      idsToEmpty.add(o.Id);
    }
    delete as system objs;
    if (!idsToEmpty.isEmpty()) {
      Database.emptyRecycleBin(idsToEmpty);
    }
  }

  /**
   * @description Deletes all data and jobs created by this demo and empties the recycle bin.
   */
  public static void cleanupData() {
    System.debug('Starting data cleanup.');

    List<Account> accountsToDelete = [
      SELECT Id
      FROM Account
      WHERE Name LIKE :DEMO_ACCOUNT_NAME_PREFIX + '%'
      WITH SYSTEM_MODE
    ];
    if (accountsToDelete.isEmpty()) {
      System.debug('No demo data found to clean up.');
      return;
    }

    Set<Id> accountIds = new Map<Id, Account>(accountsToDelete).keySet();
    cleanupJobsForAccounts(accountIds);

    hardDeleteSObjs(
      [SELECT id FROM Opportunity WHERE AccountId IN :accountIds]
    );
    System.debug('Opportunity deleted...');
    hardDeleteSObjs([SELECT id FROM Case WHERE AccountId IN :accountIds]);
    System.debug('Case deleted...');
    hardDeleteSObjs([SELECT id FROM Contact WHERE AccountId IN :accountIds]);
    System.debug('Contact deleted...');
    hardDeleteSObjs([SELECT id FROM Task WHERE WhatId IN :accountIds]);
    System.debug('Task deleted...');

    hardDeleteSObjs(accountsToDelete);
    System.debug('Accounts deleted...');
    System.debug('Cleanup complete.');
  }

  //================================================================================
  //== Private Helper Methods
  //================================================================================

  private static User getUserByLogin(String login) {
    List<User> users = [
      SELECT Id
      FROM User
      WHERE Username = :login AND IsActive = TRUE
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    if (users.isEmpty()) {
      System.debug(
        LoggingLevel.ERROR,
        'Active user not found for login: ' + login
      );
      throw new DemoException('Active user not found for login: ' + login);
    }
    return users[0];
  }

  private static List<AFF_Job__c> findJobsForAccounts(Set<Id> accountIds) {
    Set<Id> jobIds = new Set<Id>();
    for (AFF_Job_Step__c step : [
      SELECT AFF_Job__c, Payload__c
      FROM AFF_Job_Step__c
      WITH SYSTEM_MODE
    ]) {
      if (step.Payload__c != null) {
        try {
          Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(
            step.Payload__c
          );
          if (
            payload != null &&
            payload.containsKey('accountId') &&
            accountIds.contains((Id) payload.get('accountId'))
          ) {
            jobIds.add(step.AFF_Job__c);
          }
        } catch (JSONException e) {
          System.debug(
            LoggingLevel.WARN,
            'Could not deserialize payload for step: ' +
              step.Id +
              '. Error: ' +
              e.getMessage()
          );
        }
      }
    }
    if (jobIds.isEmpty()) {
      return new List<AFF_Job__c>();
    }
    return [
      SELECT Id, Status__c
      FROM AFF_Job__c
      WHERE Id IN :jobIds
      WITH SYSTEM_MODE
    ];
  }

  private static void cleanupJobsForAccounts(Set<Id> accountIds) {
    System.debug(
      'Cleaning up previous jobs for ' + accountIds.size() + ' accounts.'
    );
    List<AFF_Job__c> jobsToDelete = findJobsForAccounts(accountIds);
    if (!jobsToDelete.isEmpty()) {
      System.debug('Found ' + jobsToDelete.size() + ' old jobs to delete.');
      List<AFF_Job_Step__c> stepsToDelete = [
        SELECT Id
        FROM AFF_Job_Step__c
        WHERE AFF_Job__c IN :jobsToDelete
        WITH SYSTEM_MODE
      ];
      if (!stepsToDelete.isEmpty()) {
        List<AFF_Job_Step_Chunk__c> chunksToDelete = [
          SELECT Id
          FROM AFF_Job_Step_Chunk__c
          WHERE AFF_Job_Step__c IN :stepsToDelete
          WITH SYSTEM_MODE
        ];
        if (!chunksToDelete.isEmpty()) {
          hardDeleteSObjs(chunksToDelete);
        }
        hardDeleteSObjs(stepsToDelete);
      }
      hardDeleteSObjs(jobsToDelete);
      System.debug(
        jobsToDelete.size() + ' old jobs and their children deleted.'
      );
    }
  }

  // New helper method to check for consistent state (all records owned by one user)
  private static void validateAllRecordsOwnedBy(
    Id expectedOwnerId,
    Set<Id> accountIds,
    String ownerType
  ) {
    Integer wrongOwnerAccounts = [
      SELECT COUNT()
      FROM Account
      WHERE Id IN :accountIds AND OwnerId != :expectedOwnerId
    ];
    Integer wrongOwnerContacts = [
      SELECT COUNT()
      FROM Contact
      WHERE AccountId IN :accountIds AND OwnerId != :expectedOwnerId
    ];
    Integer wrongOwnerOpps = [
      SELECT COUNT()
      FROM Opportunity
      WHERE AccountId IN :accountIds AND OwnerId != :expectedOwnerId
    ];
    Integer wrongOwnerTasks = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId IN :accountIds AND OwnerId != :expectedOwnerId
    ];

    System.assertEquals(
      0,
      wrongOwnerAccounts,
      'Found Accounts not owned by the ' + ownerType
    );
    System.assertEquals(
      0,
      wrongOwnerContacts,
      'Found Contacts not owned by the ' + ownerType
    );
    System.assertEquals(
      0,
      wrongOwnerOpps,
      'Found Opportunities not owned by the ' + ownerType
    );
    System.assertEquals(
      0,
      wrongOwnerTasks,
      'Found Tasks not owned by the ' + ownerType
    );
    System.debug(
      'Data ownership validation successful. All records are owned by the ' +
      ownerType
    );
  }

  // New helper method for permanent failure state
  private static void validateInconsistentState(
    Id originalOwnerId,
    Id newOwnerId,
    Set<Id> accountIds,
    String failingStepName
  ) {
    Map<String, Integer> sObjectToStepIndexMap = new Map<String, Integer>{
      'Account' => 0,
      'Contact' => 1,
      'Opportunity' => 2,
      'Task' => 3
    };
    Integer failingStepIndex = sObjectToStepIndexMap.get(failingStepName);

    // Validate Accounts: Should be owned by new owner if the failure happened after step 0
    Id expectedAccountOwner = (failingStepIndex > 0)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerAccounts = [
      SELECT COUNT()
      FROM Account
      WHERE Id IN :accountIds AND OwnerId != :expectedAccountOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerAccounts,
      'Account ownership is incorrect for permanent failure scenario.'
    );

    // Validate Contacts: Should be owned by new owner if the failure happened after step 1
    Id expectedContactOwner = (failingStepIndex > 1)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerContacts = [
      SELECT COUNT()
      FROM Contact
      WHERE AccountId IN :accountIds AND OwnerId != :expectedContactOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerContacts,
      'Contact ownership is incorrect for permanent failure scenario.'
    );

    // Validate Opportunities: Should be owned by new owner if the failure happened after step 2
    Id expectedOppOwner = (failingStepIndex > 2) ? newOwnerId : originalOwnerId;
    Integer wrongOwnerOpps = [
      SELECT COUNT()
      FROM Opportunity
      WHERE AccountId IN :accountIds AND OwnerId != :expectedOppOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerOpps,
      'Opportunity ownership is incorrect for permanent failure scenario.'
    );

    // Validate Tasks: Should be owned by new owner if the failure happened after step 3
    Id expectedTaskOwner = (failingStepIndex > 3)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerTasks = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId IN :accountIds AND OwnerId != :expectedTaskOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerTasks,
      'Task ownership is incorrect for permanent failure scenario.'
    );

    System.debug(
      'Inconsistent data state validation successful for permanent failure at step: ' +
      failingStepName
    );
  }

  // helper for compensation failure state
  private static void validateInconsistentStateAfterCompFailure(
    Id originalOwnerId,
    Id newOwnerId,
    Set<Id> accountIds,
    String failingStepName
  ) {
    Map<String, Integer> sObjectToStepIndexMap = new Map<String, Integer>{
      'Account' => 0,
      'Contact' => 1,
      'Opportunity' => 2,
      'Task' => 3
    };
    Integer failingStepIndex = sObjectToStepIndexMap.get(failingStepName);

    // Rule: If a step's index is LESS THAN the failing compensation step's index,
    // its compensation was never attempted. It remains with the NEW owner.
    // If a step's index is EQUAL to the failing step's index, its compensation failed.
    // It also remains with the NEW owner.
    // If a step's index is GREATER than the failing step's index, its compensation
    // succeeded before the failure. It is reverted to the ORIGINAL owner.

    Id expectedAccountOwner = (0 <= failingStepIndex)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerAccounts = [
      SELECT COUNT()
      FROM Account
      WHERE Id IN :accountIds AND OwnerId != :expectedAccountOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerAccounts,
      'Account ownership is incorrect for compensation failure scenario.'
    );

    Id expectedContactOwner = (1 <= failingStepIndex)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerContacts = [
      SELECT COUNT()
      FROM Contact
      WHERE AccountId IN :accountIds AND OwnerId != :expectedContactOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerContacts,
      'Contact ownership is incorrect for compensation failure scenario.'
    );

    Id expectedOppOwner = (2 <= failingStepIndex)
      ? newOwnerId
      : originalOwnerId;
    Integer wrongOwnerOpps = [
      SELECT COUNT()
      FROM Opportunity
      WHERE AccountId IN :accountIds AND OwnerId != :expectedOppOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerOpps,
      'Opportunity ownership is incorrect for compensation failure scenario.'
    );

    // Tasks were never executed in the forward direction, so they should always
    // remain with the original owner in this scenario.
    Id expectedTaskOwner = originalOwnerId;
    Integer wrongOwnerTasks = [
      SELECT COUNT()
      FROM Task
      WHERE WhatId IN :accountIds AND OwnerId != :expectedTaskOwner
    ];
    System.assertEquals(
      0,
      wrongOwnerTasks,
      'Task ownership is incorrect for compensation failure scenario.'
    );

    System.debug(
      'Inconsistent data state validation successful for compensation failure at step: ' +
      failingStepName
    );
  }

  //================================================================================
  //== Step and Finalizer Implementations (Inner Classes)
  //================================================================================

  /**
   * @description Step 1: Changes the owner of the single Account in the job payload.
   */
  public with sharing class AccOwnerChange_Step implements AFFAsync.Step {
    public AFFAsync.StepCompletionState execute(AFFAsync.Context context) {
      Map<String, Object> payload = context.getStepState().payload;
      Id accountId = (Id) payload.get('accountId');
      Id newOwnerId = (Id) payload.get('newOwnerId');
      System.debug('Executing AccOwnerChange_Step for AccountId: ' + accountId);

      Account accToUpdate = new Account(Id = accountId, OwnerId = newOwnerId);
      update as system accToUpdate;

      return new AFFAsync.StepCompletionState(
        true,
        'Account owner changed.',
        null
      );
    }
    public AFFAsync.StepCompletionState compensate(AFFAsync.Context context) {
      Map<String, Object> payload = context.getStepState().payload;
      Id accountId = (Id) payload.get('accountId');
      Id originalOwnerId = (Id) payload.get('originalOwnerId');
      System.debug(
        LoggingLevel.WARN,
        'Compensating AccOwnerChange_Step for AccountId: ' + accountId
      );

      Account accToUpdate = new Account(
        Id = accountId,
        OwnerId = originalOwnerId
      );
      update as system accToUpdate;

      return new AFFAsync.StepCompletionState(
        true,
        'Account ownership compensated.',
        null
      );
    }
  }

  /**
   * @description Abstract base class for chunked owner changes of related records using PK Chunking.
   */
  public abstract with sharing class RelatedRecordsOwnerChange_Step implements AFFAsync.Step {
    protected abstract String getSObjectType();
    protected abstract String getLookupFieldName();
    protected virtual Integer getChunkSize() {
      return 1;
    }

    private void checkForFailure(
      AFFAsync.Context context,
      String failurePoint
    ) {
      Map<String, Object> payload = context.getStepState().payload;
      if (!payload.containsKey('stepFailureMap'))
        return;

      Map<String, Object> failureMap = (Map<String, Object>) payload.get(
        'stepFailureMap'
      );
      if (failureMap == null || failureMap.isEmpty())
        return;

      String stepIndexKey = String.valueOf(context.getStepState().stepIndex);

      if (failureMap.containsKey(stepIndexKey)) {
        FailureConfig config = (FailureConfig) JSON.deserialize(
          JSON.serialize(failureMap.get(stepIndexKey)),
          FailureConfig.class
        );
        if (String.valueOf(config.failureType) == failurePoint) {
          String errorMessage =
            'Intentional ' +
            failurePoint +
            ' failure for step ' +
            stepIndexKey;
          System.debug(LoggingLevel.ERROR, errorMessage);
          if (
            config.failureType == FailureType.PERMANENT ||
            config.failureType == FailureType.COMPENSATION_FAIL
          ) {
            throw new AFFAsync.PermanentFailureException(errorMessage);
          } else {
            throw new DemoException(errorMessage);
          }
        }
      }
    }

    public virtual AFFAsync.StepCompletionState execute(
      AFFAsync.Context context
    ) {
      System.debug('--> EXECUTE START for ' + getSObjectType());
      checkForFailure(context, 'REVERSIBLE');
      checkForFailure(context, 'PERMANENT');

      Map<String, Object> payload = context.getStepState().payload;
      Id accountId = (Id) payload.get('accountId');
      Id newOwnerId = (Id) payload.get('newOwnerId');
      String lastProcessedId = context.getStepState().progressState;
      System.debug('    Initial lastProcessedId: ' + lastProcessedId);

      String query =
        'SELECT Id FROM ' +
        getSObjectType() +
        ' WHERE ' +
        getLookupFieldName() +
        ' = :accountId';
      if (String.isNotBlank(lastProcessedId)) {
        query +=
          ' AND Id > \'' +
          String.escapeSingleQuotes(lastProcessedId) +
          '\'';
      }
      query += ' ORDER BY Id ASC LIMIT ' + getChunkSize();
      System.debug('    Executing query: ' + query);

      List<SObject> recordsToProcess = Database.query(query);
      System.debug(
        '    Found ' + recordsToProcess.size() + ' records to process.'
      );

      if (!recordsToProcess.isEmpty()) {
        String sObjectName = getSObjectType();
        List<SObject> recordsToUpdate = new List<SObject>();
        for (SObject record : recordsToProcess) {
          SObject sObj = (SObject) Type.forName(sObjectName).newInstance();
          sObj.put('Id', record.Id);
          sObj.put('OwnerId', newOwnerId);
          recordsToUpdate.add(sObj);
        }
        update as system recordsToUpdate;
        lastProcessedId = recordsToProcess[recordsToProcess.size() - 1].Id;
        System.debug(
          '    Updated ' +
            recordsToUpdate.size() +
            ' records. New lastProcessedId: ' +
            lastProcessedId
        );
      }

      AFFAsync.ChunkState nextChunk = (recordsToProcess.size() ==
        getChunkSize())
        ? new AFFAsync.ChunkState()
        : null;
      System.debug('    Scheduling next chunk? ' + (nextChunk != null));
      System.debug('<-- EXECUTE END for ' + getSObjectType());

      return new AFFAsync.StepCompletionState(
        nextChunk == null,
        recordsToProcess.size() + ' ' + getSObjectType() + 's updated.',
        lastProcessedId,
        nextChunk
      );
    }

    public virtual AFFAsync.StepCompletionState compensate(
      AFFAsync.Context context
    ) {
      System.debug('--> COMPENSATE START for ' + getSObjectType());
      checkForFailure(context, 'COMPENSATION_FAIL');

      Map<String, Object> payload = context.getStepState().payload;
      Id accountId = (Id) payload.get('accountId');
      Id originalOwnerId = (Id) payload.get('originalOwnerId');
      Id newOwnerId = (Id) payload.get('newOwnerId');
      String lastProcessedId = context.getStepState().progressState;
      System.debug('    Initial lastProcessedId: ' + lastProcessedId);

      String query =
        'SELECT Id FROM ' +
        getSObjectType() +
        ' WHERE ' +
        getLookupFieldName() +
        ' = :accountId' +
        ' AND OwnerId = :newOwnerId';
      if (String.isNotBlank(lastProcessedId)) {
        query +=
          ' AND Id > \'' +
          String.escapeSingleQuotes(lastProcessedId) +
          '\'';
      }
      query += ' ORDER BY Id ASC LIMIT ' + getChunkSize();
      System.debug('    Executing query: ' + query);

      List<SObject> recordsToProcess = Database.query(query);
      System.debug(
        '    Found ' + recordsToProcess.size() + ' records to compensate.'
      );

      if (!recordsToProcess.isEmpty()) {
        String sObjectName = getSObjectType();
        List<SObject> recordsToUpdate = new List<SObject>();
        for (SObject record : recordsToProcess) {
          SObject sObj = (SObject) Type.forName(sObjectName).newInstance();
          sObj.put('Id', record.Id);
          sObj.put('OwnerId', originalOwnerId);
          recordsToUpdate.add(sObj);
        }
        update as system recordsToUpdate;
        lastProcessedId = recordsToProcess[recordsToProcess.size() - 1].Id;
        System.debug(
          '    Compensated ' +
            recordsToUpdate.size() +
            ' records. New lastProcessedId: ' +
            lastProcessedId
        );
      }

      AFFAsync.ChunkState nextChunk = (recordsToProcess.size() ==
        getChunkSize())
        ? new AFFAsync.ChunkState()
        : null;
      System.debug(
        '    Scheduling next compensation chunk? ' + (nextChunk != null)
      );
      System.debug('<-- COMPENSATE END for ' + getSObjectType());

      return new AFFAsync.StepCompletionState(
        nextChunk == null,
        recordsToProcess.size() + ' ' + getSObjectType() + 's compensated.',
        lastProcessedId,
        nextChunk
      );
    }
  }

  /**
   * @description Step 2: Changes the owner of all related Contacts.
   */
  public with sharing class ContactOwnerChange_Step extends RelatedRecordsOwnerChange_Step {
    protected override String getSObjectType() {
      return 'Contact';
    }
    protected override String getLookupFieldName() {
      return 'AccountId';
    }
  }

  /**
   * @description Step 3: Changes the owner of all related Opportunities.
   */
  public with sharing class OpportunityOwnerChange_Step extends RelatedRecordsOwnerChange_Step {
    protected override String getSObjectType() {
      return 'Opportunity';
    }
    protected override String getLookupFieldName() {
      return 'AccountId';
    }
  }

  /**
   * @description Step 4: Changes the owner of all related Tasks.
   */
  public with sharing class TaskOwnerChange_Step extends RelatedRecordsOwnerChange_Step {
    protected override String getSObjectType() {
      return 'Task';
    }
    protected override String getLookupFieldName() {
      return 'WhatId';
    }
  }

  /**
   * @description Finalizer: Logs the outcome of the job.
   */
  public with sharing class AccRelOwnerChanger_Finalizer implements AFFAsync.Finalizable {
    public void onFinish(AFFAsync.JobState finalJobState) {
      if (finalJobState.status == AFFAsyncConsts.STATUS_COMPLETED) {
        System.debug('Job ' + finalJobState.jobId + ' completed successfully.');
      } else {
        System.debug(
          LoggingLevel.ERROR,
          'Job ' +
            finalJobState.jobId +
            ' finished with status ' +
            finalJobState.status +
            '. Final State: ' +
            JSON.serialize(finalJobState)
        );
      }
    }
  }
}
