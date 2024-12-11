@isTest
public inherited sharing class AFFDmlTest {
  @isTest
  static void testNoDmlTypeSet() {
    Boolean exceptionThrown = false;

    // Apply changes
    Test.startTest();
    try {
      // Create an instance of DefaultChangeUnitImpl with USER_MODE access
      AFFDml.ChangeUnit changeUnit = (new AFFDml.DefaultChangeUnitImpl(
          AFFDml.AccessMode.USER_MODE
        ))
        .addRecord(
          new Account(Name = 'Test Account 1-' + Crypto.getRandomInteger())
        )
        .addRecord(
          new Account(Name = 'Test Account 2-' + Crypto.getRandomInteger())
        )
        .applyChange();
    } catch (AFFDml.BadDataException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(
      exceptionThrown,
      'Expected AFFDml.BadDataException not thrown'
    );
  }

  @isTest
  static void testDmlTypeSetBeforeApply() {
    final Long prefix = Crypto.getRandomLong();
    List<Account> accounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :prefix + '%'
    ];
    System.assert(
      accounts.isEmpty(),
      'We should not have account records here with prefix: ' + prefix
    );

    Boolean exceptionThrown = false;

    // Apply changes
    Test.startTest();
    try {
      // Create an instance of DefaultChangeUnitImpl with USER_MODE access
      AFFDml.ChangeUnit changeUnit = (new AFFDml.DefaultChangeUnitImpl(
          AFFDml.AccessMode.USER_MODE
        ))
        .addRecords(
          new List<Account>{
            new Account(Name = prefix + 'Test Account 1'),
            new Account(Name = prefix + 'Test Account 2')
          }
        )
        .setDmlType(AFFDml.T_INSERT)
        .applyChange();
    } catch (AFFDml.BadDataException e) {
      exceptionThrown = true;
    }
    Test.stopTest();

    System.assert(!exceptionThrown, 'Expected NO AFFDml.BadDataException');
    accounts = [SELECT Id, Name FROM Account WHERE Name LIKE :prefix + '%'];
    System.assert(
      accounts.size() == 2,
      'Expected to have two new accounts here'
    );
  }

  private static void testDmlOpsSepately(AFFDml.AccessMode accessMode) {
    final Long prefix = Crypto.getRandomLong();
    final String insertPrefix = prefix + '_insert_';
    final String updatePrefix = prefix + '_update_';
    final String deletePrefix = prefix + '_delete_';
    final String upsertPrefix = prefix + '_upsert_';

    List<Account> accounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :prefix + '%'
    ];
    System.assert(
      accounts.isEmpty(),
      'We should not have account records here with prefix: ' + prefix
    );

    // Create an instance of DefaultChangeUnitImpl with USER_MODE access
    AFFDml.ChangeUnit changeUnit = (new AFFDml.DefaultChangeUnitImpl(
        accessMode
      ))
      .setDmlType(AFFDml.T_INSERT)
      .addRecord(new Account(Name = insertPrefix + 'Test Account-1'))
      .applyChange();

    accounts = [
      SELECT Id, Name
      FROM Account
      WHERE Name LIKE :insertPrefix + '%'
    ];
    System.assert(
      accounts.size() == 1,
      'Expected to have one new account here'
    );

    List<Account> insertedRecords = changeUnit.getRecordsByDmlType(
      AFFDml.T_INSERT
    );
    insertedRecords[0].Name = updatePrefix + 'Test Account-1';
    changeUnit
      .clearRecordsByDmlType(AFFDml.T_INSERT)
      .setDmlType(AFFDml.T_UPDATE)
      .addRecords(insertedRecords)
      .applyChange();

    accounts = [SELECT Id, Name FROM Account WHERE Name LIKE :prefix + '%'];
    System.assert(
      accounts.size() == 1 && accounts[0].Name.contains(updatePrefix),
      'Expected to have one updated account here'
    );

    changeUnit
      .clearRecordsByDmlType(AFFDml.T_UPDATE)
      .setDmlType(AFFDml.T_DELETE)
      .addRecords(accounts)
      .applyChange();

    accounts = [SELECT Id, Name FROM Account WHERE Name LIKE :prefix + '%'];
    System.assert(
      accounts.size() == 0,
      'Expected to have no account records here with prefix:' + prefix
    );

    changeUnit
      .clearAllRecords()
      .setDmlType(AFFDml.T_UPSERT)
      .addRecord(new Account(Name = upsertPrefix + '_Test Account 2'))
      .applyChange();

    accounts = [SELECT Id, Name FROM Account];
    System.assert(
      accounts.size() == 1 && accounts[0].Name.contains(upsertPrefix),
      'Expected to have one new account here'
    );
  }

  @IsTest
  private static void testDmlOpsSeparatelyAsUser() {
    Test.startTest();
    testDmlOpsSepately(AFFDml.AccessMode.USER_MODE);
    Test.stopTest();

    System.assert(true, '...'); // This is a dummy assertion to make sure the test runs
  }

  @IsTest
  private static void testDmlOpsSeparatelyAsSystem() {
    Test.startTest();
    testDmlOpsSepately(AFFDml.AccessMode.SYSTEM_MODE);
    Test.stopTest();

    System.assert(true, '...'); // This is a dummy assertion to make sure the test runs
  }
}
