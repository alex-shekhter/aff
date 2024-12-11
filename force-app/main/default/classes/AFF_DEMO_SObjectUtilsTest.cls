/**
 * AFF - Apex foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Tests for AFF_DEMO_SObjectUtils class
 */
@isTest
public class AFF_DEMO_SObjectUtilsTest {
  /**
   * Test class for SObjNoOwnerCondition
   */
  @isTest
  private static void testSObjNoOwnerCondition() {
    // Create an instance of the condition
    AFF_DEMO_SObjectUtils.SObjNoOwnerCondition condition = new AFF_DEMO_SObjectUtils.SObjNoOwnerCondition();

    // Test with an SObject that has no owner
    SObject objWithoutOwner = new Account();
    System.assert(
      condition.test(objWithoutOwner),
      'Condition should return true for SObject without owner'
    );

    // Test with an SObject that has an owner
    SObject objWithOwner = new Account(OwnerId = UserInfo.getUserId());
    System.assert(
      !condition.test(objWithOwner),
      'Condition should return false for SObject with owner'
    );

    // Test with null
    System.assert(
      !condition.test(null),
      'Condition should return false for null object'
    );
  }

  /**
   * Test class for SObjOwnerSetter_1
   */
  @isTest
  private static void testSObjOwnerSetter_1() {
    // Create a list of SObjects
    List<SObject> sObjects = new List<SObject>{
      new Account(),
      new Account(OwnerId = UserInfo.getUserId())
    };

    // Create an instance of the executor with the current user as owner
    AFF_DEMO_SObjectUtils.SObjOwnerSetter_1 executor = new AFF_DEMO_SObjectUtils.SObjOwnerSetter_1(
      sObjects
    );

    // Execute the task
    executor.execute();

    // Verify that the owner was set for the SObject without an owner
    System.assertEquals(
      UserInfo.getUserId(),
      sObjects[0].get('OwnerId'),
      'Owner should be set to current user'
    );

    // Verify that the owner was not changed for the SObject with an owner
    System.assertEquals(
      UserInfo.getUserId(),
      sObjects[1].get('OwnerId'),
      'Owner should remain unchanged'
    );
  }

  /**
   * Test class for SObjOwnerSetter_2
   */
  @isTest
  private static void testSObjOwnerSetter_2() {
    // Create an SObject without an owner
    SObject objWithoutOwner = new Account();

    // Create an instance of the executor with the current user as owner
    AFF_DEMO_SObjectUtils.SObjOwnerSetter_2 executor = new AFF_DEMO_SObjectUtils.SObjOwnerSetter_2();

    // Set the data to be processed
    executor.setData(objWithoutOwner);

    // Execute the task
    executor.execute();

    // Verify that the owner was set for the SObject
    System.assertEquals(
      UserInfo.getUserId(),
      ((SObject) executor.getData()).get('OwnerId'),
      'Owner should be set to current user'
    );

    // Create an SObject with an owner
    SObject objWithOwner = new Account(OwnerId = UserInfo.getUserId());

    // Set the data to be processed
    executor.setData(objWithOwner);

    // Execute the task
    executor.execute();

    // Verify that the owner was not changed for the SObject
    System.assertEquals(
      UserInfo.getUserId(),
      ((SObject) executor.getData()).get('OwnerId'),
      'Owner should remain unchanged'
    );
  }
}
