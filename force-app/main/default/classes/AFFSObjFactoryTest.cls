/**
 * Testing the use of AFFSObjFactory
 */
@isTest
private class AFFSObjFactoryTest {
  /**
   * Test the use of AFFSObjFactory.StandardFactory to create an Account with default field values
   */
  @isTest
  private static void testStandardFactoryDefaultFieldValues() {
    // setup
    Schema.SObjectType sobjType = Schema.Account.SObjectType;
    List<String> fields = new List<String>{ 'Name', 'Industry' };
    Map<String, AFFSObjFactory.FieldSetter> fieldSettersByFieldName = new Map<String, AFFSObjFactory.FieldSetter>();

    // execute
    Test.startTest();
    AFFSObjFactory.StandardFactory sut = new AFFSObjFactory.StandardFactory(
      sobjType,
      fields,
      fieldSettersByFieldName
    );
    SObject o = sut.create();
    Test.stopTest();

    // assert
    System.assert(
      o.getSObjectType() == sobjType,
      'Expected sobjType to be set to Account'
    );
    System.assert(
      o.get('Name') == Account.Name.getDescribe().getDefaultValue(),
      'Expected Name field to be default value: \'' +
        Account.Name.getDescribe().getDefaultValue() +
        '\''
    );
    System.assert(
      o.get('Industry') == Account.Industry.getDescribe().getDefaultValue(),
      'Expected Industry field to be default value: \'' +
        Account.Industry.getDescribe().getDefaultValue() +
        '\''
    );
  }

  private static final String ACC_NAME_PREFIX = 'Test Account_';

  private class AccountNameFieldSetter implements AFFSObjFactory.FieldSetter {
    private Integer counter = 1;

    public void setValue(SObject o, String fieldName) {
      o.put('Name', ACC_NAME_PREFIX + counter++);
    }
  }

  /**
   * Test the use of AFFSObjFactory.StandardFactory to create an Account with FieldSetters
   */
  @isTest
  private static void testStandardFactoryWithFieldSetters() {
    // setup
    Schema.SObjectType sobjType = Schema.Account.SObjectType;
    List<String> fields = new List<String>{ 'Name', 'Industry' };
    Map<String, AFFSObjFactory.FieldSetter> fieldSettersByFieldName = new Map<String, AFFSObjFactory.FieldSetter>{
      'Name' => new AccountNameFieldSetter()
    };

    // execute
    Test.startTest();
    AFFSObjFactory.StandardFactory sut = new AFFSObjFactory.StandardFactory(
      sobjType,
      fields,
      fieldSettersByFieldName
    );
    SObject o = sut.create();
    Test.stopTest();

    // assert
    System.assert(
      o.getSObjectType() == sobjType,
      'Expected sobjType to be set to Account'
    );
    System.assert(
      o.get('Name') == 'Test Account_1',
      'Expected Name field to be = \'Test Account_1\''
    );
    System.assert(
      o.get('Industry') == Account.Industry.getDescribe().getDefaultValue(),
      'Expected Industry field to be default value: \'' +
        Account.Industry.getDescribe().getDefaultValue() +
        '\''
    );
  }

  /**
   * Apply Field Level Security during SObject Factory creation
   */
  @IsTest
  private static void testStandardFactoryWithFieldLevelSecurity() {
    // setup
    Schema.SObjectType sobjType = Schema.Account.SObjectType;
    List<String> fields = new List<String>{ 'Name', 'Industry' };
    Map<String, AFFSObjFactory.FieldSetter> fieldSettersByFieldName = new Map<String, AFFSObjFactory.FieldSetter>{
      'Name' => new AccountNameFieldSetter()
    };

    // execute
    Test.startTest();
    AFFSObjFactory.StandardFactory sut = new AFFSObjFactory.StandardFactory(
        sobjType,
        fields,
        fieldSettersByFieldName
      )
      .applyFieldLevelSecurity(
        new List<AFFSObjFactory.FieldLevelSecurity>{
          AFFSObjFactory.FieldLevelSecurity.FLS_CREATE,
          AFFSObjFactory.FieldLevelSecurity.FLS_READ,
          AFFSObjFactory.FieldLevelSecurity.FLS_WRITE
        }
      );

    SObject o = sut.create();
    Test.stopTest();

    // assert
    System.assert(
      o.getSObjectType() == sobjType,
      'Expected sobjType to be set to Account'
    );
    System.assert(
      o.get('Name') == 'Test Account_1',
      'Expected Name field to be = \'Test Account_1\''
    );
    System.assert(
      o.get('Industry') == Account.Industry.getDescribe().getDefaultValue(),
      'Expected Industry field to be default value: \'' +
        Account.Industry.getDescribe().getDefaultValue() +
        '\''
    );
  }

  /**
   * Tests that we throw AFFSobjFactory.WrongFieldException if unknown field is requested
   */
  @IsTest
  private static void testStandardFactoryWrongFieldException() {
    // setup
    Schema.SObjectType sobjType = Schema.Account.SObjectType;
    List<String> fields = new List<String>{
      'Name',
      'Industry',
      'UnknowField_QQQ__c'
    };
    Map<String, AFFSObjFactory.FieldSetter> fieldSettersByFieldName = new Map<String, AFFSObjFactory.FieldSetter>();

    // execute
    Test.startTest();
    try {
      AFFSObjFactory.StandardFactory sut = new AFFSObjFactory.StandardFactory(
        sobjType,
        fields,
        fieldSettersByFieldName
      );
      System.assert(
        false,
        'Expected WrongFieldException to be thrown'
      );
    } catch (AFFSObjFactory.WrongFieldException e) {
      System.assert(true, 'Caught expected WrongFieldException: ' + e.getMessage());
    }
    Test.stopTest();
  }
}
