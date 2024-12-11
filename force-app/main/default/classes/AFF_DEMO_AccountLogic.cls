/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Demo code related to the Account object.
 */
public inherited sharing abstract class AFF_DEMO_AccountLogic {

  /**
   * Inner class to create a Task for each Account.
   * Implements the AFFIter.MapCallback interface.
   */
  public inherited sharing class AccountToTaskCallback implements AFFIter.MapCallback {
    /**
     * Implementation of the callback.
     *
     * @param obj - Current item from the source collection.
     * @param i - Current position in the source collection.
     * @param arr - Current source collection.
     * @return Task - A new Task object associated with the Account.
     */
    public Object execute(Object obj, Integer i, List<Object> arr) {
      Account acc = (Account) obj;
      return new Task(
        WhatId = acc.Id,
        Subject = 'Follow up with new account',
        ActivityDate = Date.today().addDays(7),
        Status = 'Not Started'
      );
    }
  }

  /**
   * Executor class to create a new Task for every new Account.
   * Implements the AFFBase.Executor interface.
   * Paradigm 1: One loop per executor.
   */
  public inherited sharing class TaskCreatorForNewAccountsWithLoop implements AFFBase.Executor {
    AFFIter.Iterator iter; // Iterator for Task[]
    AFFDml.ChangeUnit changeUnit;

    /**
     * Constructor to initialize the iterator and change unit.
     *
     * @param accs - List of Account objects.
     * @param changeUnit - Change unit for DML operations.
     */
    public TaskCreatorForNewAccountsWithLoop(
      List<Account> accs,
      AFFDml.ChangeUnit changeUnit
    ) {
      // Initialize the iterator with the Account list and transform it using AccountToTaskCallback
      this.iter = (new AFFIter.ListIterator(accs))
        .transform(new AccountToTaskCallback());
      this.changeUnit = changeUnit;
      if (this.changeUnit == null) {
        throw new IllegalArgumentException('ChangeUnit is required');
      }
    }

    /**
     * Execute method to add new Tasks to the ChangeUnit, so we can save changes later
     */
    public void execute() {
      List<Task> tasks = new List<Task>();
      while (iter.hasNext()) {
        tasks.add((Task) iter.next());
      } 
      changeUnit.setDmlType(AFFDml.T_INSERT)
        .addRecords( tasks );
    }
  }

  /**
   * Executor class to create a new Task for each new Account.
   * Implements the AFFBase.Executor, AFFBase.DataSetter, and AFFBase.DataGetter interfaces.
   * Paradigm 2: This executor is to be used inside the loop or iterator.
   */
  public inherited sharing class TaskCreatorForNewAccountInLoop implements AFFBase.Executor, AFFBase.DataSetter, AFFBase.DataGetter {
    private AFFDml.ChangeUnit changeUnit;
    private AccountToTaskCallback accToTask = new AccountToTaskCallback();
    private Task task;

    /**
     * Constructor to initialize the change unit.
     *
     * @param changeUnit - Change unit to collect changes to be saved later.
     */
    public TaskCreatorForNewAccountInLoop(AFFDml.ChangeUnit changeUnit) {
      this.changeUnit = changeUnit;
      if (this.changeUnit == null) {
        throw new IllegalArgumentException('ChangeUnit is required');
      }
    }

    /**
     * Set data method to set the Task object.
     *
     * @param o - Object to be transformed into a Task.
     * @return The executor. in our case we will be able to chain even with other executors.
     */
    public AFFBase.DataSetter setData(Object o) {
      this.task = (Task) (accToTask.execute(o, null, null));
      return this;
    }

    /**
     * Get data method to retrieve the Task object.
     *
     * @return Task - The Task object.
     */
    public Object getData() {
      return this.task;
    }

    /**
     * Execute method to add changed data to the changeUnit.
     */
    public void execute() {
      changeUnit.setDmlType(AFFDml.T_INSERT).addRecord(this.task);
    }
  }

  /**
   * Executor class to process Account ranking.
   * Implements the AFFBase.Executor interface.
   */
  public inherited sharing class AccountRankingProcessorWithLoop implements AFFBase.Executor {
    private List<Account> accs;
    private Map<Id, Account> oldAccsMap;
    private AccountRankUpdater rankUpdater;

    /**
     * Constructor to initialize the Account list and old Account map.
     *
     * @param accs - List of Account objects.
     * @param oldAccsMap - Map of old Account objects.
     */
    public AccountRankingProcessorWithLoop(
      List<Account> accs,
      Map<Id, Account> oldAccsMap
    ) {
      this.accs = accs;
      this.oldAccsMap = oldAccsMap;
      rankUpdater = new AccountRankUpdater(oldAccsMap);
    }

    /**
     * Execute method to process each Account and update its ranking.
     */
    public void execute() {
      for (Account acc : accs) {
        rankUpdater.execute(acc, null, null);
      }
    }
  }

  /**
   * Inner class to update the ranking of Accounts.
   * Implements the AFFIter.ForEachCallback interface.
   */
  public inherited sharing class AccountRankUpdater implements AFFIter.ForEachCallback {
    private Map<Id, Account> oldAccsMap;

    /**
     * Constructor to initialize the old Account map.
     *
     * @param oldAccsMap - Map of old Account objects.
     */
    public AccountRankUpdater(Map<Id, Account> oldAccsMap) {
      this.oldAccsMap = oldAccsMap;
    }

    /**
     * Execute method to update the ranking of an Account.
     *
     * @param obj - Current item from the source collection.
     * @param i - Current position in the source collection.
     * @param arr - Current source collection.
     */
    public void execute(Object obj, Integer i, List<Object> arr) {
      Account acc = (Account) obj;
      Account oldAcc = oldAccsMap?.get(acc.Id);
      // Update Account Rating (store it in the Type field for demo purposes)
      final Boolean isOldAndChanged = oldAcc != null && oldAcc.AnnualRevenue != acc.AnnualRevenue;
      final Boolean isNew = oldAcc == null && acc != null;
      if ( isNew || isOldAndChanged ) {
        if (acc.AnnualRevenue > 1000000) {
          acc.Type = 'Hot';
        } else if (acc.AnnualRevenue > 500000) {
          acc.Type = 'Warm';
        } else {
          acc.Type = 'Cold';
        }
      }
    }
  }
}
