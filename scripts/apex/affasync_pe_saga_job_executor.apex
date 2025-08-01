/**
 * @description
 * Anonymous Apex script for testing the AFFAsync Saga Framework.
 *
 * This script allows you to easily configure and run various test scenarios,
 * including successful execution, reversible failures (successful compensation),
 * permanent failures, and failed compensations.
 *
 * USAGE:
 * 1. Ensure your user logins are correct.
 * 2. Uncomment ONLY ONE of the test case configurations in the "SETUP TEST SCENARIO" section.
 * 3. Uncomment and run the desired execution steps in the "EXECUTION STEPS" section.
 * 4. Use the SOQL queries at the bottom to inspect the results.
 */

//================================================================================
//== USER CONFIGURATION
//================================================================================
// Replace with the username of the data's original owner.
final String originalOwnerLogin = 'alex.shekhter@gmail.com.aff';
// Replace with the username of the user who should become the new owner.
final String newOwnerLogin = 'alex.shekhter@gmail.com.aff2';


//================================================================================
//== SETUP TEST SCENARIO
//  - Uncomment the ONE test case you wish to run.
//================================================================================

//
// --- USE CASE 1: Successful Execution ---
// No failures are injected. All steps should complete successfully.
//
Map<String, AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig> failures = null;

//
// --- USE CASE 2: Successful Compensation (Reversible Failure) ---
// DESCRIPTION: This test makes the 'Opportunity' step (Step 2) fail reversibly.
// EXPECTED BEHAVIOR: The framework will execute steps 0 and 1, fail on step 2,
// then reverse direction and successfully compensate steps 1 and 0.
// FINAL JOB STATUS: 'Failed' (because the forward transaction did not complete).
// FINAL DATA STATE: All records should remain owned by the originalOwnerLogin.
//

failures = new Map<String, AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig>{
    'Opportunity' => new AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig(
        AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureType.REVERSIBLE,
        AFFAsyncConsts.STATUS_FAILED
      )
};


//
// --- USE CASE 3: Failed Compensation ---
// DESCRIPTION: This is a critical test. The 'Contact' step (Step 1) is configured
// to FAIL its compensation logic. The 'Opportunity' step (Step 2) is configured
// to fail reversibly, which acts as the trigger to start the rollback process.
// EXPECTED BEHAVIOR: The framework will execute steps 0 and 1, fail on step 2,
// reverse direction, and then attempt to compensate step 1. The compensation for
// step 1 will throw a permanent exception, halting the entire rollback.
// FINAL JOB STATUS: 'Compensation_Failed', signaling that manual data intervention is required.
// FINAL DATA STATE: Inconsistent. 
//                    Accounts (Step 0):      Their compensation was never attempted because 
//                                            the process halted at step 1. 
//                                            They should remain owned by the new owner.
//                    Contacts (Step 1):      Their compensation failed. They should remain owned by the new owner.
//                    Opportunities (Step 2): Their compensation succeeded before the failure 
//                                            at step 1. They should be reverted to the original owner.
//                    Tasks (Step 3):         They were never processed in the forward direction. 
//                                            They should still be owned by the original owner
//
/*
failures = new Map<String, AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig>{
    'Contact' => new AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig(
        AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureType.COMPENSATION_FAIL,
        AFFAsyncConsts.STATUS_COMPENSATION_FAILED
    ),
    'Opportunity' => new AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig(
      AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureType.REVERSIBLE,
      AFFAsyncConsts.STATUS_COMPENSATION_FAILED // The final job status is what matters.
    )
};
*/

//
// --- USE CASE 4: Permanent Failure (No Compensation) ---
// DESCRIPTION: This test makes the 'Opportunity' step (Step 2) fail permanently.
// EXPECTED BEHAVIOR: The framework will execute steps 0 and 1, then hit the permanent
// failure on step 2. The job will immediately halt and will NOT attempt any compensation.
// FINAL JOB STATUS: 'Failed'.
// FINAL DATA STATE: Inconsistent. Accounts and Contacts will be owned by the newOwnerLogin,
// but Opportunities and Tasks will remain with the originalOwnerLogin.
//
/*
failures = new Map<String, AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig>{
    'Opportunity' => new AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureConfig(
      AFF_DEMO_AFFAsync_AccRelOwnerChanger.FailureType.PERMANENT,
      AFFAsyncConsts.STATUS_FAILED
    )
};
*/

