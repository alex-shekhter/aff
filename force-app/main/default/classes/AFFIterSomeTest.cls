/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFIter.Iterator.some() method
 */
@IsTest
public class AFFIterSomeTest {
  /**
   * Callback for integer collection.
   */
  private class ElementGreaterThenZeroCallback implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      Integer intEl = (Integer) obj;
      Boolean res = intEl > 0;
      // check potential immutability of the source collection
      intEl++; // will not change outer collection since it is primitive type, but just in case
      return res;
    }
  }

  /**
   * test null and empty collection for Some
   */
  private static void testNullOrEmptyCollection(
    AFFIter.Iterator it,
    AFFIter.FilterCallback cb
  ) {
    System.Assert.areEqual(false, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(null, it.next(), 'First it.next');

    List<Object> beforeEveryCloned = it.getCollection();

    System.Assert.areEqual(false, it.some(cb), 'Some on empty collection' + it);

    List<Object> afterEveryCloned = it.getCollection();

    System.Assert.areEqual(0, afterEveryCloned.size(), 'Collection size');
    System.Assert.areEqual(
      beforeEveryCloned.size(),
      afterEveryCloned.size(),
      'Collection size'
    );
  }

  private static Boolean testNotEmptyCollection(
    AFFIter.Iterator it,
    AFFIter.FilterCallback cb,
    Boolean expectedRes
  ) {
    List<Object> beforeSomeCloned = it.getCollection();
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(beforeSomeCloned[0], it.next(), 'First it.next');

    Boolean afterSomeResult = it.some(cb);
    System.Assert.areEqual(
      expectedRes,
      afterSomeResult,
      'After some:' + afterSomeResult
    );

    List<Object> afterSomeCloned = it.getCollection();
    System.Assert.areEqual(
      beforeSomeCloned.size(),
      afterSomeCloned.size(),
      'Collection size'
    );
    for (Integer i = 0; i < afterSomeCloned.size(); i++) {
      System.Assert.areEqual(
        beforeSomeCloned[i],
        afterSomeCloned[i],
        'Collection value'
      );
    }
    return true;
  }

  /**
   * Test AFFIter.ListIterator.some() method
   */
  @IsTest
  private static void testListIteratorSome() {
    Test.startTest();

    AFFIter.FilterCallback cb = new ElementGreaterThenZeroCallback();

    // Test null list
    List<Integer> testList = null;
    AFFIter.Iterator it = new AFFIter.ListIterator(testList);
    testNullOrEmptyCollection(it, cb);

    // Test empty list
    testList = new List<Integer>();
    testNullOrEmptyCollection(it, cb);

    // Test list with elements
    testList = new List<Integer>{ 0, -1, -2, -3, -4 };
    testNotEmptyCollection(new AFFIter.ListIterator(testList), cb, false);

    // Test list with elements
    testList = new List<Integer>{ 0, -1, -2, -3, 4 };
    testNotEmptyCollection(new AFFIter.ListIterator(testList), cb, true);

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }

  /**
   * Test AFFIter.SetIterator.some() method
   */
  @IsTest
  private static void testSetIteratorSome() {
    Test.startTest();

    AFFIter.FilterCallback cb = new ElementGreaterThenZeroCallback();

    // Test null set
    Set<Object> testSet = null;
    AFFIter.Iterator it = new AFFIter.SetIterator(testSet);
    testNullOrEmptyCollection(it, cb);

    // Test empty set
    testSet = new Set<Object>();
    testNullOrEmptyCollection(it, cb);

    // Test set with elements
    testSet = new Set<Object>{ 0, -1, -2, -3, -4 };
    testNotEmptyCollection(new AFFIter.SetIterator(testSet), cb, false);

    // Test set with elements
    testSet = new Set<Object>{ 0, -1, -2, -3, 4 };
    testNotEmptyCollection(new AFFIter.SetIterator(testSet), cb, true);

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }

  /**
   * Callback for AFFIter.MapEntry collection.
   */
  private class MapEntryKeyGreaterThenZeroCallback implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      AFFIter.MapEntry me = (AFFIter.MapEntry) obj;
      Boolean res = (Integer) me.key > 0;
      // check potential immutability of the source collection
      me.key = (Integer) me.key + 10;
      return res;
    }
  }

  /**
   * Test AFFIter.MapIterator.some() method
   */
  @IsTest
  private static void testMapIteratorSome() {
    Test.startTest();

    AFFIter.FilterCallback cb = new MapEntryKeyGreaterThenZeroCallback();

    // Test null map
    Map<Object, Object> testMap = null;
    AFFIter.Iterator it = new AFFIter.MapIterator(
      (Map<Object, Object>) testMap
    );
    testNullOrEmptyCollection(it, cb);

    // Test empty map
    testMap = new Map<Object, Object>();
    testNullOrEmptyCollection(it, cb);

    // Test map with elements
    testMap = new Map<Object, Object>{
      0 => 0,
      -1 => -1,
      -2 => -2,
      -3 => -3,
      -4 => -4
    };
    testNotEmptyCollection(new AFFIter.MapIterator(testMap), cb, false);

    // Test map with elements
    testMap = new Map<Object, Object>{
      0 => 0,
      -1 => -1,
      -2 => -2,
      -3 => -3,
      4 => 4
    };
    testNotEmptyCollection(new AFFIter.MapIterator(testMap), cb, true);

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }
}
