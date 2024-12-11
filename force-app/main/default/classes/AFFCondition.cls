/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * This abstract class and its interfaces are designed to facilitate
 * the reuse of different conditions during development. It provides
 * a standardized way to define and test conditions on objects and their instances.
 */
public inherited sharing abstract class AFFCondition {
  /**
   * Interface for defining a condition that can be applied to an object.
   */
  public interface ObjCondition {
    /**
     * Tests whether the given object satisfies the condition.
     * @param o The object to test.
     * @return true if the object satisfies the condition, false otherwise.
     */
    Boolean test(Object o);
  }

  /**
   * Interface for defining a condition that can be applied to an instance of an object.
   * This interface extends AFFBase.DataSetter to allow setting the instance.
   */
  public interface InstCondition extends AFFBase.DataSetter {
    /**
     * Tests whether the current instance of the object satisfies the condition.
     * @return true if the object instance satisfies the condition, false otherwise.     
     */
    Boolean test();
  }
}
