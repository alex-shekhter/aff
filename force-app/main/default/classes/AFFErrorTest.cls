/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description Test class for AFFError. This class provides full coverage
 * for the error marshalling and parsing logic, including various exception
 * types and corner cases.
 */
@isTest
private class AFFErrorTest {
  /**
   * @description Custom exception class to test the marshalling of exception causes.
   */
  private class TestExceptionWithCauseException extends Exception {
  }

  /**
   * @description Verifies that marshalling a null exception returns null.
   */
  @isTest
  static void testMarshalNullException() {
    Test.startTest();
    AFFError.SerializableError result = AFFError.marshal(null);
    Test.stopTest();
    System.assertEquals(
      null,
      result,
      'Marshalling a null exception should result in null.'
    );
  }

  /**
   * @description Tests marshalling a standard Exception, verifying that
   * basic details like message and type are captured.
   */
  @isTest
  static void testMarshalSimpleException() {
    Exception ex = new TestExceptionWithCauseException('Simple test error');
    Test.startTest();
    AFFError.SerializableError result = AFFError.marshal(ex);
    Test.stopTest();

    System.assertNotEquals(
      null,
      result,
      'Result should not be null for a valid exception.'
    );
    System.assertEquals(
      'AFFErrorTest.TestExceptionWithCauseException',
      result.type,
      'Exception type should be captured correctly.'
    );
    System.assertEquals(
      'Simple test error',
      result.message,
      'Exception message should be captured correctly.'
    );
    System.assert(
      String.isNotBlank(result.stackTrace),
      'Stack trace should not be blank.'
    );
    System.assertEquals(
      null,
      result.cause,
      'A simple exception should have no cause.'
    );
  }

  /**
   * @description Verifies that the cause of an exception is recursively marshalled.
   */
  @isTest
  static void testMarshalExceptionWithCause() {
    // Generate a real DML exception by forcing a database error.
    DmlException cause = null;
    try {
      insert new Account(Name = 'a'.repeat(256));
    } catch (DmlException e) {
      cause = e;
    }

    Exception ex = new TestExceptionWithCauseException('Outer exception.');
    ex.initCause(cause);

    Test.startTest();
    AFFError.SerializableError result = AFFError.marshal(ex);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null.');
    System.assertNotEquals(
      null,
      result.cause,
      'The cause should have been marshalled.'
    );
    System.assertEquals(
      'System.DmlException',
      result.cause.type,
      'The cause exception type should be correct.'
    );
    System.assert(
      result.cause.message.contains('STRING_TOO_LONG'),
      'The cause exception message should be correct.'
    );
  }

  /**
   * @description Tests the specific handling of DmlException to ensure
   * detailed error information is extracted correctly.
   */
  @isTest
  static void testMarshalDmlException() {
    DmlException dmlEx;
    try {
      // Force a DML exception with a known error
      insert new Account(Name = 'a'.repeat(256));
    } catch (DmlException e) {
      dmlEx = e;
    }

    Test.startTest();
    AFFError.SerializableError result = AFFError.marshal(dmlEx);
    Test.stopTest();

    System.assertNotEquals(null, result, 'Result should not be null.');
    System.assertEquals(
      'System.DmlException',
      result.type,
      'Exception type should be DmlException.'
    );
    System.assertNotEquals(
      null,
      result.dmlErrors,
      'DML errors list should be populated.'
    );
    System.assertEquals(
      1,
      result.dmlErrors.size(),
      'There should be one DML error.'
    );

    AFFError.DmlError detail = result.dmlErrors[0];
    System.assertEquals(0, detail.recordIndex, 'Record index should be 0.');
    System.assert(
      detail.statusMessage.contains('Name: data value too large'),
      'Status message should contain the field error.'
    );
    System.assertEquals(
      'STRING_TOO_LONG',
      detail.statusCode,
      'Status code should be correct.'
    );
    System.assert(
      detail.fields.contains('Name'),
      'Fields list should contain the problematic field.'
    );
  }

  /**
   * @description Verifies that a marshalled error can be serialized to a JSON
   * string and then parsed back into an equivalent object.
   */
  @isTest
  static void testSerializeAndParse() {
    Exception ex = new TestExceptionWithCauseException(
      'Test for serialization'
    );
    AFFError.SerializableError originalError = AFFError.marshal(ex);

    Test.startTest();
    String jsonString = originalError.serialize();
    AFFError.SerializableError parsedError = AFFError.parse(jsonString);
    Test.stopTest();

    System.assert(
      String.isNotBlank(jsonString),
      'Serialized JSON string should not be blank.'
    );
    System.assertNotEquals(
      null,
      parsedError,
      'Parsed error should not be null.'
    );
    System.assertEquals(
      originalError.type,
      parsedError.type,
      'Parsed type should match original.'
    );
    System.assertEquals(
      originalError.message,
      parsedError.message,
      'Parsed message should match original.'
    );
  }
}
