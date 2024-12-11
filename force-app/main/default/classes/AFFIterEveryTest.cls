/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFIter.Iterator.every() method
 */
@IsTest
public class AFFIterEveryTest {
  /**
   * implentation of the AFFIter.FilterCallback for our testing
   */
  private virtual class IsIntegerPositiveAndNotZero implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      Integer intEl = (Integer) obj;
      return intEl > 0;
    }
  }

  /**
   * Testing AFFIter.Iterator.every() method with null or empty collection
   */
  private static void testEmptyCollectionEvery(
    AFFIter.Iterator it,
    AFFIter.FilterCallback cb
  ) {
    System.Assert.areEqual(false, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(null, it.next(), 'First it.next');

    List<Object> beforeEveryCloned = it.getCollection();

    Boolean afterEveryResult = it.every(cb);
    System.Assert.areEqual(true, afterEveryResult, 'After every it.hasNext');

    List<Object> afterEveryCloned = it.getCollection();

    System.Assert.areEqual(
      beforeEveryCloned.size(),
      afterEveryCloned.size(),
      'Collection size'
    );
  }

  /**
   * Testing AFFIter.Iterator.every() method with not empty collection
   */
  private static Boolean testNotEmptyCollectionEvery(
    AFFIter.Iterator it,
    AFFIter.FilterCallback cb,
    Boolean isEveryGood
  ) {
    List<Object> beforeEveryCloned = it.getCollection();
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(beforeEveryCloned[0], it.next(), 'First it.next');

    Boolean afterEveryResult = it.every(cb);
    System.Assert.areEqual(
      isEveryGood,
      afterEveryResult,
      'After every:' + afterEveryResult
    );

    List<Object> afterEveryCloned = it.getCollection();

    System.Assert.areEqual(
      beforeEveryCloned.size(),
      afterEveryCloned.size(),
      'Collection size'
    );
    for (Integer i = 0; i < beforeEveryCloned.size(); ++i) {
      System.Assert.areEqual(
        beforeEveryCloned[i],
        afterEveryCloned[i],
        'Compare ' + i + ' element'
      );
    }

    return true;
  }

  /**
   * Testing AFFIter.Iterator.every() method with ListIterator
   */
  @IsTest
  private static void testListIteratorForEvery() {
    Test.startTest();

    AFFIter.FilterCallback cb = new IsIntegerPositiveAndNotZero();

    List<Integer> intList = null;
    AFFIter.Iterator it = new AFFIter.ListIterator(intList);
    testEmptyCollectionEvery(it, cb);

    intList = new List<Integer>();
    it = new AFFIter.ListIterator(intList);
    testEmptyCollectionEvery(it, cb);

    intList = new List<Integer>{ 1, 2, 3 };
    it = new AFFIter.ListIterator(intList);
    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, true),
      'After every'
    );

    intList = new List<Integer>{ 1, 0, -3 };
    it = new AFFIter.ListIterator(intList);

    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, false),
      'After every'
    );

    Test.stopTest();
  }

  /**
   * Testing AFFIter.Iterator.every() method with SetIterator
   */
  @IsTest
  private static void testSetIteratorForEvery() {
    Test.startTest();

    AFFIter.FilterCallback cb = new IsIntegerPositiveAndNotZero();

    Set<Object> intSet = null;
    AFFIter.Iterator it = new AFFIter.SetIterator(intSet);
    testEmptyCollectionEvery(it, cb);

    intSet = new Set<Object>();
    it = new AFFIter.SetIterator(intSet);
    testEmptyCollectionEvery(it, cb);

    intSet = new Set<Object>{ 1, 2, 3 };
    it = new AFFIter.SetIterator(intSet);
    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, true),
      'After every'
    );

    intSet = new Set<Object>{ -2, -1, 0 };
    it = new AFFIter.SetIterator(intSet);

    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, false),
      'After every'
    );

    Test.stopTest();
  }

  /**
   * implentation of the AFFIter.FilterCallback for our testing
   */
  private virtual class IsMapEntryKeyAndValuePositiveAndNotZero implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      AFFIter.MapEntry me = (AFFIter.MapEntry) obj;
      return (Integer) me.key > 0 && (Integer) me.value > 0;
    }
  }

  /**
   * Testing AFFIter.Iterator.every() method with MapIterator
   */
  @IsTest
  private static void testMapIteratorForEvery() {
    Test.startTest();

    AFFIter.FilterCallback cb = new IsMapEntryKeyAndValuePositiveAndNotZero();

    Map<Object, Object> intByInt = null;
    AFFIter.Iterator it = new AFFIter.MapIterator(
      (Map<Object, Object>) intByInt
    );
    testEmptyCollectionEvery(it, cb);

    intByInt = new Map<Object, Object>();
    it = new AFFIter.MapIterator(intByInt);
    testEmptyCollectionEvery(it, cb);

    intByInt = new Map<Object, Object>{ 1 => 1, 2 => 2, 3 => 3 };
    it = new AFFIter.MapIterator(intByInt);
    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, true),
      'After every'
    );

    intByInt = new Map<Object, Object>{ -2 => 2, -1 => 1, 3 => -3 };
    it = new AFFIter.MapIterator(intByInt);

    System.Assert.areEqual(
      true,
      testNotEmptyCollectionEvery(it, cb, false),
      'After every'
    );

    Test.stopTest();
  }
}
