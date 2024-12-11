@isTest
private class AFFIterTest {
  /**
   * Test the use of AFFIter.ListIterator to iterate over a list
   */
  @isTest
  static void testListIteratorWithNullList() {
    Test.startTest();
    AFFIter.Iterator it = new AFFIter.ListIterator(null);

    System.assertEquals(false, it.hasNext(), '1st hasNext');
    System.assertEquals(null, it.next(), '1st next');
    Test.stopTest();
  }

  /**
   * Test the use of AFFIter.ListIterator to iterate over an empty list
   */
  @isTest
  static void testListIteratorWithEmptyList() {
    Test.startTest();
    AFFIter.Iterator it = new AFFIter.ListIterator(new List<String>());

    System.assertEquals(false, it.hasNext(), '1st hasNext');
    System.assertEquals(null, it.next(), '1st next');
    Test.stopTest();
  }

  /**
   * Test the use of AFFIter.ListIterator to iterate over a list
   */
  @isTest
  static void testListIteratorWithListWithData() {
    Test.startTest();
    List<String> testList = new List<String>{ 'A', 'B', 'C' };
    AFFIter.Iterator it = new AFFIter.ListIterator(testList);

    System.assertEquals(true, it.hasNext(), '1st hasNext');
    System.assertEquals('A', it.next(), '1st next');
    System.assertEquals('B', it.next(), '2d next');
    System.assertEquals('C', it.next(), '3d next');
    System.assertEquals(
      false,
      it.hasNext(),
      'Last hasNext at the end of collection'
    );
    System.assertEquals(null, it.next(), 'Last next after last element');
    Test.stopTest();
  }

  /**
   * Test the use of AFFIter.ListIterator.getCurrIndex()
   */
  @isTest
  static void testGetCurrIndex() {
    Test.startTest();
    List<String> testList = null;
    AFFIter.Iterator it = new AFFIter.ListIterator(testList);
    System.assertEquals(-1, it.getCurrIndex(), 'Iterator:' + it);
    testList = new List<String>();
    it = new AFFIter.ListIterator(testList);
    System.assertEquals(-1, it.getCurrIndex(), 'Iterator:' + it);
    it = new AFFIter.ListIterator(testList);
    System.assertEquals(-1, it.getCurrIndex(), 'Iterator:' + it);
    it.next();
    it.next();
    System.assertEquals(-1, it.getCurrIndex(), 'Iterator:' + it);
    testList = new List<String>{ 'A', 'B', 'C' };
    it = new AFFIter.ListIterator(testList);
    System.assertEquals(0, it.getCurrIndex(), 'Iterator:' + it);
    it.next();
    System.Assert.areEqual(1, it.getCurrIndex(), 'Iterator:' + it);
    it.next();
    System.Assert.areEqual(2, it.getCurrIndex(), 'Iterator:' + it);
    it.next();
    System.Assert.areEqual(3, it.getCurrIndex(), 'Iterator:' + it);
    Test.stopTest();
  }

  /**
   * Test the getCollection() and that the collection is not changed by any other operation
   */
  @isTest
  private static void testGetCollectionAndImmutability() {
    Test.startTest();
    List<String> testList = new List<String>{ 'A', 'B', 'C' };
    AFFIter.Iterator it = new AFFIter.ListIterator(testList);

    List<Object> clonedTest = it.getCollection();
    System.Assert.areEqual(
      testList.size(),
      clonedTest.size(),
      'Collection size'
    );
    for (Integer i = 0; i < testList.size(); ++i) {
      System.Assert.areEqual(testList[i], clonedTest[i], 'Collection value');
    }
    testList.set(0, 'D');
    System.Assert.areNotEqual(
      clonedTest.get(0),
      testList.get(0),
      'Collection value changed'
    );
    testList.add('E');
    System.Assert.areEqual(3, clonedTest.size(), 'Collection size changed');
    System.Assert.areEqual(4, testList.size(), 'Collection size changed');

    Test.stopTest();
  }

  /**
   * Test AFFIter.ListIterator.getCollection() with SObject[]
   */
  @IsTest
  private static void testGetCollectionWithSObject() {
    List<Account> accs = new List<Account>{
      new Account(Name = 'A'),
      new Account(Name = 'B'),
      new Account(Name = 'C')
    };
    insert accs;

    Test.startTest();
    AFFIter.Iterator it = new AFFIter.ListIterator(accs);
    List<Object> clonedTest = it.getCollection();
    System.Assert.areEqual(accs.size(), clonedTest.size(), 'Collection size');
    Account clonedAcc = (Account) clonedTest[0];
    clonedAcc.Name = 'D';
    System.Assert.areNotEqual(
      accs[0].Name,
      clonedAcc.Name,
      'Collection value changed'
    );
    clonedTest.add(new Account(Name = 'E'));
    System.Assert.areNotEqual(
      accs.size(),
      clonedTest.size(),
      'Collection size changed'
    );
    Test.stopTest();
  }

