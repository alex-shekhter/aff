/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * This class is used to mock DML operations in unit tests.
 * It provides a simple way to simulate insert, update, upsert, and delete operations on SObjects.
 */
public inherited sharing abstract class AFFMockDml {
  private static MockIdGenerator mockIdGenInstance = new MockIdGeneratorImpl();

  /**
   * Returns the instance of the mock Id generator.
   * This can be used to generate fake Ids for SObjects in the mock data.
   *
   * @return The mock Id generator instance.
   */
  public static MockIdGenerator getMockIdGenInstance() {
    return mockIdGenInstance;
  }

  /**
   * Interface for the mock Id generator.
   * This can be implemented to provide a custom way of generating fake Ids for SObjects.
   */
  public interface MockIdGenerator {
    /**
     * Generates a fake Id for the given SObject type.
     *
     * @param objType The SObject type.
     * @return The fake Id.
     */
    Id getMockId(Schema.SObjectType objType);
  }

  /**
   * Default implementation of the mock Id generator.
   * This generates fake Ids by incrementing a counter and using the key prefix of the SObject type.
   */
  private inherited sharing class MockIdGeneratorImpl implements MockIdGenerator {
    private Integer idCount = 0;
    // Lazy initializable map for keyPrefixes
    private Map<Schema.SObjectType, String> objType2IdPrefix = new Map<Schema.SObjectType, String>();

    /**
     * Generates a fake Id for the given SObject type.
     *
     * @param objType The SObject type.
     * @return The fake Id.
     */
    public Id getMockId(Schema.SObjectType objType) {
      String keyPrefix = objType2IdPrefix.get(objType);
      if (keyPrefix == null) {
        Schema.DescribeSObjectResult dor = objType.getDescribe();
        keyPrefix = dor.getKeyPrefix();
        objType2IdPrefix.put(objType, keyPrefix);
      }

      return Id.valueOf(keyPrefix + String.valueOf(idCount++).leftPad(12, '0'));
    }
  }

  /**
   * Default implementation of the ChangeUnit mock.
   * This mock does not actually perform any DML operations, but it can be used to generate fake Ids for SObjects.
   */
  public inherited sharing virtual class ChangeUnitMock extends AFFDml.DefaultChangeUnitImpl {
    /**
     * Default mock constructor
     */
    public ChangeUnitMock() {
      super(null);
    }

    /**
     * Applies the insert DML operation for the associated data list.
     *
     * @param data The list of SObjects to insert.
     */
    protected override void insertData(List<SObject> data) {
      for (SObject obj : data) {
        obj.Id = getMockIdGenInstance().getMockId(obj.getSObjectType());
      }
    }

    /**
     * Applies the update DML operation for the associated data list.
     *
     * @param data The list of SObjects to update.
     */
    protected override void updateData(List<SObject> data) {
      return;
    }

    /**
     * Applies the upsert DML operation for the associated data list.
     *
     * @param data The list of SObjects to upsert.
     */
    protected override void upsertData(List<SObject> data) {
      for (SObject obj : data) {
        if (String.isBlank(obj.Id)) {
          obj.Id = getMockIdGenInstance().getMockId(obj.getSObjectType());
        }
      }
    }

    /**
     * Applies the delete DML operation for the associated data list.
     *
     * @param data The list of SObjects to delete.
     */
    protected override void deleteData(List<SObject> data) {
      return;
    }
  }
}
