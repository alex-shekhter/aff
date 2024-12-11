/**
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Test class for AFFSingleton
 */
@IsTest
public class AFFSingletonTest {
  /**
   * Test class to be used with AFFSingleton.
   * This class is a simple placeholder to test the singleton functionality.
   */
  public class TestSingleton {
    public String value;
  }

  /**
   * Test method for AFFSingleton.getInstance(Type type).
   * This method tests that the singleton instance is correctly created and retrieved by Type.
   */
  @IsTest
  static void testGetInstanceByType() {
    // Get the Type for TestSingleton
    Type testSingletonType = Type.forName('AFFSingletonTest.TestSingleton');

    // Get the singleton instance
    Object instance1 = AFFSingleton.getInstance(testSingletonType);

    // Assert that the instance is not null
    System.assertNotEquals(null, instance1, 'Instance should not be null');

    // Get the singleton instance again
    Object instance2 = AFFSingleton.getInstance(testSingletonType);

    // Assert that the same instance is returned
    System.assertEquals(
      instance1,
      instance2,
      'Both instances should be the same'
    );
  }
  
  /**
   * Test method for AFFSingleton.getInstance(String fqTypeName).
   * This method tests that the singleton instance is correctly created and retrieved by fully qualified type name.
   */
  @IsTest
  static void testGetInstanceByName() {
    // Fully qualified type name
    String fqTypeName = 'AFFSingletonTest.TestSingleton';

    // Get the singleton instance
    Object instance1 = AFFSingleton.getInstance(fqTypeName);

    // Assert that the instance is not null
    System.assertNotEquals(null, instance1, 'Instance should not be null');

    // Get the singleton instance again
    Object instance2 = AFFSingleton.getInstance(fqTypeName);

    // Assert that the same instance is returned
    System.assertEquals(
      instance1,
      instance2,
      'Both instances should be the same'
    );
  }
  /**
   * Test method for AFFSingleton.getInstance(String fqTypeName) with an invalid type name.
   * This method tests that a TypeException is thrown when an invalid type name is provided.
   */
  @IsTest
  static void testGetInstanceByNameInvalidType() {
    // Invalid fully qualified type name
    String invalidTypeName = 'InvalidTypeName';

    // Expect a TypeException to be thrown
    try {
      AFFSingleton.getInstance(invalidTypeName);
      System.assert(false, 'TypeException should have been thrown');
    } catch (TypeException e) {
      System.assert(true, 'TypeException was correctly thrown');
    }
  }
}
