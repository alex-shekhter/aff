@IsTest
public class AFFTriggerTest {
  // Copied here to reduce dependencies
  private class TestExecutor implements AFFBase.Executor {
    public Integer value { get; set; }

    public TestExecutor() {
      value = -1;
    }

    public TestExecutor(final Integer v) {
      value = v;
    }

    public void execute() {
      value++;
    }
  }

  @isTest
  public static void testTriggerCategory() {
    System.Test.startTest();
    // We are not testing for Governor limits here...
    System.Test.stopTest();

    AFFTrigger.TriggerCategory tc1 = AFFTrigger.AFTER_INS_TRG;
    AFFTrigger.TriggerCategory tc2 = new AFFTrigger.TriggerCategory(
      AFFTrigger.TriggerType.AFTER_INS
    );
    AFFTrigger.TriggerCategory tc3 = new AFFTrigger.TriggerCategory(
      AFFTrigger.TriggerType.BEFORE_INS
    );
    AFFTrigger.TriggerCategory tcNull = null;

    System.assert(tc1 == tc2, 'Expected tc1 == tc2');
    System.assert(
      tc1.hashCode() == tc2.hashcode(),
      'Expected tc1.hashcode() (' +
        tc1.hashCode() +
        ') == tc2.hashcode() (' +
        tc2.hashCode() +
        ')'
    );

    System.assert(tc1 != tc3, 'Expected tc1 !- tc3');
    System.assert(
      tc1.hashCode() != tc3.hashcode(),
      'Expected tc1.hashcode() (' +
        tc1.hashCode() +
        ') == tc3.hashcode() (' +
        tc3.hashCode() +
        ')'
    );

    System.assert(tc1 != tcNull, 'Expected tc1!= null');
  }

  @isTest
  public static void testGenericCategoryForTrigger() {
    System.Test.startTest();
    AFFBase.SimpleCategoryImpl genCat = new AFFBase.SimpleCategoryImpl(
      'Generic'
    );
    AFFTrigger.TriggerExecutionManager tem = new AFFTrigger.TriggerExecutionManager();
    try {
      tem.addExecutor(genCat, new TestExecutor());
      System.assert(false, 'Something is wrong with the test...');
    } catch (AFFTrigger.WrongTriggerCategoryException e) {
      System.assert(true, '');
    }
    System.Test.stopTest();
  }
}
