/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFIter.Iterator.reduce() method
 */
@IsTest
@SuppressWarnings('PMD.ExcessiveParameterList')
public class AFFIterReduceTest {
  /**
   * Callback for integer collection.
   */
  private class IntegerCollectionSumOfAllElements implements AFFIter.ReduceCallback {
    public Object execute(
      Object accumulator,
      Object elem,
      Integer i,
      List<Object> arr
    ) {
      Integer res = ((Integer) accumulator) + ((Integer) elem);
      elem = (Integer) elem + 1000; // Primitive type change is local, but for the sake of the test
      return res;
    }
  }

  private static void assertCollectionsEqual(
    List<Object> beforeCol,
    List<Object> afterCol
  ) {
    System.Assert.areEqual(
      beforeCol.size(),
      afterCol.size(),
      'Collection size'
    );
    for (Integer i = 0; i < beforeCol.size(); i++) {
      System.Assert.areEqual(
        beforeCol[i],
        afterCol[i],
        'Collection element ' + i
      );
    }
  }

  /**
   * Test reduce on null or empty collection
   */
  private static void testNullOrEmptyCollection(
    AFFIter.Iterator it,
    AFFIter.ReduceCallback cb,
    Integer expectedSum
  ) {
    List<Object> beforeReduceCloned = it.getCollection();

    System.Assert.areEqual(false, it.hasNext(), 'First it.hasNext: ' + it);
    System.Assert.areEqual(null, it.next(), 'First it.next: ' + it);

    try {
      Object sum = it.reduce(cb);
      System.assert(false, 'We should not be here');
    } catch (IllegalArgumentException e) {
      System.assert(true, 'We expected IllegalArgumentException here');
    }

    Object sum = it.reduce(expectedSum, cb);
    System.Assert.areEqual(expectedSum, sum, 'After reduce: ' + sum);

    List<Object> afterReduceCloned = it.getCollection();
    assertCollectionsEqual(beforeReduceCloned, afterReduceCloned);
  }

  /**
   * Test reduce when collection is not empty
   */
  private static Boolean testNotEmptyCollectionReduce(
    AFFIter.Iterator it,
    AFFIter.ReduceCallback cb,
    Integer expectedSum
  ) {
    List<Object> beforeReduceCloned = it.getCollection();

    Integer firstElem = (beforeReduceCloned[0] instanceof AFFIter.MapEntry)
      ? (Integer) ((AFFIter.MapEntry) beforeReduceCloned[0]).key
      : (Integer) beforeReduceCloned[0];

    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext: ' + it);
    System.Assert.areEqual(
      beforeReduceCloned[0],
      it.next(),
      'First it.next: ' + it
    );

    Object sum1 = it.reduce(cb);
    // sum1 - 1 because if initial accamulator is not set, then first element is used as initial value
    System.Assert.areEqual(
      expectedSum,
      (Integer) sum1 - firstElem,
      'After reduce: ' + it
    );

    List<Object> afterReduceCloned = it.getCollection();
    assertCollectionsEqual(beforeReduceCloned, afterReduceCloned);

    Object sum2 = it.reduce(0, cb);
    System.Assert.areEqual(expectedSum, sum2, 'After reduce: ' + it);

    afterReduceCloned = it.getCollection();

    assertCollectionsEqual(afterReduceCloned, it.getCollection());

    return true;
  }

  /**
   * Test reduce for AFFIter.ListIterator
   */
  @IsTest
  private static void testListIteratorReduce() {
    Test.startTest();

    AFFIter.ReduceCallback cb = new IntegerCollectionSumOfAllElements();

    // null collection and empty collection
    testNullOrEmptyCollection(new AFFIter.ListIterator(null), cb, 10);
    testNullOrEmptyCollection(
      new AFFIter.ListIterator(new List<Integer>()),
      cb,
      10
    );

    // List with elements
    List<Integer> intList = new List<Integer>{ 1, 2, 3 };
    testNotEmptyCollectionReduce(new AFFIter.ListIterator(intList), cb, 6);

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }

  /**
   * Test reduce for AFFIter.SetIterator
   */
  @IsTest
  private static void testSetIteratorReduce() {
    Test.startTest();

    AFFIter.ReduceCallback cb = new IntegerCollectionSumOfAllElements();

    // null collection and empty collection
    testNullOrEmptyCollection(new AFFIter.SetIterator(null), cb, 10);
    testNullOrEmptyCollection(
      new AFFIter.SetIterator(new Set<Object>()),
      cb,
      10
    );

    // Set with elements
    Set<Object> intSet = new Set<Object>{ 1, 2, 3 };
    testNotEmptyCollectionReduce(new AFFIter.SetIterator(intSet), cb, 6);

    System.assert(true, 'To avoid PMD warning');
    Test.stopTest();
  }

  /**
   * Callback for AFFIter.MapEntry collection.
   */
  private class MapEntryCollectionSumOfAllKeys implements AFFIter.ReduceCallback {
    public Object execute(
      Object accumulator,
      Object elem,
      Integer i,
      List<Object> arr
    ) {
      // Initial accumulator can be specified like Integer param. If not, it will be MapEntry
      Integer accumInt = (accumulator instanceof AFFIter.MapEntry)
        ? (Integer) ((AFFIter.MapEntry) accumulator).key
        : (Integer) accumulator;

      AFFIter.MapEntry meElem = (AFFIter.MapEntry) elem;
      Integer res = accumInt + (Integer) meElem.key;
      // Check immutability of the source collection
      meElem.key = (Integer) meElem.key + 20;
      return res;
    }
  }

  /**
   * Test reduce for AFFIter.MapIterator
   */
  @IsTest
  private static void testMapIteratorReduce() {
    Test.startTest();

    AFFIter.ReduceCallback cb = new MapEntryCollectionSumOfAllKeys();

    // null collection and empty collection
    testNullOrEmptyCollection(
      new AFFIter.MapIterator((Map<Object, Object>) null),
      cb,
      10
    );
    testNullOrEmptyCollection(
      new AFFIter.MapIterator(new Map<Object, Object>()),
      cb,
      10
    );

    // Map with elements
    Map<Object, Object> intMap = new Map<Object, Object>{
      1 => 1,
      2 => 2,
      3 => 3
    };
    testNotEmptyCollectionReduce(new AFFIter.MapIterator(intMap), cb, 6);

    System.assert(true, 'To avoid PMD warning');

    Test.stopTest();
  }
}
