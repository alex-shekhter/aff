/**
 * AFF - Apex Foundation Framework
 *
 * Authot: Alex Shekhter
 *
 * Test class for AFFIter.Iterator.forEach() method
 */
@IsTest
public class AFFIterForEachTest {
  /**
   * ForEach callback which increments each element in the list by the position in the array
   */
  private class IntegerIncrementForEachCallback implements AFFIter.ForEachCallback {
    public void execute(Object obj, Integer i, List<Object> arr) {
      Integer intEl = (Integer) obj;
      // we need to do that since we use Primitive types. Otherwise just changing obj content will be enough
      arr[i] = intEl + i;
    }
  }

  /**
   * Tests the forEach method of the Iterator when input is null or empty list
   */
  private static void nullOrEmptyCollectionForEach(
    AFFIter.Iterator it,
    AFFIter.ForEachCallback cb
  ) {
    System.Assert.areEqual(false, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(null, it.next(), 'First it.next');

    List<Object> beforeForEachCloned = it.getCollection();

    AFFIter.Iterator afterForEachIt = it.forEach(cb);
    System.Assert.areEqual(
      false,
      afterForEachIt.hasNext(),
      'After forEach it.hasNext'
    );
    System.Assert.areEqual(
      null,
      afterForEachIt.next(),
      'After forEach it.next'
    );

    List<Object> afterForEachCloned = afterForEachIt.getCollection();

    System.Assert.areEqual(
      beforeForEachCloned.size(),
      afterForEachCloned.size(),
      'Collection size'
    );
  }

  private static Boolean testNotEmptyCollectionForEach(
    AFFIter.Iterator it,
    AFFIter.ForEachCallback cb
  ) {
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(1, it.next(), 'First it.next');

    List<Object> beforeForEachCloned = it.getCollection();

    AFFIter.Iterator afterForEachIt = it.forEach(cb);

    List<Object> afterForEachCloned = afterForEachIt.getCollection();

    List<Object> originalCloned = it.getCollection();

    // immutability of the original iterator collection
    for (Integer i = 0; i < originalCloned.size(); ++i) {
      System.Assert.areEqual(
        originalCloned[i],
        beforeForEachCloned[i],
        'Compare ' + i + ' element'
      );
    }

    System.Assert.areEqual(
      true,
      afterForEachIt.hasNext(),
      'After forEach it.hasNext'
    );
    System.Assert.areEqual(
      1,
      afterForEachIt.next(),
      'After forEach 1st it.next'
    );
    System.Assert.areEqual(
      3,
      afterForEachIt.next(),
      'After forEach 2d it.next'
    );
    System.Assert.areEqual(
      5,
      afterForEachIt.next(),
      'After forEach 3d it.next'
    );

    System.Assert.areEqual(
      beforeForEachCloned.size(),
      afterForEachCloned.size(),
      'Compare underline array size after Filter'
    );
    for (Integer i = 0; i < beforeForEachCloned.size(); ++i) {
      if (i == 0) {
        System.Assert.areEqual(
          beforeForEachCloned[i],
          afterForEachCloned[i],
          'Compare element ' + i
        );
      } else {
        System.Assert.areNotEqual(
          beforeForEachCloned[i],
          afterForEachCloned[i],
          'Compare element ' + i
        );
      }
    }

    return true;
  }

  /**
   * Tests the forEach method of the Iterator.
   */
  @IsTest
  public static void testListIteratorForEach() {
    Test.startTest();

    AFFIter.ForEachCallback cb = new IntegerIncrementForEachCallback();

    // Input list is null
    nullOrEmptyCollectionForEach(new AFFIter.ListIterator(null), cb);

    // Input list is empty
    nullOrEmptyCollectionForEach(
      new AFFIter.ListIterator(new List<Integer>()),
      cb
    );

    // List with elements
    List<Integer> intList = new List<Integer>{ 1, 2, 3 };
    AFFIter.Iterator it = new AFFIter.ListIterator(intList);
    System.assertEquals(
      true,
      testNotEmptyCollectionForEach(it, cb),
      'Final not empty forEach finished'
    );

    Test.stopTest();
  }

  /**
   * Tests the forEach method of the Iterator for AFFIter.SetIterator
   */
  @IsTest
  public static void testSetIteratorForEach() {
    Test.startTest();

    AFFIter.ForEachCallback cb = new IntegerIncrementForEachCallback();

    // Input set is null
    nullOrEmptyCollectionForEach(new AFFIter.SetIterator(null), cb);

    // Input set is empty
    nullOrEmptyCollectionForEach(
      new AFFIter.SetIterator(new Set<Object>()),
      cb
    );

    // Set with elements
    Set<Object> intSet = new Set<Object>{ 1, 2, 3 };
    AFFIter.Iterator it = new AFFIter.SetIterator(intSet);
    System.assertEquals(
      true,
      testNotEmptyCollectionForEach(it, cb),
      'Final not empty forEach finished'
    );

    Test.stopTest();
  }

  /**
   * ForEach callback which increments each element in the list by the position in the array
   */
  private class MapEntryIncrementForEachCallback implements AFFIter.ForEachCallback {
    public void execute(Object obj, Integer i, List<Object> arr) {
      AFFIter.MapEntry me = (AFFIter.MapEntry) obj;
      me.key = (Integer) me.key + i;
      me.value = (Integer) me.value + i;
    }
  }

  private static Boolean testNotEmptyMapForEach(
    AFFIter.Iterator it,
    AFFIter.ForEachCallback cb
  ) {
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(
      new AFFIter.MapEntry(1, 1),
      it.next(),
      'First it.next'
    );

    List<Object> beforeForEachCloned = it.getCollection();

    AFFIter.Iterator afterForEachIt = it.forEach(cb);

    List<Object> afterForEachCloned = afterForEachIt.getCollection();

    System.Assert.areEqual(
      true,
      afterForEachIt.hasNext(),
      'After forEach it.hasNext'
    );
    System.Assert.areEqual(
      1,
      ((AFFIter.MapEntry) afterForEachIt.next()).key,
      'After forEach 1st it.next'
    );
    System.Assert.areEqual(
      3,
      ((AFFIter.MapEntry) afterForEachIt.next()).key,
      'After forEach 2d it.next'
    );
    System.Assert.areEqual(
      5,
      ((AFFIter.MapEntry) afterForEachIt.next()).key,
      'After forEach 3d it.next'
    );

    System.Assert.areEqual(
      beforeForEachCloned.size(),
      afterForEachCloned.size(),
      'Compare underline array size after Filter'
    );
    for (Integer i = 0; i < beforeForEachCloned.size(); ++i) {
      if (i == 0) {
        System.Assert.areEqual(
          beforeForEachCloned[i],
          afterForEachCloned[i],
          'Compare element ' + i
        );
      } else {
        System.Assert.areNotEqual(
          beforeForEachCloned[i],
          afterForEachCloned[i],
          'Compare element ' + i
        );
      }
    }

    return true;
  }

  /**
   * Tests the forEach method of the Iterator for AFFIter.MapIterator
   */
  @IsTest
  public static void testMapIteratorForEach() {
    Test.startTest();

    AFFIter.ForEachCallback cb = new MapEntryIncrementForEachCallback();

    // Input set is null
    nullOrEmptyCollectionForEach(
      new AFFIter.MapIterator((Map<Object, Object>) null),
      cb
    );

    // Input set is empty
    nullOrEmptyCollectionForEach(
      new AFFIter.MapIterator(new Map<Object, Object>()),
      cb
    );

    // Set with elements
    Map<Object, Object> intMap = new Map<Object, Object>{
      1 => 1,
      2 => 2,
      3 => 3
    };
    AFFIter.Iterator it = new AFFIter.MapIterator(intMap);
    System.assertEquals(
      true,
      testNotEmptyMapForEach(it, cb),
      'Final not empty forEach finished'
    );

    Test.stopTest();
  }
}
