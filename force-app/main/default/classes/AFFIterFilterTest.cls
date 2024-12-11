/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Testing AFFIter.Iterator.FilterCallback
 */
@IsTest
private class AFFIterFilterTest {
  /**
   * Integer less then 10 filtering callback implementation
   */
  private class IntegerLessThen10 implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      Integer intEl = (Integer) obj;
      // test immutability of the list
      Boolean res = intEl < 10;
      intEl += 1;
      return res;
    }
  }

  /**
   * Test AFFIter.ListIterator.filter()
   */
  @IsTest
  private static void testListIteratorFilter() {
    Test.startTest();
    // NULL list as input
    List<Integer> testData = null;
    AFFIter.Iterator it = new AFFIter.ListIterator(testData);
    AFFIter.Iterator filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // Empty list as input
    testData = new List<Integer>();
    it = new AFFIter.ListIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // List where all elements are greater than 10
    testData = new List<Integer>{ 20, 30, 40 };
    it = new AFFIter.ListIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(20, it.next(), 'Iterator immutable: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has NO data' + filteredIt
    );

    // List where are 2 elements are less than 10
    testData = new List<Integer>{ -10, -20, 20 };
    it = new AFFIter.ListIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(-10, it.next(), 'Iterator immutable: ' + it);
    System.Assert.areEqual(
      3,
      it.getCollection().size(),
      'Iterator has 3 elements: ' + it
    );
    System.Assert.areEqual(
      true,
      filteredIt.hasNext(),
      'Filtered Iterator has data' + filteredIt
    );
    System.Assert.areEqual(
      -10,
      filteredIt.next(),
      'FilteredI terator immutable: ' + filteredIt
    );
    System.Assert.areEqual(
      2,
      filteredIt.getCollection().size(),
      'Filtered Iterator has 2 elements: ' + filteredIt
    );

    Test.stopTest();
  }

  /**
   * Test AFFIter.SetIterator.filter()
   */
  @IsTest
  private static void testSetIteratorFilter() {
    Test.startTest();
    // NULL list as input
    Set<Object> testData = null;
    AFFIter.Iterator it = new AFFIter.SetIterator(testData);
    AFFIter.Iterator filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // Empty list as input
    testData = new Set<Object>();
    it = new AFFIter.SetIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // List where all elements are greater than 10
    testData = new Set<Object>{ 20, 30, 40 };
    it = new AFFIter.SetIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(20, it.next(), 'Iterator immutable: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has NO data' + filteredIt
    );

    // Set where are 2 elements are less than 10
    testData = new Set<Object>{ -10, -20, 20 };
    it = new AFFIter.SetIterator(testData);
    filteredIt = it.filter(new IntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(-10, it.next(), 'Iterator immutable: ' + it);
    System.Assert.areEqual(
      3,
      it.getCollection().size(),
      'Iterator has 3 elements: ' + it
    );
    System.Assert.areEqual(
      true,
      filteredIt.hasNext(),
      'Filtered Iterator has data' + filteredIt
    );
    System.Assert.areEqual(
      -10,
      filteredIt.next(),
      'FilteredI terator immutable: ' + filteredIt
    );
    System.Assert.areEqual(
      2,
      filteredIt.getCollection().size(),
      'Filtered Iterator has 2 elements: ' + filteredIt
    );

    Test.stopTest();
  }

  /**
   * MapEntry key value is Integer less then 10 filtering callback implementation
   */
  private class MapEntryKeyIntegerLessThen10 implements AFFIter.FilterCallback {
    public Boolean execute(Object obj, Integer i, List<Object> arr) {
      AFFIter.MapEntry me = (AFFIter.MapEntry) obj;
      // test immutability of the list
      Boolean res = (Integer) me.key < 10;
      me.key = (Integer) me.key + 1;
      return res;
    }
  }

  /**
   * Test AFFIter.MapIterator.filter()
   */
  @IsTest
  private static void testMapIteratorFilter() {
    Test.startTest();
    // NULL list as input
    Map<Object, Integer> testData = null;
    AFFIter.Iterator it = new AFFIter.MapIterator(testData);
    AFFIter.Iterator filteredIt = it.filter(new MapEntryKeyIntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // Empty list as input
    testData = new Map<Object, Integer>();
    it = new AFFIter.MapIterator(testData);
    filteredIt = it.filter(new MapEntryKeyIntegerLessThen10());
    System.Assert.areEqual(false, it.hasNext(), 'Iterator has no data: ' + it);
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has no data' + filteredIt
    );

    // List where all elements are greater than 10
    testData = new Map<Object, Integer>{ 20 => 20, 30 => 30, 40 => 40 };
    it = new AFFIter.MapIterator(testData);
    filteredIt = it.filter(new MapEntryKeyIntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(
      new AFFIter.MapEntry(20, 20),
      it.next(),
      'Iterator immutable: ' + it
    );
    System.Assert.areEqual(
      false,
      filteredIt.hasNext(),
      'Filtered Iterator has NO data' + filteredIt
    );

    // Set where are 2 elements are less than 10
    testData = new Map<Object, Integer>{ -10 => -10, -20 => -20, 20 => 20 };
    it = new AFFIter.MapIterator(testData);
    filteredIt = it.filter(new MapEntryKeyIntegerLessThen10());
    System.Assert.areEqual(true, it.hasNext(), 'Iterator has data: ' + it);
    System.Assert.areEqual(
      new AFFIter.MapEntry(-10, -10),
      it.next(),
      'Iterator immutable: ' + it
    );
    System.Assert.areEqual(
      3,
      it.getCollection().size(),
      'Iterator has 3 elements: ' + it
    );
    System.Assert.areEqual(
      true,
      filteredIt.hasNext(),
      'Filtered Iterator has data' + filteredIt
    );
    System.Assert.areEqual(
      new AFFIter.MapEntry(-10, -10),
      filteredIt.next(),
      'FilteredI terator immutable: ' + filteredIt
    );
    System.Assert.areEqual(
      2,
      filteredIt.getCollection().size(),
      'Filtered Iterator has 2 elements: ' + filteredIt
    );

    Test.stopTest();
  }
}
