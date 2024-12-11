/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFIter.Iterator.transform() method
 */
@IsTest
public class AFFIterTransformTest {
  /**
   * Callback for transformation Integer to MapEntry.
   */
  private class TransformIntegerToMapEntry implements AFFIter.MapCallback {
    public Object execute(Object obj, Integer i, List<Object> arr) {
      Integer intEl = (Integer) obj;
      intEl += i;
      return new AFFIter.MapEntry(intEl, intEl);
    }
  }

  /**
   * Tests the transform method of the Iterator when input is null or empty list
   */
  private static void nullOrEmptyCollectionTransform(
    AFFIter.Iterator it,
    AFFIter.MapCallback cb
  ) {
    System.Assert.areEqual(false, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(null, it.next(), 'First it.next');

    List<Object> beforeTransformCloned = it.getCollection();

    AFFIter.Iterator afterTransformIt = it.transform(cb);
    System.Assert.areEqual(
      false,
      afterTransformIt.hasNext(),
      'After Transform it.hasNext'
    );
    System.Assert.areEqual(
      null,
      afterTransformIt.next(),
      'After Transform it.next'
    );

    List<Object> afterTransformCloned = afterTransformIt.getCollection();

    System.Assert.areEqual(
      beforeTransformCloned.size(),
      afterTransformCloned.size(),
      'Collection size'
    );
  }

  /**
   * Tests the transform method of the Iterator when input is not null or empty list
   */
  private static Boolean testNotEmptyCollectionTransform(
    AFFIter.Iterator it,
    AFFIter.MapCallback cb
  ) {
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(1, it.next(), 'First it.next');

    List<Object> beforeTransformCloned = it.getCollection();

    AFFIter.Iterator afterTransformIt = it.transform(cb);

    List<Object> afterTransformCloned = afterTransformIt.getCollection();

    List<Object> originalCloned = it.getCollection();

    // immutability of the original iterator collection
    for (Integer i = 0; i < originalCloned.size(); ++i) {
      System.Assert.areEqual(
        originalCloned[i],
        beforeTransformCloned[i],
        'Compare ' + i + ' element'
      );
    }

    //
    System.Assert.areEqual(
      true,
      afterTransformIt.hasNext(),
      'After Transform it.hasNext'
    );
    System.Assert.areEqual(
      new AFFIter.MapEntry(1, 1),
      (AFFIter.MapEntry) afterTransformIt.next(),
      'After Transform 1st it.next'
    );
    System.Assert.areEqual(
      new AFFIter.MapEntry(3, 3),
      (AFFIter.MapEntry) afterTransformIt.next(),
      'After Transform 2d it.next'
    );
    System.Assert.areEqual(
      new AFFIter.MapEntry(5, 5),
      (AFFIter.MapEntry) afterTransformIt.next(),
      'After Transform 3d it.next'
    );

    System.Assert.areEqual(
      beforeTransformCloned.size(),
      afterTransformCloned.size(),
      'Compare underline array size after Filter'
    );
    for (Integer i = 0; i < beforeTransformCloned.size(); ++i) {
      if (i == 0) {
        System.Assert.areEqual(
          beforeTransformCloned[i],
          ((AFFIter.MapEntry) afterTransformCloned[i]).key,
          'Compare element ' + i
        );
      } else {
        System.Assert.areNotEqual(
          beforeTransformCloned[i],
          ((AFFIter.MapEntry) afterTransformCloned[i]).key,
          'Compare element ' + i
        );
      }
    }

    return true;
  }

  /**
   * Tests the transform method of the ListIterator.
   */
  @IsTest
  public static void testListIteratorTransform() {
    Test.startTest();

    AFFIter.MapCallback cb = new TransformIntegerToMapEntry();

    // Input list is null
    nullOrEmptyCollectionTransform(new AFFIter.ListIterator(null), cb);

    // Input list is empty
    nullOrEmptyCollectionTransform(
      new AFFIter.ListIterator(new List<Integer>()),
      cb
    );

    // List with elements
    List<Integer> intList = new List<Integer>{ 1, 2, 3 };
    AFFIter.Iterator it = new AFFIter.ListIterator(intList);
    System.assertEquals(
      true,
      testNotEmptyCollectionTransform(it, cb),
      'Final not empty transform finished'
    );

    Test.stopTest();
  }

  /**
   * Tests the transform method of the SetIterator.
   */
  @IsTest
  public static void testSetIteratorTransform() {
    Test.startTest();

    AFFIter.MapCallback cb = new TransformIntegerToMapEntry();

    // Input list is null
    nullOrEmptyCollectionTransform(new AFFIter.SetIterator(null), cb);

    // Input list is empty
    nullOrEmptyCollectionTransform(
      new AFFIter.SetIterator(new Set<Object>()),
      cb
    );

    // List with elements
    Set<Object> intSet = new Set<Object>{ 1, 2, 3 };
    AFFIter.Iterator it = new AFFIter.SetIterator(intSet);
    System.assertEquals(
      true,
      testNotEmptyCollectionTransform(it, cb),
      'Final not empty transform finished'
    );

    Test.stopTest();
  }

  /**
   * Callback for transformation Integer to MapEntry.
   */
  private class TransformMapEntryToInteger implements AFFIter.MapCallback {
    public Object execute(Object obj, Integer i, List<Object> arr) {
      AFFIter.MapEntry me = (AFFIter.MapEntry) obj;
      return (Integer) me.key + i;
    }
  }

  private static Boolean testNotEmptyMapTransform(
    AFFIter.Iterator it,
    AFFIter.MapCallback cb
  ) {
    System.Assert.areEqual(true, it.hasNext(), 'First it.hasNext');
    System.Assert.areEqual(
      new AFFIter.MapEntry(1, 1),
      it.next(),
      'First it.next'
    );

    List<Object> beforeTransformCloned = it.getCollection();

    AFFIter.Iterator afterTransformIt = it.transform(cb);

    List<Object> afterTransformCloned = afterTransformIt.getCollection();

    List<Object> originalCloned = it.getCollection();

    // immutability of the original iterator collection
    for (Integer i = 0; i < originalCloned.size(); ++i) {
      System.Assert.areEqual(
        originalCloned[i],
        beforeTransformCloned[i],
        'Compare ' + i + ' element'
      );
    }

    //
    System.Assert.areEqual(
      true,
      afterTransformIt.hasNext(),
      'After Transform it.hasNext'
    );
    System.Assert.areEqual(
      1,
      (Integer) afterTransformIt.next(),
      'After Transform 1st it.next'
    );
    System.Assert.areEqual(
      3,
      (Integer) afterTransformIt.next(),
      'After Transform 2d it.next'
    );
    System.Assert.areEqual(
      5,
      (Integer) afterTransformIt.next(),
      'After Transform 3d it.next'
    );

    System.Assert.areEqual(
      beforeTransformCloned.size(),
      afterTransformCloned.size(),
      'Compare underline array size after Filter'
    );
    for (Integer i = 0; i < beforeTransformCloned.size(); ++i) {
      if (i == 0) {
        System.Assert.areEqual(
          ((AFFIter.MapEntry) beforeTransformCloned[i]).key,
          (Integer) afterTransformCloned[i],
          'Compare element ' + i
        );
      } else {
        System.Assert.areNotEqual(
          ((AFFIter.MapEntry) beforeTransformCloned[i]).key,
          (Integer) afterTransformCloned[i],
          'Compare element ' + i
        );
      }
    }

    return true;
  }

  /**
   * Tests the transform method of the MapIterator.
   */
  @IsTest
  public static void testMapIteratorTransform() {
    Test.startTest();

    AFFIter.MapCallback cb = new TransformMapEntryToInteger();

    // Input list is null
    nullOrEmptyCollectionTransform(
      new AFFIter.MapIterator((Map<Object, Object>) null),
      cb
    );

    // Input list is empty
    nullOrEmptyCollectionTransform(
      new AFFIter.MapIterator(new Map<Object, Object>()),
      cb
    );

    // List with elements
    Map<Object, Object> intMap = new Map<Object, Object>{
      1 => 1,
      2 => 2,
      3 => 3
    };
    AFFIter.Iterator it = new AFFIter.MapIterator(intMap);
    System.assertEquals(
      true,
      testNotEmptyMapTransform(it, cb),
      'Final not empty transform finished'
    );

    Test.stopTest();
  }
}
