@isTest
public class AFF_DEMO_AccountLogicTest {
  /**
   * Test method for the execute method in AccountToTaskCallback.
   */
  @isTest
  static void testAccountToTaskCallback() {
    // Create a test Account
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;
    // Create an instance of AccountToTaskCallback
    AFF_DEMO_AccountLogic.AccountToTaskCallback callback = new AFF_DEMO_AccountLogic.AccountToTaskCallback();
    // Execute the callback
    Task resultTask = (Task) callback.execute(
      testAccount,
      0,
      new List<Object>()
    );
    // Verify the Task fields
    System.assertEquals(
      testAccount.Id,
      resultTask.WhatId,
      'testAccount.Id == resultTask.WhatId'
    );
    System.assertEquals(
      'Follow up with new account',
      resultTask.Subject,
      'Subject == \'Follow up with new account\''
    );
    System.assertEquals(
      Date.today().addDays(7),
      resultTask.ActivityDate,
      'ActivityDate == Date.today().addDays(7)'
    );
    System.assertEquals(
      'Not Started',
      resultTask.Status,
      'Status == \'Not Started\''
    );
  }

  /**
   * Test method for the execute method in TaskCreatorForNewAccountsWithLoop.
   */
  @isTest
  static void testTaskCreatorForNewAccountsWithLoop() {
    // Create test Accounts
    List<Account> testAccounts = new List<Account>{
      new Account(Name = 'Test Account 1'),
      new Account(Name = 'Test Account 2')
    };
    insert testAccounts;
    // Create a ChangeUnit for DML operations
    AFFDml.ChangeUnit changeUnit;
    AFF_DEMO_AccountLogic.TaskCreatorForNewAccountsWithLoop taskCreator;

    try {
      taskCreator = new AFF_DEMO_AccountLogic.TaskCreatorForNewAccountsWithLoop(
        testAccounts, changeUnit
      );
      System.Assert( false, 'We should not be here');
    }
    catch (IllegalArgumentException e) {
      System.Assert( true, 'IllegalArgumentException e.getMessage() = ' + e.getMessage() );
    }

    changeUnit = new AFFDml.DefaultChangeUnitImpl( AFFDml.AccessMode.USER_MODE);
    // Create an instance of TaskCreatorForNewAccountsWithLoop
    taskCreator = new AFF_DEMO_AccountLogic.TaskCreatorForNewAccountsWithLoop(
      testAccounts,
      changeUnit
    );

    // Execute the task creation
    taskCreator.execute();
    changeUnit.applyChange();

    // Verify that the tasks were created
    List<Task> tasks = [
      SELECT WhatId, Subject, ActivityDate, Status
      FROM Task
      WHERE WhatId IN :testAccounts
    ];

    System.assertEquals(2, tasks.size(), 'tasks.size() == 2');

    for (Task task : tasks) {
      System.assertEquals(
        'Follow up with new account',
        task.Subject,
        'Subject == \'Follow up with new account\''
      );
      System.assertEquals(
        Date.today().addDays(7),
        task.ActivityDate,
        'ActivityDate == Date.today().addDays(7)'
      );
      System.Assert(task.WhatId != null, 'task.WhatId != null');
      System.assertEquals(
        'Not Started',
        task.Status,
        'Status == \'Not Started\''
      );
    }
  }

  /**
   * Test class for TaskCreatorForNewAccountInLoop.
   */
  @isTest
  static void testTaskCreatorForNewAccountInLoop() {
    // Create a test Account
    Account testAccount = new Account(Name = 'Test Account');
    insert testAccount;

    // Test illegal exception
    AFFDml.ChangeUnit changeUnit;

    AFF_DEMO_AccountLogic.TaskCreatorForNewAccountInLoop taskCreator;
    
    try {
      taskCreator = 
      new AFF_DEMO_AccountLogic.TaskCreatorForNewAccountInLoop( changeUnit);
      System.assert( false, 'We should not be here');
    }
    catch (IllegalArgumentException e) {
      System.assert( true, 'IllegalArgumentException e.getMessage() = ' + e.getMessage() );
      changeUnit = new AFFDml.DefaultChangeUnitImpl( AFFDml.AccessMode.USER_MODE );
      taskCreator = new AFF_DEMO_AccountLogic.TaskCreatorForNewAccountInLoop( changeUnit);
    }
    
    // Set the data for the task
    taskCreator.setData(testAccount);
    // Execute the task creation
    taskCreator.execute();

    // Check that task has been created
    Task taskBeforeInsert = (Task)taskCreator.getData();
    System.assert( taskBeforeInsert.Id == null, 'taskBeforeInsert.Id == null' + taskBeforeInsert.Id);
    System.Assert(
      taskBeforeInsert.WhatId != null,
      'taskBeforeInsert.WhatId != null' + taskBeforeInsert.WhatId + ' ' + testAccount.Id
    );

    changeUnit.applyChange();

    // Verify that the task was created
    Task task = [
      SELECT WhatId, Subject, ActivityDate, Status
      FROM Task
      WHERE WhatId = :testAccount.Id
      LIMIT 1
    ];
    System.assertEquals(
      'Follow up with new account',
      task.Subject,
      'Subject == \'Follow up with new account\''
    );
    System.assertEquals(
      Date.today().addDays(7),
      task.ActivityDate,
      'ActivityDate == Date.today().addDays(7)'
    );
    System.Assert(
      task.WhatId != null,
      'task.WhatId != null' + task.WhatId + ' ' + testAccount.Id
    );
    System.assertEquals(
      'Not Started',
      task.Status,
      'Status == \'Not Started\''
    );
  }

