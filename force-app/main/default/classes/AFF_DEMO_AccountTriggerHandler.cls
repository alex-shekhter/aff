/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Example of the Account Trigger Handler with the ability to enable/disable
 * the whole trigger and also other features using configuration or programmatically.
 */
@SuppressWarnings('PMD.ExcessiveParameterList')
public inherited sharing class AFF_DEMO_AccountTriggerHandler implements AFFBase.Executor {
  /**
   * This constant is used to enable/disable the real-time logic in the Account trigger,
   * allowing us to quickly enable/disable the whole trigger logic.
   */
  public static final AFFBase.Category FEATURE_ACCOUNT_REALTIME_LOGIC = new AFFBase.SimpleCategoryImpl(
    'FEATURE_ACCOUNT_REALTIME_LOGIC'
  );

  /**
   * Constants below are used to enable/disable various functionalities in our demo.
   */
  public static final AFFBase.Category FEATURE_AUTOASSIGN_ACC_OWNER = new AFFBase.SimpleCategoryImpl(
    'FEATURE_AUTOASSIGN_ACC_OWNER'
  );
  public static final AFFBase.Category FEATURE_AUTOASSIGN_TASK_2_ACC = new AFFBase.SimpleCategoryImpl(
    'FEATURE_AUTOASSIGN_TASK_2_ACC'
  );
  public static final AFFBase.Category FEATURE_ACC_RATING = new AFFBase.SimpleCategoryImpl(
    'FEATURE_ACC_RATING'
  );

  /**
   * This class is used to hold the configuration of all features.
   */
  public static final AFFFeatureCtrl.FeatureConfig FEATURE_CFG = new AFFFeatureCtrl.FeatureConfigImpl();

  private List<Account> newAccounts;
  private List<Account> oldAccounts;
  private Map<Id, Account> newAccountsMap;
  private Map<Id, Account> oldAccountsMap;
  private AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr = new AFFFeatureCtrl.FeatureConfigMgr(
    FEATURE_CFG
  );

  /**
   * Constructor to initialize the handler with new and old Account records and their maps.
   *
   * @param newAccounts List of new Account records.
   * @param newAccountsMap Map of new Account records.
   * @param oldAccounts List of old Account records.
   * @param oldAccountsMap Map of old Account records.
   */
  public AFF_DEMO_AccountTriggerHandler(
    List<Account> newAccounts,
    List<Account> oldAccounts,
    Map<Id, Account> newAccountsMap,
    Map<Id, Account> oldAccountsMap
  ) {
    this.newAccounts = newAccounts;
    this.oldAccounts = oldAccounts;
    this.newAccountsMap = newAccountsMap;
    this.oldAccountsMap = oldAccountsMap;
  }

  /**
   * Abstract class to handle common trigger event logic.
   */
  private inherited sharing abstract class TriggerEventAbs implements AFFBase.Executor {
    protected AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr;

    protected List<Account> newAccounts;
    protected List<Account> oldAccounts;
    protected Map<Id, Account> newAccountsMap;
    protected Map<Id, Account> oldAccountsMap;

    /**
     * Constructor to initialize the trigger event with feature configuration manager and Account records.
     *
     * @param featureConfigMgr Feature configuration manager.
     * @param newAccounts List of new Account records.
     * @param oldAccounts List of old Account records.
     * @param newAccountsMap Map of new Account records.
     * @param oldAccountsMap Map of old Account records.
     */
    public TriggerEventAbs(
      AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr,
      List<Account> newAccounts,
      List<Account> oldAccounts,
      Map<Id, Account> newAccountsMap,
      Map<Id, Account> oldAccountsMap
    ) {
      this.featureConfigMgr = featureConfigMgr;
      this.newAccounts = newAccounts;
      this.oldAccounts = oldAccounts;
      this.newAccountsMap = newAccountsMap;
      this.oldAccountsMap = oldAccountsMap;
    }
  }

  /**
   * Class to handle logic before inserting Account records.
   */
  private inherited sharing class BeforeInsertExecutor extends TriggerEventAbs {
    /**
     * Constructor to initialize the before insert executor with feature configuration manager and new Account records.
     *
     * @param featureConfigMgr Feature configuration manager.
     * @param newAccounts List of new Account records.
     */
    public BeforeInsertExecutor(
      AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr,
      List<Account> newAccounts
    ) {
      super(featureConfigMgr, newAccounts, null, null, null);
    }

    /**
     * Executes the logic before inserting Account records.
     */
    public void execute() {

      // Add executors for auto-assigning account owner and account rating
      featureConfigMgr.addExecutor(
          FEATURE_AUTOASSIGN_ACC_OWNER,
          new AFF_DEMO_SObjectUtils.SObjOwnerSetter_1(newAccounts)
        )
        .addExecutor(
          FEATURE_ACC_RATING,
          new AFF_DEMO_AccountLogic.AccountRankingProcessorWithLoop(
            newAccounts,
            null
          )
        )
        .execute();
    }
  }

  /**
   * Class to handle logic after inserting Account records.
   */
  private inherited sharing class AfterInsertExecutor extends TriggerEventAbs {
    private AFFDml.ChangeUnit changeUnit = new AFFDml.DefaultChangeUnitImpl(
      AFFDml.AccessMode.USER_MODE
    );

    /**
     * Constructor to initialize the after insert executor with feature configuration
     * manager and new Account records.
     *
     * @param featureConfigMgr Feature configuration manager.
     * @param newAccounts List of new Account records.
     */
    public AfterInsertExecutor(
      AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr,
      List<Account> newAccounts
    ) {
      super(featureConfigMgr, newAccounts, null, null, null);
    }

    /**
     * Executes the logic after inserting Account records.
     */
    public void execute() {
      // Add executor for auto-assigning tasks to new accounts
      featureConfigMgr.addExecutor(
          FEATURE_AUTOASSIGN_TASK_2_ACC,
          new AFF_DEMO_AccountLogic.TaskCreatorForNewAccountsWithLoop(
            newAccounts,
            changeUnit
          )
        )
        .execute();

      // Save changes
      changeUnit.applyChange();
    }
  }

  /**
   * Class to handle logic before updating Account records.
   */
  private inherited sharing class BeforeUpdateExecutor extends TriggerEventAbs {
    /**
     * Constructor to initialize the before update executor with feature configuration manager,
     * new and old Account records.
     *
     * @param featureConfigMgr Feature configuration manager.
     * @param newAccounts List of new Account records.
     * @param oldAccounts List of old Account records.
     */
    public BeforeUpdateExecutor(
      AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr,
      List<Account> newAccounts,
      List<Account> oldAccounts
    ) {
      super(featureConfigMgr, newAccounts, oldAccounts, null, null);
    }

    /**
     * Executes the logic before updating Account records.
     */
    public void execute() {
      
      featureConfigMgr.addExecutor(
          FEATURE_ACC_RATING,
          new AFF_DEMO_AccountLogic.AccountRankingProcessorWithLoop(
            newAccounts,
            new Map<Id, Account>(oldAccounts)
          )
        )
        .execute();
    }
  }

  /**
   * Executes the appropriate trigger logic based on the trigger event.
   */
  public void execute() {
    // Is triigger enabled?
    if ( !featureConfigMgr.isEnabled( FEATURE_ACCOUNT_REALTIME_LOGIC) ) {
      return;
    }

    (new AFFTrigger.TriggerExecutionManager())
      .addExecutor(
        AFFTrigger.BEFORE_INS_TRG,
        new BeforeInsertExecutor(featureConfigMgr, newAccounts)
      )
      .addExecutor(
        AFFTrigger.AFTER_INS_TRG,
        new AfterInsertExecutor(featureConfigMgr, newAccounts)
      )
      .addExecutor(
        AFFTrigger.BEFORE_UPD_TRG,
        new BeforeUpdateExecutor(featureConfigMgr, newAccounts, oldAccounts)
      )
      .execute();
  }
}