//================================================================================
//== EXECUTION STEPS
// - Uncomment and run these steps sequentially as needed.
//================================================================================

// STEP 0: Clean up all demo data and jobs from previous runs.
// AFF_DEMO_AFFAsync_AccRelOwnerChanger.cleanupData();

// STEP 1: Create fresh sample data for the test.
// AFF_DEMO_AFFAsync_AccRelOwnerChanger.setupSampleData( originalOwnerLogin );

// STEP 2: Start the ownership change jobs witsh the configured failure scenario.
AFF_DEMO_AFFAsync_AccRelOwnerChanger.startOwnershipChange( originalOwnerLogin, newOwnerLogin, failures );

// STEP 3: (Optional) After waiting for jobs to process, run automated validation.
// This is most useful for automated testing. For manual inspection, use the SOQL queries below.
// AFF_DEMO_AFFAsync_AccRelOwnerChanger.validateResults(failures, originalOwnerLogin, newOwnerLogin);


//================================================================================
//== USEFUL SOQL QUERIES
// - Run these in the Query Editor to inspect the state of the system after a test.
//================================================================================

/*
// -- Check Job Status --
// See the final status, direction, and any error details for all jobs in the test run.
SELECT Id, Status__c, Direction__c, Current_Step_Index__c, Final_Error_Details__c
FROM AFF_Job__c
WHERE Id IN ('a00ak000011HJaRAAW');

// -- Check Step Statuses --
// See the final status of each step within the jobs.
SELECT Id, AFF_Job__c, Step_Index__c, Status__c, Result__c
FROM AFF_Job_Step__c
WHERE AFF_Job__c IN :jobIds
ORDER BY AFF_Job__c, Step_Index__c;

// -- check Chunk status
SELECT Id, AFF_Job_Step__c, Chunk_Index__c, Status__c, Result__c
FROM AFF_Job_Step_Chunk__c

// -- Check Data Ownership --
// Verify the final owner of the data. Replace 'originalOwnerLogin' or 'newOwnerLogin'
// with the appropriate variable depending on the expected outcome of the test.
// AFF - 005ak00000A28qAAAR ; AFF2 - 005ak00000IAievAAD 

SELECT Id FROM User WHERE Username = 'alex.shekhter@gmail.com.aff' LIMIT 1
SELECT Id FROM User WHERE Username = 'alex.shekhter@gmail.com.aff2' LIMIT 1
SELECT COUNT(Id) FROM Account WHERE Name LIKE 'AFF Demo Account %' AND OwnerId = '005ak00000A28qAAAR';
SELECT COUNT(Id) FROM Contact WHERE Account.Name LIKE 'AFF Demo Account %' AND OwnerId = '005ak00000A28qAAAR';
SELECT COUNT(Id) FROM Opportunity WHERE Account.Name LIKE 'AFF Demo Account %' AND OwnerId = '005ak00000A28qAAAR';
SELECT COUNT(Id) FROM Task WHERE What.Name LIKE 'AFF Demo Account %' AND OwnerId = '005ak00000A28qAAAR';
*/

// class MyTestException extends Exception{}

// try {
//   insert new Account();
// }
// catch ( Exception ex ) {
//   MyTestException myex = new MyTestException( 'My TEST Exception to emulate cause', ex );
//   AFFError.SerializableError err = AFFError.marshal( myex );
//   System.debug( '--->>> err JSON: ' + err.serialize() );
//   System.debug( '--->>> err: ' + AFFError.parse( err.serialize() ) );
//   System.debug( '\n\n--->>> dml: ' + err.cause?.dmlErrors[ 0 ].statusMessage + ';\nfields:  ' + err.cause?.dmlErrors[ 0 ].fields + '\n\n'); 
// }
