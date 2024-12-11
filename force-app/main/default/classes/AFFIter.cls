/*
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * This is an abstract class to work with collections using iterators.
 *
 * TODO: Consider Iterable support and dynamic map initiaition:
 * <code>
 * SObjectType ofObject = Account.SObjectType;
 * Map<Id, SObject> idToSObject = (Map<Id, SObject>) Type.forName('Map<Id, ' + ofObject  + ' >').newInstance();
 * Map<Id, Account> idToAccount = (Map<Id, Account>) idToSObject;
 * </code>
 * https://beyondthecloud.dev/blog/type-casting-in-apex
 */
@SuppressWarnings('PMD.ExcessiveParameterList, PMD.CognitiveComplexity')
public inherited sharing abstract class AFFIter {
  /**
   * Interface for a callback used in filtering operations.
   */
  public interface FilterCallback {
    /**
     * Executes the filter logic.
     * @param item the current item
     * @param i the index of the current item
     * @param arr the entire collection
     * @return true if the item should be included, false otherwise
     */
    Boolean execute(Object item, Integer i, List<Object> arr);
  }

  /**
   * Interface for a callback used in mapping operations.
   */
  public interface MapCallback {
    /**
     * Executes the mapping/transformation logic.
     * @param item the current item
     * @param i the index of the current item
     * @param arr the entire collection
     * @return the transformed item
     */
    Object execute(Object item, Integer i, List<Object> arr);
  }

  /**
   * Interface for a callback used in forEach operations.
   */
  public interface ForEachCallback {
    /**
     * Executes the forEach logic.
     * @param item the current item
     * @param i the index of the current item
     * @param arr the entire collection
     */
    void execute(Object item, Integer i, List<Object> arr);
  }

  /**
   * Interface for a callback used in reduce operations.
   */
  public interface ReduceCallback {
    /**
     * Executes the reduce logic.
     * @param accumulator the accumulated value
     * @param item the current item
     * @param i the index of the current item
     * @param arr the entire collection
     * @return the new accumulated value
     */
    Object execute(
      Object accumulator,
      Object item,
      Integer i,
      List<Object> arr
    );
  }

  /**
   * Interface for a generic iterator that can traverse over various types of collections.
   */
  public interface Iterator {
    /**
     * Checks whether the current iterator has more elements to process.
     * @return true if there are more elements, false otherwise
     */
    Boolean hasNext();

    /**
     * Returns the next element from the collection, or null if none exists.
     * @return the next element, or null if none exists
     */
    Object next();

    /**
     * Gets the current index in the collection.
     * @return the current index
     */
    Integer getCurrIndex();

    /**
     * Gets a full deep copy of the underlying collection.
     * @return the deep-copied collection
     */
    List<Object> getCollection();

    /**
     * Resets the iterator to the initial position.
     * @return the reset iterator
     */
    Iterator reset();

    // Chainable iteration operations
    /**
     * Filters the collection based on the provided callback.
     * @param cb the filter callback
     * @return a new iterator with the filtered collection
     */
    Iterator filter(FilterCallback cb);

    /**
     * Executes the provided callback for each element in the collection.
     * @param cb the forEach callback
     * @return a new iterator with the modified collection
     */
    Iterator forEach(ForEachCallback cb);

    /**
     * Maps/Transforms the collection based on the provided callback.
     * @param cb the map callback
     * @return a new iterator with the transformed collection
     */
    Iterator transform(MapCallback cb); // js map

    // Chain terminator operations
    /**
     * Checks if all elements in the collection satisfy the provided callback.
     * @param cb the filter callback
     * @return true if all elements satisfy the callback, false otherwise
     */
    Boolean every(FilterCallback cb);

    /**
     * Reduces the collection to a single value based on the provided callback.
     * @param cb the reduce callback
     * @return the reduced value
     */
    Object reduce(ReduceCallback cb);

    /**
     * Reduces the collection to a single value based on the provided callback and initial accumulator.
     * @param accumulator the initial accumulator
     * @param cb the reduce callback
     * @return the reduced value
     */
    Object reduce(Object accumulator, ReduceCallback cb);

    /**
     * Checks if at least one element in the collection satisfies the provided callback.
     * @param cb the filter callback
     * @return true if at least one element satisfies the callback, false otherwise
     */
    Boolean some(FilterCallback cb);
  }

  /**
   * A concrete iterator implementation that can traverse over lists.
   */
  public inherited sharing virtual class ListIterator implements Iterator {
    protected List<Object> lst;
    protected Integer currIndex;

    /**
     * Constructor to create a new ListIterator instance,
     * initializing the current index to 0 if the list is not empty.
     * @param lst the list to iterate over
     */
    public ListIterator(List<Object> lst) {
      this.lst = lst != null ? lst : new List<Object>();
      currIndex = (this.lst.size() == 0) ? -1 : 0;
    }

    /**
     * Checks whether the current iterator has more elements to process.
     * @return true if there are more elements, false otherwise
     */
    public virtual Boolean hasNext() {
      return currIndex >= 0 && currIndex < lst.size();
    }

    /**
     * Returns the next element from the collection, or null if none exists.
     * @return the next element, or null if none exists
     */
    public virtual Object next() {
      return (currIndex >= 0 &&
        currIndex < lst.size())
        ? lst[currIndex++]
        : null;
    }

    /**
     * Gets the current index in the collection.
     * @return the current index
     */
    public virtual Integer getCurrIndex() {
      return currIndex;
    }

    /**
     * Gets a full deep copy of the underlying collection.
     * SObjects will be deep cloned using SObject.clone(true, true, true, true).
     * Regular Apex class instances inside our iterator better to implement
     * AFFComons.Cloneable interface for deep cloning.
     * In the worst case heavy deep cloning based on the JSON serialization will be used
     * @return the deep-copied collection
     */
    public virtual List<Object> getCollection() {
      List<Object> newLst = new List<Object>();
      Integer sz = lst.size();
      for (Integer i = 0; i < sz; i++) {
        Object o = lst[i];
        newLst.add(AFFCommons.deepClone(o));
      }
      return newLst;
    }

    /**
     * Resets the iterator to the initial position.
     * @return the reset iterator
     */
    public virtual Iterator reset() {
      currIndex = (lst.size() > 0) ? 0 : -1;
      return this;
    }

    /**
     * Filter collection inside iterator and return new Iterator with the filtered collection.
     * Source Iterator is not changed
     * @return new Iterator with filtered collection
     */
    public virtual Iterator filter(FilterCallback cb) {
      List<Object> newLst = new List<Object>();
      // if filterCallback change the collection or it's elements - it will be applied to the new collection
      List<Object> paramLst = getCollection();
      for (Integer i = 0; i < lst.size(); i++) {
        Object o = lst[i];
        if (cb.execute(AFFCommons.deepClone(o), i, paramLst)) {
          newLst.add(o);
        }
      }

      return new ListIterator(newLst);
    }

    /**
     * Executes the provided callback for all elements in the iterator.
     * The source iterator is not changed.
     * @param cb the forEach callback
     * @return a new iterator with the modified collection
     */
    public virtual Iterator forEach(ForEachCallback cb) {
      List<Object> cloneLst = getCollection();
      for (Integer i = 0; i < cloneLst.size(); i++) {
        Object o = cloneLst[i];
        cb.execute(o, i, cloneLst);
      }
      return new ListIterator(cloneLst);
    }

    /**
     * Transforms the collection based on the provided callback.
     * The source iterator is not changed.
     * @param cb the map callback
     * @return a new iterator with the transformed collection
     */
    public virtual Iterator transform(MapCallback cb) {
      List<Object> newLst = new List<Object>();
      List<Object> clonedLst = getCollection();
      for (Integer i = 0; i < clonedLst.size(); i++) {
        Object o = clonedLst[i];
        newLst.add(cb.execute(o, i, clonedLst));
      }
      return new ListIterator(newLst);
    }

    // Chain terminator operations
    /**
     * Checks if all elements in the collection satisfy the provided callback.
     * @param cb the filter callback
     * @return true if all elements satisfy the callback, false otherwise
     */
    public virtual Boolean every(FilterCallback cb) {
      List<Object> clonedLst = getCollection();
      for (Integer i = 0; i < lst.size(); i++) {
        Object o = AFFCommons.deepClone(lst[i]);
        if (!cb.execute(o, i, clonedLst)) {
          return false;
        }
      }
      return true;
    }

    /**
     * Reduces the collection to a single value based on the provided callback.
     * @param cb the reduce callback
     * @return the reduced value
     */
    public virtual Object reduce(ReduceCallback cb) {
      return reduce(null, cb);
    }

    /**
     * Reduces the collection to a single value based on the provided callback and initial accumulator.
     *
     * If the initialAccumulator is not provided, the first element of the collection is used
     * as the initial accumulator.
     *
     * But if underline collection is empty and accumulator not set explicitely,
     * it throws IllegalArgumentException
     *
     * @param initialAccumulator the initial accumulator
     * @param cb the reduce callback
     * @return the reduced value
     */
    public virtual Object reduce(Object initialAccumulator, ReduceCallback cb) {
      Integer sz = lst.size();
      List<Object> clonedLst = getCollection();
      Object accumulator = (initialAccumulator == null)
        ? (sz > 0) ? AFFCommons.deepClone(lst[0]) : null
        : initialAccumulator;
      if (accumulator == null) {
        throw new IllegalArgumentException(
          'Error: accamulator initialValue is not defined'
        );
      }
      for (Integer i = 0; i < sz; i++) {
        accumulator = cb.execute(accumulator, clonedLst[i], i, clonedLst);
      }
      return accumulator;
    }

    /**
     * Checks if at least one element in the collection satisfies the provided callback.
     * @param cb the filter callback
     * @return true if at least one element satisfies the callback, false otherwise
     */
    public virtual Boolean some(FilterCallback cb) {
      List<Object> clonedLst = getCollection();
      for (Integer i = 0; i < clonedLst.size(); i++) {
        Object o = clonedLst.get(i);
        if (cb.execute(o, i, clonedLst)) {
          return true;
        }
      }
      return false;
    }
  }

  /**
   * A concrete iterator implementation that can traverse over sets by converting them to lists.
   */
  public inherited sharing virtual class SetIterator extends ListIterator implements Iterator {
    /**
     * Constructor to create a new SetIterator instance, which wraps a set
     * and iterates over its elements as if they were in a list.
     * @param s the set to iterate over
     */
    public SetIterator(Set<Object> s) {
      super(new List<Object>(s));
    }
  }

  /**
   * A simple class representing a key-value pair, used as an entry point for maps.
   */
  public inherited sharing virtual class MapEntry implements AFFCommons.Cloneable {
    /**
     * A simple class representing a key-value pair, used as an entry point for maps.
     */
    public Object key;
    public Object value;

    /**
     * Constructor to create a new MapEntry instance.
     * @param key the key of the map entry
     * @param value the value of the map entry
     */
    public MapEntry(Object key, Object value) {
      this.key = key;
      this.value = value;
    }

    /**
     * Clone method.
     * @return a clone of this instance
     */
    public virtual Object clone(Boolean deepClone) {
      if (deepClone) {
        return new MapEntry(
          AFFCommons.deepClone(this.key),
          AFFCommons.deepClone(this.value)
        );
      }
      return this;
    }

    /**
     * Equals
     */
    public virtual Boolean equals(Object obj) {
      if (obj == null) {
        return false;
      }
      MapEntry other = (MapEntry) obj;
      return this.key == other.key && this.value == other.value;
    }
  }

  /**
   * A concrete iterator implementation that can traverse over maps
   * by converting them to lists of key-value pairs.
   */
  public inherited sharing virtual class MapIterator implements Iterator {
    private ListIterator listIter;

    /**
     * Private constructor to create a new MapIterator instance from an existing iterator.
     * @param listIterWithMapEntries the iterator with map entries
     */
    private MapIterator(Iterator listIterWithMapEntries) {
      this.listIter = (ListIterator) listIterWithMapEntries;
    }

    /**
     * Constructor to create a new MapIterator instance, which iterates over
     * the elements of a map as if they were in a list.
     * @param m the map to iterate over
     */
    public MapIterator(Map<Object, Object> m) {
      if (m == null) {
        listIter = new ListIterator(null);
        return;
      }

      List<MapEntry> lst = new List<MapEntry>();
      for (Object key : m.keySet()) {
        lst.add(new MapEntry(key, m.get(key)));
      }
      listIter = new ListIterator(lst);
    }

    /**
     * Checks whether the current iterator has more elements to process.
     * @return true if there are more elements, false otherwise
     */
    public virtual Boolean hasNext() {
      return (listIter == null) ? false : listIter.hasNext();
    }

    /**
     * Returns the next element from the collection, or null if none exists.
     * @return the next element, or null if none exists
     */
    public virtual Object next() {
      return (listIter == null) ? null : listIter.next();
    }

    /**
     * Resets the iterator to the initial position.
     * @return the reset iterator
     */
    public virtual Iterator reset() {
      listIter.reset();
      return new MapIterator(listIter);
    }

    /**
     * Gets the current index in the collection.
     * @return the current index
     */
    public virtual Integer getCurrIndex() {
      return listIter.getCurrIndex();
    }

    /**
     * Gets a full deep copy of the underlying collection.
     * @return the deep-copied collection
     */
    public virtual List<Object> getCollection() {
      return listIter.getCollection();
    }

    /**
     * Filters the collection inside the iterator and returns a new iterator with the filtered collection.
     * The source iterator is not changed.
     * @param cb the filter callback
     * @return a new iterator with the filtered collection
     */
    public virtual Iterator filter(FilterCallback cb) {
      return new MapIterator(listIter.filter(cb));
    }

    /**
     * Executes the provided callback for all elements in the iterator.
     * The source iterator is not changed.
     * @param cb the forEach callback
     * @return a new iterator with the modified collection
     */
    public virtual Iterator forEach(ForEachCallback cb) {
      return new MapIterator(listIter.forEach(cb));
    }

    /**
     * Transforms the collection based on the provided callback.
     * The source iterator is not changed.
     * @param cb the map callback
     * @return a new iterator with the transformed collection
     */
    public virtual Iterator transform(MapCallback cb) {
      return new MapIterator(listIter.transform(cb));
    }

    // chain terminator operations
    /**
     * Reduces the collection to a single value based on the provided callback.
     * @param cb the reduce callback
     * @return the reduced value
     */
    public virtual Object reduce(ReduceCallback cb) {
      return listIter.reduce(cb);
    }

    /**
     * Reduces the collection to a single value based on the provided callback and initial accumulator.
     * @param initialAccumulator the initial accumulator
     * @param cb the reduce callback
     * @return the reduced value
     */
    public virtual Object reduce(Object initialAccumulator, ReduceCallback cb) {
      return listIter.reduce(initialAccumulator, cb);
    }

    /**
     * Checks if at least one element in the collection satisfies the provided callback.
     * @param cb the filter callback
     * @return true if at least one element satisfies the callback, false otherwise
     */
    public virtual Boolean some(FilterCallback cb) {
      return listIter.some(cb);
    }

    /**
     * Checks if all elements in the collection satisfy the provided callback.
     * @param cb the filter callback
     * @return true if all elements satisfy the callback, false otherwise
     */
    public virtual Boolean every(FilterCallback cb) {
      return listIter.every(cb);
    }
  }
}
