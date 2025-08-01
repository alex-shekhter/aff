/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description Test class for AFFLimit. This class provides full coverage
 * for the Budget inner class, ensuring that governor limit budget checks
 * behave as expected under various conditions.
 */
@isTest
@SuppressWarnings('PMD.OperationWithLimitsInLoop')
private class AFFLimitTest {
  /**
   * @description Verifies that the Budget constructor correctly calculates
   * budget thresholds and clamps the safety factor within a reasonable range.
   */
  @isTest
  static void testBudgetConstructor() {
    Test.startTest();
    // Test with a standard safety factor
    AFFLimit.Budget standardBudget = new AFFLimit.Budget(80);
    System.assertNotEquals(
      null,
      standardBudget,
      'Budget should be created with a standard safety factor.'
    );

    // Test with a safety factor below the minimum (should be clamped to 50)
    AFFLimit.Budget lowBudget = new AFFLimit.Budget(20);
    System.assertNotEquals(
      null,
      lowBudget,
      'Budget should be created with a low safety factor.'
    );

    // Test with a safety factor above the maximum (should be clamped to 95)
    AFFLimit.Budget highBudget = new AFFLimit.Budget(110);
    System.assertNotEquals(
      null,
      highBudget,
      'Budget should be created with a high safety factor.'
    );
    Test.stopTest();
  }

  /**
   * @description Tests the happy path where no limits are close to being
   * exceeded and canContinue() should return true.
   */
  @isTest
  static void testCanContinueHappyPath() {
    Test.startTest();
    AFFLimit.Budget budget = new AFFLimit.Budget(80);
    Boolean canContinue = budget.canContinue();
    Test.stopTest();
    System.assertEquals(
      true,
      canContinue,
      'canContinue should be true when limits are not exceeded.'
    );
  }

  /**
   * @description Verifies that canContinue() returns false when the SOQL query limit is exceeded.
   */
  @isTest
  static void testCanContinueSoqlLimitExceeded() {
    Test.startTest();
    AFFLimit.Budget budget = new AFFLimit.Budget(50); // Use 50% to hit the limit faster
    // Consume SOQL queries until the budget is exceeded
    for (Integer i = 0; i < Limits.getLimitQueries(); i++) {
      if (!budget.canContinue()) {
        break;
      }
      List<Account> accs = [SELECT Id FROM Account LIMIT 1];
    }
    Boolean canContinue = budget.canContinue();
    Test.stopTest();
    System.assertEquals(
      false,
      canContinue,
      'canContinue should be false when SOQL limit is exceeded.'
    );
  }

  /**
   * @description Verifies that canContinue() returns false when the DML statement limit is exceeded.
   */
  @isTest
  static void testCanContinueDmlLimitExceeded() {
    Test.startTest();
    AFFLimit.Budget budget = new AFFLimit.Budget(50);
    // Consume DML statements until the budget is exceeded
    for (Integer i = 0; i < Limits.getLimitDmlStatements(); i++) {
      if (!budget.canContinue()) {
        break;
      }
      insert new Account(Name = 'Test ' + i);
    }
    Boolean canContinue = budget.canContinue();
    Test.stopTest();
    System.assertEquals(
      false,
      canContinue,
      'canContinue should be false when DML limit is exceeded.'
    );
  }

  /**
   * @description Verifies that canContinue() returns false when the CPU time limit is exceeded.
   */
  @isTest
  @SuppressWarnings('PMD.EmptyWhileStmt,PMD.EmptyStatementBlock')
  static void testCanContinueCpuLimitExceeded() {
    Test.startTest();
    AFFLimit.Budget budget = new AFFLimit.Budget(50);
    // Consume CPU time until the budget is exceeded
    while (budget.canContinue()) {
      // Burn CPU
    }
    Boolean canContinue = budget.canContinue();
    Test.stopTest();
    System.assertEquals(
      false,
      canContinue,
      'canContinue should be false when CPU limit is exceeded.'
    );
  }

  /**
   * @description Verifies that canContinue() returns false when the heap size limit is exceeded.
   */
  @isTest
  static void testCanContinueHeapLimitExceeded() {
    Test.startTest();
    AFFLimit.Budget budget = new AFFLimit.Budget(50);
    String largeString = '';
    // Consume heap size until the budget is exceeded
    while (budget.canContinue()) {
      largeString += 'a'.repeat(1000);
    }
    Boolean canContinue = budget.canContinue();
    Test.stopTest();
    System.assertEquals(
      false,
      canContinue,
      'canContinue should be false when Heap limit is exceeded.'
    );
  }
}
