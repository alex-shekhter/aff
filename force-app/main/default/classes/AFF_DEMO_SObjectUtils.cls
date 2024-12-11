/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * SObject utility class
 *
 *  This abstract class provides utility methods and classes for working with SObjects.
 */
public inherited sharing abstract class AFF_DEMO_SObjectUtils {
  /**
   * Reusable condition to check if an SObject doesn't have an owner set yet.
   *
   * Note: In a real implementation, this should not be part of this class/package.
   */
  public inherited sharing class SObjNoOwnerCondition implements AFFCondition.ObjCondition {
    /**
     * Checks if the given SObject is not null and doesn't have an owner.
     *
     * @param obj The object to check.
     * @return True if the object is not null and doesn't have an owner, false otherwise.
     */
    public Boolean test(Object obj) {
      return (obj != null) ? ((SObject) obj).get('OwnerId') == null : false;
    }
  }

  /**
   * Executors can be used in two paradigms:
   *
   * 1) One loop per Executor:
   *    The Executor instance consumes a collection of objects and loops through them to fulfill its task.
   * 2) One loop calling many Executors:
   *    The Executor's instance `execute` method is called many times to fulfill its task inside an outer loop.
   *    In this case, the Executor should implement the `AFFBase.DataSetter` method to set the object it should process
   *    and optionally `AFFBase.DataGetter` to get the processed object.
   */

  /**
   * Executor to set an SObject's owner if this SObject instance doesn't have one yet.
   *
   * Paradigm 1: One loop per Executor
   *
   * The Executor instance consumes a collection of objects and loops through them to fulfill its task.
   *
   * @see AFFBase.Executor
   */
  public inherited sharing class SObjOwnerSetter_1 implements AFFBase.Executor {
    private List<SObject> sobjs;
    private Id ownerId;
    private AFFCondition.ObjCondition cond = (AFFCondition.ObjCondition) AFFSingleton.getInstance(
      SObjNoOwnerCondition.class
    );

    /**
     * Constructor. Sets the owner to the current user.
     *
     * @param sobjs The list of SObjects to be processed.
     */
    public SObjOwnerSetter_1(List<SObject> sobjs) {
      this.sobjs = sobjs;
      this.ownerId = UserInfo.getUserId();
    }

    /**
     * Constructor. Sets the owner to the specified user.
     *
     * @param ownerId The Id of the owner to be used.
     * @param sobjs The list of SObjects to be processed.
     */
    public SObjOwnerSetter_1(ID ownerId, List<SObject> sobjs) {
      this.sobjs = sobjs;
      this.ownerId = ownerId;
    }

    /**
     * Executes the task of setting the owner for SObjects that don't have an owner.
     */
    public void execute() {
      for (SObject o : sobjs) {
        if (cond.test(o)) {
          o.put('OwnerId', ownerId);
        }
      }
    }
  }

  /**
   * Executor to set an SObject's owner if this SObject instance doesn't have one yet.
   *
   * Paradigm 2: One loop calling many Executors
   *
   * The Executor's instance `execute` method is called many times to fulfill its task inside an outer loop.
   *
   * @see AFFBase.Executor
   * @see AFFBase.DataGetter
   * @see AFFBase.DataSetter
   */
  public inherited sharing class SObjOwnerSetter_2 implements AFFBase.Executor, AFFBase.DataGetter, AFFBase.DataSetter {
    private Id ownerId;
    private AFFCondition.ObjCondition cond = (AFFCondition.ObjCondition) AFFSingleton.getInstance(
      SObjNoOwnerCondition.class
    );
    private SObject sobj;

    /**
     * Constructor. Sets the owner to the current user.
     */
    public SObjOwnerSetter_2() {
      this.ownerId = UserInfo.getUserId();
    }

    /**
     * Constructor. Sets the owner to the specified user.
     *
     * @param ownerId The Id of the owner to be used.
     */
    public SObjOwnerSetter_2(ID ownerId) {
      this.ownerId = ownerId;
    }

    /**
     * Sets the data (SObject) to be processed.
     *
     * @param o The SObject to be processed.
     */
    public AFFBase.DataSetter setData(Object o) {
      this.sobj = (SObject) o;
      return this;
    }

    /**
     * Gets the data (SObject) that was processed.
     *
     * @return The processed SObject.
     */
    public Object getData() {
      return sobj;
    }

    /**
     * Executes the task of setting the owner for the SObject if it doesn't have an owner.
     */
    public void execute() {
      if (cond.test(sobj)) {
        sobj.put('OwnerId', ownerId);
      }
    }
  }
}
