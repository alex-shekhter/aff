/**
 * AFF  - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Classes which are used in tests to facilitate more declarative testing
 */
@SuppressWarnings('PMD.CognitiveComplexity')
@IsTest
public class AFFTestHelper {
  /**
   * Result - class represents result of the test run.
   * This class can be used to simplify and standardize test creation, but it is not mandatory.
   */
  // TODO: Add assert message to result???
  public virtual class Result {
    // Type property holds the type of the result value.
    public Type type { get; set; }
    // Value property holds the actual result value.
    public Object value { get; set; }

    /**
     * Constructor for Result class.
     * @param type The type of the result value.
     * @param value The actual result value.
     */
    public Result(Type type, Object value) {
      this.type = type;
      this.value = value;
    }

    /**
     * This method is used to compare the actual result value with the expected result value.
     * @param o The object to compare with.
     * @return True if the objects are equal, false otherwise.
     */
    public virtual Boolean equals(Object o) {
      if (this === o) {
        return true;
      }

      if ((o == null) || !(o instanceof Result)) {
        return false;
      }

      Result other = (Result) o;
      return (this.type.equals(other.type) && this.value.equals(other.value));
    }

    /**
     * Method to generate a hash code for the Result object.
     * @return The hash code of the Result object.
     */
    public virtual Integer hashCode() {
      return new AFFCommons.HashBuilder().add(type).add(value).hashCode();
    }
  }

  /**
   * Test interface.
   * This defines a method to assert test results and
   * check if an exception occurred during the test.
   */
  public interface Test {
    void assert(Object result);
    Object run();
  }

  /*
   * ExceptionTest - Interface extending the Test interface.
   * 
   * Rationale:
   * In Salesforce Apex, it is not possible to programmatically create standard exceptions 
   * that behave exactly like real exceptions during testing. To work around this limitation, 
   * we use the ExceptionTest interface to wrap real exceptions or their naive implementations 
   * inside a TestException. This wrapper allows us to assert the results effectively during tests.
   * 
   * Method:
   * - getWrappingTestException(Exception e): Wraps the given exception in a TestException.
   */  
  public interface ExceptionTest extends Test {
    TestException getWrappingTestException(Exception e);
  }

  /**
   * TestExceptionResult - class represents result of the test run with exception.
   * This class can be used to simplify and standardize test creation, but it is not mandatory.
   */
  public virtual class TestExceptionResult extends Result {
    public TestExceptionResult(TestException e) {
      super(TestException.class, e);
    }

    // Compare Exceptions by type and by message (start with, not equals)
    public override Boolean equals(object o) {
      if (this === o) {
        return true;
      }

      if ((o == null) || !(o instanceof TestExceptionResult)) {
        return false;
      }

      TestExceptionResult other = (TestExceptionResult) o;
      final String currMsg = ((TestException) value).getMessage();
      final String otherMsg = ((TestException) other.value).getMessage();

      return this.type.equals(other.type) && otherMsg.startsWith(currMsg);
    }
  }

  // Static final String constant representing the expected type of results in tests.
  static public final String BASE_TEST_PARAM_MSG = 'Expected Results and Results should have type of AFFTestHelper.Result or List<AFFTestHelper.Result>. Please rewrite your test accordingly';

  public inherited sharing class TestException extends Exception {
  }

  /**
   * BaseTest - abstract class implementing base Test functionality.
   *
   * This class assumes that AFFTestHelper.Result is used.
   */
  public abstract class BaseTest implements Test {
    //
    // Properties have Object type, not AFFTestHelper.Result
    // since we do not want to limit ourself
    // with single result or list of the results.
    //
    // TODO: It might be better to have 2 classes one for single Result,
    //       another for List<AFFTestHelper.Result>
    //

    // Property to hold the data for the test.
    protected Object data { get; set; }
    // Property to hold the expected result of the test.
    protected Object expectedResult { get; set; }
    // Property to hold a message used in assertions.
    protected String assertMsg { get; set; }

    /**
     * Constructor for BaseTest class.
     * @param data The data for the test.
     * @param expectedResult The expected result of the test.
     * @param assertMsg A message to use in assertions.
     */
    public BaseTest(Object data, Object expectedResult, String assertMsg) {
      this.data = data;
      if (
        !(expectedResult instanceof Result) &&
        !(expectedResult instanceof List<Result>)
      ) {
        throw new TestException(BASE_TEST_PARAM_MSG);
      }
      this.expectedResult = expectedResult;
      this.assertMsg = assertMsg;
      if (String.isBlank(this.assertMsg)) {
        this.assertMsg = 'Result is not expected';
      }
    }

    // Helper method to compose a message for assertions.
    protected virtual String composeMsg(String auxMsg) {
      return assertMsg + ': ' + auxMsg + ' ';
    }

    /**
     * Method to assert the result of the test.
     * @param results The results to assert, expected to be either a
     * Result or a List<Result>.
     */
    public virtual void assert(Object results) {
      if (results instanceof Result) {
        System.assertEquals(
          results,
          expectedResult,
          composeMsg(
            ' DATA: ' + results + '; EXP RES: ' + expectedResult + '; '
          )
        );
      } else if (results instanceof List<Result>) {
        List<Result> expectedArr = (List<Result>) expectedResult;
        List<Result> resultsArr = (List<Result>) results;
        Integer sz = resultsArr?.size();
        System.assertEquals(
          sz,
          expectedArr.size(),
          composeMsg(
            'Expect Array size: ' + sz + '; Got ' + expectedArr.size() + '; '
          )
        );
        for (Integer i = 0; i < sz; i++) {
          System.assertEquals(
            resultsArr[i],
            expectedArr[i],
            composeMsg(
              'res#' +
                i +
                ' DATA: ' +
                results +
                '; EXP RES: ' +
                expectedResult +
                '; '
            )
          );
        }
      } else {
        throw new TestException(BASE_TEST_PARAM_MSG + ' ' + results);
      }
    }
  }

  /**
   * ExceptionTest - abstract class extending BaseTest for exception handling tests.
   */
  public abstract class ExceptionTestAbs extends BaseTest implements ExceptionTest {
    public ExceptionTestAbs(
      Object data,
      Object expectedResult,
      String assertMsg
    ) {
      super(data, expectedResult, assertMsg);
    }

    public virtual TestException getWrappingTestException(Exception e) {
      return new TestException('Test Exception caused by: ', e);
    }
  }

  /**
   * TestCollection interface for running a collection of tests.
   */
  public interface TestCollection {
    void run(List<Test> tests);
  }

  /**
   * BaseTestCollection - represents a collection of tests and implements the TestCollection interface.
   */
  public virtual class BaseTestCollection implements TestCollection {
    /**
     * Method to run a list of tests.
     * @param tests The list of tests to be executed.
     */
    public virtual void run(List<Test> tests) {
      System.Test.startTest();
      for (Test tst : tests) {
        try {
          Object res = tst.run();
          if (!(tst instanceof ExceptionTest)) {
            tst.assert(res);
          }
        } catch (Exception e) {
          if (tst instanceof ExceptionTest) {
            TestExceptionResult r = new TestExceptionResult(
              ((ExceptionTest) tst).getWrappingTestException(e)
            );
            tst.assert(r);
          } else {
            throw e;
          }
        }
      }
      System.Test.stopTest();
    }
  }
}
