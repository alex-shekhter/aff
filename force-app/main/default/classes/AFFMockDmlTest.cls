/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * This class is used to test mock DML operations implementation.
 */
@isTest
public class AFFMockDmlTest {
  
  /***
   * Tests the getMockIdGenInstance() method.
   */
  @isTest
  public static void testGetMockIdGenInstance() {
      Test.startTest();
      AFFMockDml.MockIdGenerator mockIdGenInstance = AFFMockDml.getMockIdGenInstance();
      Test.stopTest();
      System.assertNotEquals(
        mockIdGenInstance,
        null,
        'MockIdGenerator instance should not be null'
      );
  }

  /**
   * Test the getMockId() method.
   */
  @isTest
  public static void testGetMockIdForTask() {
    Schema.SObjectType objType = Task.sObjectType;

    Test.startTest();
    Id mockId = AFFMockDml.getMockIdGenInstance().getMockId(objType);
    Test.stopTest();

    System.assertNotEquals(null, mockId, 'MockId should not be null');
    System.assert( mockId.getSObjectType() == Task.sObjectType, 'MockId should be of Task.sObjectType');
  }

  /***
   * Tests the insert method.
   */
  @isTest
  public static void testInsertAccounts() {
    Test.startTest();
    AFFMockDml.ChangeUnitMock chgUnit = new AFFMockDml.ChangeUnitMock();
    chgUnit
      .setDmlType( AFFDml.T_INSERT)
      .addRecord( new Account( Name = 'ABC' ) )
      .applyChange();
    Test.stopTest();

    List<Account> accs = (List<Account>)chgUnit.getRecordsByDmlType( AFFDml.T_INSERT);
    System.assert( 
      accs != null && accs.size() == 1 && accs[0].Id.getSobjectType() == Account.sObjectType, 
      'There should be one Account record inserted'
    );
  }

  /***
   * Tests the upsert method. 
   */
  @isTest
  public static void testUpsertAccounts() {
    Test.startTest();
    AFFMockDml.ChangeUnitMock chgUnit = new AFFMockDml.ChangeUnitMock();
    chgUnit
      .setDmlType( AFFDml.T_UPSERT)
      .addRecord( new Account( Name = 'No ID' ) )
      .addRecord( 
        new Account( 
          Id = AFFMockDml.getMockIdGenInstance().getMockId( Account.sObjectType ),
          Name = 'Yes ID'
        )
      )
      .applyChange();
    Test.stopTest();

    List<Account> accs = (List<Account>)chgUnit.getRecordsByDmlType( AFFDml.T_UPSERT);
    System.assert( 
      accs != null && accs.size() == 2 
      && accs[0].Name == 'No ID'
      && accs[1].Name == 'Yes ID'
      && accs[0].Id.getSobjectType() == Account.sObjectType
      && accs[1].Id.getSobjectType() == Account.sObjectType, 
      'There should be 1 Account record inserted and 1 updated'
    );
  }

}
