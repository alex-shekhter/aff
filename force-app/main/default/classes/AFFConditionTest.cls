/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Tests for the AFFCondition class.
 */
@IsTest
public class AFFConditionTest {
  /**
   * Class implemnts AFFCondition.ObjCondition interface.
   *
   * A simple example of a class that could be used as a predicate to test an object.
   */
  public class RevenueCondition implements AFFCondition.ObjCondition {
    private Decimal threshold;

    /**
     * Constructor
     * @param threshold The threshold value for the condition.
     */
    public RevenueCondition(Decimal threshold) {
      this.threshold = threshold;
    }

    /**
     * Tests the condition.
     * @param o The object to test.
     * @return true if the object satisfies the condition, false otherwise.
     */
    public Boolean test(Object o) {
      if (o instanceof Account) {
        Account acc = (Account) o;
        return acc.AnnualRevenue > threshold;
      }
      return false;
    }
  }

  /**
   * Tests the ObjCondition interface.
   */
  @IsTest
  public static void testObjCondition() {
    Test.startTest();
    // Usage
    Account acc = new Account(Name = 'Test Account', AnnualRevenue = 500000);
    AFFCondition.ObjCondition revenueCondition = new RevenueCondition(300000);
    Boolean result = revenueCondition.test(acc);
    System.assert(result, 'Expected the condition to be true');

    acc = new Account(Name = 'Test Account', AnnualRevenue = 100000);
    result = revenueCondition.test(acc);
    System.Assert(!result, 'Expected the condition to be false');
    Test.stopTest();
  }

  /**
   * Class implemnts AFFCondition.InstCondition interface.
   *
   * A simple example of a class that could be used as a predicate to test an instance.
   */
  public class RecentlyUpdatedAccountCondition implements AFFCondition.InstCondition {
    private Account instance;

    /**
     * Sets the instance.
     * @param o The instance to set.
     */
    public AFFBase.DataSetter setData(Object o) {
      if (o instanceof Account) {
        this.instance = (Account) o;
      }
      return this;
    }

    /**
     * Tests the condition.
     * @return true if the object satisfies the condition, false otherwise.
     */
    public Boolean test() {
      if (instance == null) {
        return false;
      }
      Date today = Date.today();
      return instance.LastModifiedDate != null &&
        instance.LastModifiedDate.addDays(30) >= today;
    }
  }

  /**
   * Tests the InstCondition interface.
   */
  @IsTest
  private static void testInstCondition() {
    Account acc = new Account(Name = 'Test Account', AnnualRevenue = 500000);
    insert as system acc;
    List<Account> accs = [SELECT Id, Name, LastModifiedDate FROM Account];

    Test.startTest();
    RecentlyUpdatedAccountCondition condition = new RecentlyUpdatedAccountCondition();
    condition.setData(accs[0]);
    Boolean result = condition.test(); // Should return true if updated within last 30 days
    Test.stopTest();

    System.assert(result, 'Expected the condition to be true: ' + acc);
  }
}
