/**
 * AFF  - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Demonstrates how to use AFFTestHelper framework part to achieve more structured
 * approach to test apex classes.
 */
@IsTest
public class AFFTestHelperTest {
  // Inner class representing the class to be tested
  public class ClassToTest {
    private List<Account> accs;

    // Constructor to initialize the list of accounts
    public ClassToTest(List<Account> accs) {
      this.accs = accs;
    }

    // Method to decorate account names with a given prefix
    public void decorateAccNames(String prefix) {
      for (Account a : accs) {
        a.Name = prefix + a.Name;
      }
    }

    // Method to save or update the list of accounts
    public void saveData() {
      upsert as user accs;
    }

    // Method to delete the list of accounts
    public void deleteData() {
      delete accs;
    }
  }

  // Inner class to compare accounts by name
  public virtual class AccountResultComparedByName extends AFFTestHelper.Result {
    // Constructor to initialize the result with an account
    public AccountResultComparedByName(Account acc) {
      super(Account.class, acc);
    }

    // Override equals method to compare accounts by name
    public override Boolean equals(object o) {
      if (this === o) {
        return true;
      }

      if ((o == null) || !(o instanceof AccountResultComparedByName)) {
        return false;
      }

      AccountResultComparedByName other = (AccountResultComparedByName) o;
      return (this.type.equals(other.type) &&
      ((Account) this.value).Name.equals(((Account) other.value).Name));
    }
  }

  // Test class for creating accounts and decorate their names
  public virtual class AccountNameDecoratorTest extends AFFTestHelper.BaseTest {
    protected String testName;
    protected ClassToTest testClass;

    // Constructor to initialize the test with necessary parameters
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public AccountNameDecoratorTest(
      String testName,
      List<Account> accs, // input
      List<AFFTestHelper.Result> results,
      String assertMsg
    ) {
      super(accs, results, assertMsg);
      this.testName = testName;
      this.testClass = new ClassToTest(accs);
    }

    // Method to run the test
    public virtual Object run() {
      testClass.decorateAccNames(testName);
      testClass.saveData();

      List<AccountResultComparedByName> ars = new List<AccountResultComparedByName>();
      for (Account a : [SELECT Id, Name FROM Account]) {
        ars.add(new AccountResultComparedByName(a));
      }

      return ars;
    }
  }

  private static final String DML_EXCEPTION_MSG = 'Test Exception caused by DML failure: ';

  // Test class to check how exceptions are handled during account creation
  public class AccountCreatorExceptionTest extends AFFTestHelper.BaseTest implements AFFTestHelper.ExceptionTest {
    protected String testName;
    protected ClassToTest testClass;

    // Constructor to initialize the exception test with necessary parameters
    @SuppressWarnings('PMD.ExcessiveParameterList')
    public AccountCreatorExceptionTest(
      String testName,
      List<Account> accs,
      AFFTestHelper.TestExceptionResult testEx,
      String assertMsg
    ) {
      super(accs, testEx, assertMsg);
      this.testClass = new ClassToTest(accs);
      this.testName = testName;
    }

    // Method to run the exception test
    public Object run() {
      testClass.saveData();
      return null;
    }

    // Method to wrap the exception in a TestException
    public virtual TestException getWrappingTestException(Exception e) {
      if (!(e instanceof DmlException)) {
        throw new IllegalArgumentException(
          'Expected DMLException here... got: ' + e
        );
      }
      return new TestException(DML_EXCEPTION_MSG, e);
    }
  }

  // Test method for a successful account creation scenario
  @IsTest
  @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
  public static void testAccountCreationWithDecorationHappyPath() {
    final String testName = 'Account decoration test with working DML_';
    final String postfix = 'Test';

    AFFTestHelper.Test test = new AccountNameDecoratorTest(
      testName,
      new List<Account>{ new Account(Name = postfix) },
      new List<AccountResultComparedByName>{
        new AccountResultComparedByName(new Account(Name = testName + postfix))
      },
      'Expected Account Name to start with \'' +
        testName +
        '\' and have postfix'
    );

    Object testRes = test.run();

    test.assert(testRes);
  }

  // Test method for a DML exception scenario
  @IsTest
  @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
  public static void testAccountDmlException() {
    final String testName = 'Account decoration test should fail';
    final String postfix = 'Test';

    AFFTestHelper.ExceptionTest test = new AccountCreatorExceptionTest(
      testName,
      new List<Account>{ new Account() }, // No mandatory field, so DML will fail
      new AFFTestHelper.TestExceptionResult(
        new AFFTestHelper.TestException(DML_EXCEPTION_MSG)
      ),
      'Expected DML exception wrapped inside AFFTestHelper.TestException...'
    );

    try {
      Object testRes = test.run();
      System.assert(false, 'We shouldn\'t be here. Expected DMLException');
    } catch (DmlException e) {
      test.assert(
        new AFFTestHelper.TestExceptionResult(test.getWrappingTestException(e))
      );
    }
  }

  // Test method demonstrating a declarative test example
  @IsTest
  @SuppressWarnings('PMD.ApexUnitTestClassShouldHaveAsserts')
  public static void declarativeTestExample() {
    AFFTestHelper.ExceptionTest testDmlException = new AccountCreatorExceptionTest(
      'DML exception test due to missed mandatory fields',
      new List<Account>{ new Account() }, // No mandatory field, so DML will fail
      new AFFTestHelper.TestExceptionResult(
        new AFFTestHelper.TestException(DML_EXCEPTION_MSG)
      ),
      'Expected DML exception wrapped inside AFFTestHelper.TestException...'
    );

    AFFTestHelper.Test testSaveDecoratedAccounts = new AccountNameDecoratorTest(
      'Test saving accounts with decorated names',
      new List<Account>{ new Account(Name = '123') },
      new List<AccountResultComparedByName>{
        new AccountResultComparedByName(
          new Account(
            Name = 'Test saving accounts with decorated names' + '123'
          )
        )
      },
      'Expected Account Name to start with \'Test saving accounts with decorated names\' and have postfix'
    );

    (new AFFTestHelper.BaseTestCollection())
      .run(
        new List<AFFTestHelper.Test>{
          testDmlException,
          testSaveDecoratedAccounts
        }
      );
  }
}
