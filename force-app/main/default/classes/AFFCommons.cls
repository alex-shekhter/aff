/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Abstract class that contains common methods and classes. For example universal
 * HashBuilder
 */
public inherited sharing abstract class AFFCommons {
  /**
   * The HashBuilder class is responsible for generating a hash code for objects.
   */
  public inherited sharing class HashBuilder {
    // Starting hash value, using 7 as per Java's convention.
    private Integer hash = 7;

    /**
     * Method to retrieve the current hash code.
     * @return The current hash code.
     */
    public Integer hashCode() {
      return hash;
    }

    /**
     * Adds an object to the hash calculation and returns the HashBuilder instance for chaining.
     * If the object is null, it uses a default value of 0 in the hash code calculation.
     * Otherwise, it uses the hashCode of the object.
     * @param o The object to be added to the hash calculation.
     * @return The HashBuilder instance for method chaining.
     */
    public HashBuilder add(Object o) {
      hash = 31 * hash + (o == null ? 0 : o.hashCode());
      return this;
    }
  }

  /**
   * The HashBuilderCached class is a cached version of HashBuilder,
   * which stores the objects and calculates the hashCode only when needed.
   */
  public inherited sharing class HashBuilderCached {
    private Integer cachedHashCode = null;
    private List<Object> objects = new List<Object>();

    /**
     * Adds an object to the hash calculation list and returns the
     * HashBuilderCached instance for chaining.
     * @param o The object to be added to the hash calculation list.
     * @return The HashBuilderCached instance for method chaining.
     */
    public HashBuilderCached add(Object o) {
      objects.add(o);
      return this;
    }

    /**
     * Clears the cached hashCode and the list of objects to recalculate
     * them later if needed.
     * @return The HashBuilderCached instance for method chaining.
     */
    public HashBuilderCached clear() {
      cachedHashCode = null;
      objects.clear();
      return this;
    }

    /**
     * Method to retrieve the current hash code.
     * If not already calculated, it calculates it by creating a new
     * HashBuilder instance and adding all stored objects to it.
     * @return The current hash code.
     */
    public Integer hashCode() {
      if (cachedHashCode == null) {
        HashBuilder hb = new HashBuilder();
        for (Object o : objects) {
          hb.add(o);
        }
        cachedHashCode = hb.hashCode();
      }
      return cachedHashCode;
    }
  }

  /**
   * Get object type as String using TypeException output. Heavy, but reliable.
   *
   * Code taken from:
   *  https://salesforce.stackexchange.com/questions/23998/return-name-of-class-from-instance-of-that-class
   *
   * @param Object
   * @return type of the Apex instance as String
   */
  public static String getObjectType(Object obj) {
    String result = 'DateTime';
    try {
      DateTime typeCheck = (DateTime) obj;
    } catch (System.TypeException te) {
      String message = te.getMessage()
        .substringAfter('Invalid conversion from runtime type ');
      result = message.substringBefore(' to Datetime');
    }

    return result;
  }

  /**
   * Method to retrieve the type of an Apex object from its string representation.
   *
   * Code idea taken from:
   *  https://salesforce.stackexchange.com/questions/23998/return-name-of-class-from-instance-of-that-class
   *
   * @param namespace The namespace of the Apex object
   * @param o The Apex object whose type is to be retrieved.
   * @return The Type of the given Apex object.
   */
  public static Type getTypeForApexObject(String namespace, Object o) {
    if (o == null) {
      throw new IllegalArgumentException('Object cannot be null');
    }

    String objAsString = String.valueOf(o); // only object name without namespace appears here

    // If the object is a custom object, then it will be of the form 'CustomObject__c:Id'
    if (objAsString.contains(':')) {
      objAsString = objAsString.substringBefore(':');
    }

    // Restore namespace.
    if (String.isNotBlank(namespace)) {
      objAsString = namespace + '.' + objAsString;
    }

    Type resType = Type.forName(objAsString);
    if (resType == null) {
      throw new IllegalArgumentException('Invalid object type: ' + objAsString);
    }

    return resType;
  }

  /**
   * Interface for objects that can be cloned.
   */
  public interface Cloneable {
    /**
     * Clones the object.
     * @param deepClone whether to perform a deep clone
     * @return the cloned object
     */
    Object clone(Boolean deepClone);
  }

  /**
   * deep clone of any Apex object. Uses JSON serialization/deserialization.
   *
   * Heavy from the processor time POV. Use with case
   *
   * @param Object to deep clone
   * @return Object - clone of the input
   */
  public static Object deepClone(Object obj) {
    Object res;
    if (obj == null) {
      return null;
    }
    if (obj instanceof SObject) {
      res = ((SObject) obj).clone(true, true, true, true);
    } else if (obj instanceof Cloneable) {
      res = ((Cloneable) obj).clone(true);
    } else if (
      obj instanceOf Integer 
      || obj instanceOf Long
      || obj instanceOf Double
      || obj instanceOf Decimal
      || obj instanceOf String
      || obj instanceOf Boolean
      || obj instanceOf Blob
      || obj instanceOf Date
      || obj instanceOf Datetime
      || obj instanceOf Time
      || obj instanceOf ID
    ) {
      res = obj;
    }
    else {
      res = JSON.deserialize(
        JSON.serialize(obj),
        Type.forName(AFFCommons.getObjectType(obj))
      );
    }

    return res;
  }
}