  /**
   * Test method for the execute method in AccountRankingProcessorWithLoop.
   */
  @isTest
  static void testAccountRankingProcessorWithLoop() {
    // Create test Accounts
    Account oldAccount = new Account(
      Name = 'Old Account',
      AnnualRevenue = 500000
    );
    insert oldAccount;
    Account newAccount = new Account(
      Id = oldAccount.Id,
      Name = 'New Account',
      AnnualRevenue = 1500000
    );
    // Create a map of old Accounts
    Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
      oldAccount.Id => oldAccount
    };
    // Create an instance of AccountRankingProcessorWithLoop
    // Create an instance of AccountRankingProcessorWithLoop
    List<Account> newAccounts = new List<Account>{ newAccount };
    AFF_DEMO_AccountLogic.AccountRankingProcessorWithLoop rankingProcessor = new AFF_DEMO_AccountLogic.AccountRankingProcessorWithLoop(
      newAccounts,
      oldAccountsMap
    );
    // Execute the ranking processor
    rankingProcessor.execute();
    update newAccount;

    // Verify that the account ranking was updated
    Account updatedAccount = [
      SELECT Id, Type
      FROM Account
      WHERE Id = :newAccount.Id
    ];
    System.assertEquals('Hot', updatedAccount.Type, 'updatedAccount.Type == \'Hot\'');
  }

  /**
   * Test method for the execute method in AccountRankUpdater.
   */
  @isTest
  static void testAccountRankUpdater() {
    // Create test Accounts
    Account oldHotAccount = new Account(
      Name = 'Old Hot Account',
      AnnualRevenue = 1
    );
    Account oldWarmAccount = new Account(
      Name = 'Old Warm Account',
      AnnualRevenue = 1
    );
    Account oldColdAccount = new Account(
      Name = 'Old Cold Account',
      AnnualRevenue = 1
    );
    insert new List<Account> { oldHotAccount, oldWarmAccount, oldColdAccount};

    Map<Id, Account> oldAccountsMap = new Map<Id, Account>{
      oldHotAccount.Id => oldHotAccount,
      oldWarmAccount.Id => oldWarmAccount,
      oldColdAccount.Id => oldColdAccount
    };

    Account newHotAccount = new Account(
      Id = oldHotAccount.Id,
      Name = 'New Hot Account',
      AnnualRevenue = 1500000
    );
    Account newWarmAccount = new Account(
      Id = oldWarmAccount.Id,
      Name = 'New Warm Account',
      AnnualRevenue = 600000
    );
    Account newColdAccount = new Account(
      Id = oldColdAccount.Id,
      Name = 'New Cold Account',
      AnnualRevenue = 15000
    );
    List<Account> newAccounts = new List<Account>{
      newHotAccount, newWarmAccount, newColdAccount
    };

    // Create an instance of AccountRankUpdater
    AFF_DEMO_AccountLogic.AccountRankUpdater rankUpdater = new AFF_DEMO_AccountLogic.AccountRankUpdater(
      oldAccountsMap
    );
    // Execute the rank updater
    for ( Account na : newAccounts) {
      rankUpdater.execute( na, null, null);
    }
    update newAccounts;
    // Verify that the account ranking was updated
    List<Account> updatedAccounts = [
      SELECT Id, Type
      FROM Account
      WHERE Id in :newAccounts
    ];
    for (Account a : updatedAccounts) {
      Boolean isGood = a.Type == 'Hot' || a.Type == 'Warm' || a.Type == 'Cold';
      System.Assert.isTrue(isGood, 'a.Type == \'Hot\' || a.Type == \'Warm\' || a.Type == \'Cold\'');
    }
  }
}