  private class CloneableImpl implements AFFCommons.Cloneable {
    public String name { get; set; }

    public CloneableImpl(String name) {
      this.name = name;
    }

    public Object clone(Boolean deepClone) {
      return new CloneableImpl(this.name);
    }
  }

  /**
   * Test AFFIter.ListIterator.getCollection() with AFFCommons.Cloneable[]
   */
  @IsTest
  private static void testGetCollectionWithCloneable() {
    Test.startTest();
    List<AFFCommons.Cloneable> testList = new List<AFFCommons.Cloneable>{
      new CloneableImpl('ABC')
    };
    AFFIter.Iterator it = new AFFIter.ListIterator(testList);
    List<Object> clonedTest = it.getCollection();
    System.Assert.areEqual(
      testList.size(),
      clonedTest.size(),
      'Collection size'
    );
    CloneableImpl cloned = (CloneableImpl) clonedTest[0];
    cloned.name = 'DEF';
    System.Assert.areNotEqual(
      ((CloneableImpl) testList[0]).Name,
      cloned.Name,
      'Collection value changed'
    );
    clonedTest.add(new CloneableImpl('ZZZ'));
    System.Assert.areNotEqual(
      testList.size(),
      clonedTest.size(),
      'Collection size changed'
    );
    Test.stopTest();
  }

  private static void assertReset(
    AFFIter.Iterator it,
    List<Integer> expectedList
  ) {
    System.Assert.areEqual(
      expectedList[0],
      it.getCurrIndex(),
      'null input iterator' + it
    );
    it.next();
    System.Assert.areEqual(
      expectedList[1],
      it.getCurrIndex(),
      'empty input iterator' + it
    );
    it.reset();
    System.Assert.areEqual(
      expectedList[2],
      it.getCurrIndex(),
      'empty input iterator after reset' + it
    );
  }

  /**
   * test AFFIter.ListIterator.reset()
   */
  @IsTest
  private static void testReset() {
    Test.startTest();

    // Test null collections
    List<Integer> expectedRes = new List<Integer>{ -1, -1, -1 };
    assertReset(new AFFIter.ListIterator(null), expectedRes);
    assertReset(new AFFIter.SetIterator(null), expectedRes);
    assertReset(
      new AFFIter.MapIterator((Map<Object, Object>) null),
      expectedRes
    );
    // Test empty collections
    assertReset(new AFFIter.ListIterator(new List<Integer>()), expectedRes);
    assertReset(new AFFIter.SetIterator(new Set<Object>()), expectedRes);
    assertReset(
      new AFFIter.MapIterator(new Map<Object, Object>()),
      expectedRes
    );

    // Not empty collection
    expectedRes = new List<Integer>{ 0, 1, 0 };
    assertReset(
      new AFFIter.ListIterator(new List<Integer>{ 1, 2, 3 }),
      expectedRes
    );
    assertReset(
      new AFFIter.SetIterator(new Set<Object>{ 1, 2, 3 }),
      expectedRes
    );
    assertReset(
      new AFFIter.MapIterator(
        new Map<Object, Object>{ 1 => 1, 2 => 2, 3 => 3 }
      ),
      expectedRes
    );

    // List<String> testList = null;
    // AFFIter.Iterator it = new AFFIter.ListIterator(testList);
    // System.Assert.areEqual(-1, it.getCurrIndex(), 'null input list');
    // it.next();
    // System.Assert.areEqual(-1, it.getCurrIndex(), 'empty input list');
    // it.reset();
    // System.Assert.areEqual(
    //   -1,
    //   it.getCurrIndex(),
    //   'null input list after reset'
    // );
    // testList = new List<String>();
    // it = new AFFIter.ListIterator(testList);
    // System.Assert.areEqual(-1, it.getCurrIndex(), 'empty input list');
    // it.next();
    // System.Assert.areEqual(-1, it.getCurrIndex(), 'empty input list');
    // it.reset();
    // System.Assert.areEqual(
    //   -1,
    //   it.getCurrIndex(),
    //   'empty input list after reset'
    // );
    // testList = new List<String>{ 'A', 'B', 'C' };
    // it = new AFFIter.ListIterator(testList);
    // System.Assert.areEqual(0, it.getCurrIndex(), 'input list');
    // it.next();
    // System.Assert.areEqual(1, it.getCurrIndex(), 'input list after next');
    // it.reset();
    // System.Assert.areEqual(0, it.getCurrIndex(), 'input list after reset');

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }
}
