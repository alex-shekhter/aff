/**
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Test class for AFF_DEMO_AccountTriggerHandler
 */
@isTest
public class AFF_DEMO_AccountTriggerHandlerTest {

  private static void setupFeatures() {
    List<AFFBase.Category> fatureDevNames = new List<AFFBase.Category>{
      AFF_DEMO_AccountTriggerHandler.FEATURE_ACCOUNT_REALTIME_LOGIC,
      AFF_DEMO_AccountTriggerHandler.FEATURE_AUTOASSIGN_ACC_OWNER,
      AFF_DEMO_AccountTriggerHandler.FEATURE_AUTOASSIGN_TASK_2_ACC,
      AFF_DEMO_AccountTriggerHandler.FEATURE_ACC_RATING
    };
    List<AFFFeatureCtrl.Feature> features = new List<AFFFeatureCtrl.Feature>();
    for ( AFFBase.Category fdn : fatureDevNames) {
      features.add( 
        new AFFFeatureCtrl.FeatureImpl(
          new AFF_Features_Control_Config__mdt(
            DeveloperName = fdn.name(),
            IsEnabled__c = true,
            FeatureDescription__c = fdn.name() + ' description'
          )
        )
      );
    }

    AFF_DEMO_AccountTriggerHandler.FEATURE_CFG.setFeatures(features);
  }

  /**
   * Test method to verify the behavior of the BeforeInsertExecutor.
   */
  @isTest
  static void testBeforeInsertExecutor() {
    setupFeatures();

    // Create test data
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'Test Account 1'),
      new Account(Name = 'Test Account 2')
    };
    // Insert the new accounts to trigger the before insert logic
    Test.startTest();
    insert newAccounts;
    Test.stopTest();
    // Verify the expected behavior
    for (Account acc : [
      SELECT Id, OwnerId
      FROM Account
      WHERE Id IN :newAccounts
    ]) {
      System.assertNotEquals(null, acc.OwnerId, 'Owner should be assigned');
    }
  }
  /**
   * Test method to verify the behavior of the AfterInsertExecutor.
   */
  @isTest
  static void testAfterInsertExecutor() {
    setupFeatures();

    // Create test data
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'Test Account 1'),
      new Account(Name = 'Test Account 2')
    };
    // Insert the new accounts to trigger the after insert logic
    Test.startTest();
    insert newAccounts;
    Test.stopTest();
    // Verify the expected behavior
    List<Task> tasks = [
      SELECT Id, WhatId
      FROM Task
      WHERE WhatId IN :newAccounts
    ];
    System.assertEquals(
      2,
      tasks.size(),
      'Two tasks should be created for the new accounts'
    );
  }
  /**
   * Test method to verify the behavior of the BeforeUpdateExecutor.
   */
  @isTest
  static void testBeforeUpdateExecutor() {
    setupFeatures();

    // Create test data
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'Test Account 1', AnnualRevenue = 1000),
      new Account(Name = 'Test Account 2', AnnualRevenue = 2000)
    };
    // Insert the new accounts
    insert newAccounts;
    // Verify the expected behavior
    for (Account acc : [
      SELECT Id, Type
      FROM Account
      WHERE Id IN :newAccounts
    ]) {
      System.assertNotEquals('Cold', acc.Type, 'Rating should be Cold');
    }
    // Update the accounts to trigger the before update logic
    for (Account acc : newAccounts) {
      acc.AnnualRevenue += 500000;
    }
    Test.startTest();
    update newAccounts;
    Test.stopTest();
    // Verify the expected behavior
    for (Account acc : [
      SELECT Id, Type, AnnualRevenue
      FROM Account
      WHERE Id IN :newAccounts
    ]) {
      System.Assert.areEqual(
        'Warm',
        acc.Type,
        'Rating (Type) should be updated from Cold to Warm'
      );
    }
  }
  /**
   * Test method to verify the overall trigger handler execution.
   */
  @isTest
  static void testTriggerHandlerInsertExecution() {
    setupFeatures();

    // Create test data
    List<Account> newAccounts = new List<Account>{
      new Account(Name = 'Test Account 1'),
      new Account(Name = 'Test Account 2')
    };
    // Insert the new accounts to trigger the handler
    Test.startTest();
    insert newAccounts;
    Test.stopTest();
    // Verify the expected behavior
    for (Account acc : [
      SELECT Id, OwnerId, Type
      FROM Account
      WHERE Id IN :newAccounts
    ]) {
      System.assertNotEquals(null, acc.OwnerId, 'Owner should be assigned');
      System.assertNotEquals('Cold', acc.Type, 'Rating should be Cold');
    }
    List<Task> tasks = [
      SELECT Id, WhatId
      FROM Task
      WHERE WhatId IN :newAccounts
    ];
    System.assertEquals(
      2,
      tasks.size(),
      'Two tasks should be created for the new accounts'
    );
  }
}
