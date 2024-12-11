/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFCommons.
 *
 */
@IsTest
public class AFFCommonsTest {
  /**
   * Tests the HashBuilder to ensure it correctly calculates hash codes for various inputs.
   */
  @isTest
  public static void testHashBuilder() {
    Test.startTest();

    // Create a new instance of HashBuilder
    AFFCommons.HashBuilder hb = new AFFCommons.HashBuilder();

    // Add null and check the hash code
    System.assertEquals(
      31 * 7 + 0,
      hb.add(null).hashCode(),
      'Expected result 31 * 7 + 0'
    );

    // Add an empty string and check the hash code
    System.assertEquals(
      31 * hb.hashCode() + ''.hashCode(),
      hb.add('').hashCode(),
      'Expected result ' + (31 * hb.hashCode() + ''.hashCode())
    );

    // Add a non-empty string and check the hash code
    System.assertEquals(
      31 * hb.hashCode() + 'a'.hashCode(),
      hb.add('a').hashCode(),
      'Expected result' + (31 * hb.hashCode() + 'a'.hashCode())
    );

    // Ensure chaining works
    System.assertEquals(
      31 * (31 * 7 + 'a'.hashCode()) + 0,
      (new AFFCommons.HashBuilder()).add('a').add(null).hashCode(),
      'Expected result' + (31 * (31 * 7 + 'a'.hashCode()) + 0)
    );

    Test.stopTest();
  }

  /**
   * Test AFFCommons.HashBuilderCached to ensure it correctly calculates hash codes for various inputs.
   */
  @isTest
  public static void testHashBuilderCached() {
    List<String> strs = new List<String>{ 'a', 'b', null, '', 'c' };

    Test.startTest();
    AFFCommons.HashBuilderCached hbc = new AFFCommons.HashBuilderCached();
    for (String s : strs) {
      hbc.add(s);
    }
    Integer expectedHash = (new AFFCommons.HashBuilder())
      .add(strs[0])
      .add(strs[1])
      .add(strs[2])
      .add(strs[3])
      .add(strs[4])
      .hashCode();

    System.assert(
      hbc.hashCode() == expectedHash,
      'Expected result ' + expectedHash + 'got' + hbc.hashCode()
    );

    // Test clear
    hbc.clear();
    System.assert(hbc.hashCode() == 7, 'Expected result' + 0);

    System.assert(
      hbc.clear().add(strs[0]).hashCode() ==
      (new AFFCommons.HashBuilder()).add(strs[0]).hashCode(),
      'Expected result ' +
        (new AFFCommons.HashBuilder()).add(strs[0]).hashCode() +
        ' got ' +
        hbc.hashCode()
    );
    Test.stopTest();
  }

  public class MyTestApexClass {
    private Integer i = 0;
  }

  /**
   * Test getTypeForApexObject method to ensure it correctly
   * returns the type of an Apex objec
   */
  @isTest
  public static void testGetTypeForApexObjectSunny() {
    Test.startTest();

    Type resType = AFFCommons.getTypeForApexObject(
      'AFFCommonsTest',
      new AFFCommonsTest.MyTestApexClass()
    );

    Type trgType = Type.forName('AFFCommonsTest.MyTestApexClass');

    System.assert(
      resType == trgType,
      'Expected result:  ' + trgType + ' got: ' + resType
    );

    Test.stopTest();
  }

  /**
   * Test getTypeForApexObject method exceptions
   */
  @isTest
  public static void testGetTypeForApexObjectFailures() {
    Test.startTest();

    // Check for null
    try {
      AFFCommons.getTypeForApexObject(null, null);
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().startsWith('Object cannot be null'),
        'Expected message start with: "Object cannot be null"' +
          ' got: ' +
          e.getMessage()
      );
    }

    // check wrong object type
    try {
      AFFCommons.getTypeForApexObject('ass', 'tttt');
      System.assert(false, 'Should throw exception');
    } catch (IllegalArgumentException e) {
      System.assert(
        e.getMessage().startsWith('Invalid object type'),
        'Expected message start with: "Invalid object type"' +
          ' got:' +
          e.getMessage()
      );
    }
    Test.stopTest();
  }

  /**
   * Test getObjectType method
   */
  @isTest
  private static void testGetObjectType() {
    Date d = Date.today();
    String ot = AFFCommons.getObjectType(d);
    System.assertEquals('DateTime', ot, '');

    ot = AFFCommons.getObjectType(
      new Map<AFFBase.SimpleCategoryImpl, Map<Schema.DescribeFieldResult, List<Integer>>>()
    );
    System.assertEquals(
      'Map<AFFBase.SimpleCategoryImpl,Map<Schema.DescribeFieldResult,List<Integer>>>',
      ot,
      ''
    );
  }

  /**
   * Implementation of the AFFCommons.Cloneable interface
   */
  private class CloneableImpl implements AFFCommons.Cloneable {
    public String name { get; set; }

    public CloneableImpl(String name) {
      this.name = name;
    }

    public Object clone(Boolean deepClone) {
      return new CloneableImpl(this.name);
    }
  }

  @isTest
  private static void testDeepClone() {
    // test null
    System.Assert.areEqual(null, AFFCommons.deepClone(null), 'Null');

    // Test primitive types
    String str = 'ABC';
    String clonedStr = (String)AFFCommons.deepClone(str);
    System.Assert.areEqual(str, clonedStr, 'Cloned string');
    str = 'DEF';
    System.Assert.areNotEqual(str, clonedStr, 'Cloned string');

    // test SObject
    Account acc = new Account(Name = 'Acc1');
    Account clonedAcc = (Account) AFFCommons.deepClone(acc);
    System.Assert.areEqual(acc.Name, clonedAcc.Name, 'Name');
    acc.Name = 'Changed Acc1';
    System.Assert.areNotEqual(acc.Name, clonedAcc.Name, 'Name');
    System.Assert.areEqual('Acc1', clonedAcc.Name, 'Name');

    //test Cloneable
    CloneableImpl ci = new CloneableImpl('ABC');
    CloneableImpl clonedCi = (CloneableImpl) AFFCommons.deepClone(ci);
    System.Assert.areEqual(ci.name, clonedCi.name, 'Name');
    ci.name = 'Changed ABC';
    System.Assert.areNotEqual(ci.name, clonedCi.name, 'Name');
    System.Assert.areEqual('ABC', clonedCi.name, 'Name');

    // Test something unknown
    Map<String, Account> accsByName = new Map<String, Account>{
      'Acc1' => new Account(Name = 'Acc1')
    };

    Map<String, Account> clonedMap = (Map<String, Account>) AFFCommons.deepClone(
      accsByName
    );

    System.assertEquals(clonedMap.size(), accsByName.size(), 'Map Size');
    System.assertEquals(
      'Acc1',
      new List<String>(clonedMap.keySet())[0],
      'Map Key'
    );
    System.assertEquals(
      new Account(Name = 'Acc1'),
      new List<Account>(clonedMap.values())[0],
      'Map Values'
    );
  }
}
