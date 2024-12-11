/**
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Test class for AFFFeatureCtrl
 */
@IsTest
public class AFFFeatureCtrlTest {
  /**
   * Initializes the feature configuration records for testing.
   * Note: Custom metadata records cannot be inserted directly in tests.
   * Instead, we use a mock DML approach.
   */
  static List<AFF_Features_Control_Config__mdt> initFeatureConfigs() {
    // Create test data for AFF_Features_Control_Config__mdt
    List<AFF_Features_Control_Config__mdt> featureConfigs = new List<AFF_Features_Control_Config__mdt>();
    featureConfigs.add(
      new AFF_Features_Control_Config__mdt(
        DeveloperName = 'EnableAdvancedReporting',
        FeatureDescription__c = 'Allows users to access advanced reporting features',
        IsEnabled__c = true
      )
    );
    featureConfigs.add(
      new AFF_Features_Control_Config__mdt(
        DeveloperName = 'EnableUserNotifications',
        FeatureDescription__c = 'Enables user notifications for various events',
        IsEnabled__c = false
      )
    );
    AFFDml.ChangeUnit cu = (new AFFMockDml.ChangeUnitMock())
      .addRecords(featureConfigs)
      .setDmlType(AFFDml.T_INSERT)
      .applyChange();

    return cu.getRecordsByDmlType(AFFDml.T_INSERT);
  }

  /**
   * Test the AFFFeatureCtrl.FeatureImpl class
   */
  @IsTest
  static void testFeatureImpl() {
    Test.startTest();

    List<AFF_Features_Control_Config__mdt> featureConfigs = initFeatureConfigs();

    AFF_Features_Control_Config__mdt fc = featureConfigs[0];
    System.Assert.areEqual(fc.DeveloperName, 'EnableAdvancedReporting');

    // Create a FeatureImpl instance
    AFFFeatureCtrl.FeatureImpl feature = new AFFFeatureCtrl.FeatureImpl(fc);
    // Test the description method
    System.assertEquals(
      'Allows users to access advanced reporting features',
      feature.description(),
      'Feature description'
    );

    // Test the isEnabled method
    System.assertEquals(true, feature.isEnabled(), 'Feature is enabled');
    feature.setEnabled(false);
    System.Assert.areEqual(false, feature.isEnabled(), 'Feature is disabled');
    feature.setEnabled(true);
    System.Assert.areEqual(true, feature.isEnabled(), 'Feature is enabled');

    Test.stopTest();
  }

  /**
   * Test the AFFFeatureCtrl.FeatureConfigImpl class
   */
  @IsTest
  static void testFeatureConfigImpl() {
    // Create a FeatureConfigImpl instance
    AFFFeatureCtrl.FeatureConfigImpl featureConfigImpl = new AFFFeatureCtrl.FeatureConfigImpl();

    List<AFF_Features_Control_Config__mdt> featureConfigs = initFeatureConfigs();

    featureConfigImpl.setFeatures(
      new List<AFFFeatureCtrl.Feature>{
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[0]),
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[1])
      }
    );

    // Test the getFeatures method
    List<AFFFeatureCtrl.Feature> features = featureConfigImpl.getFeatures();
    System.assertEquals(2, features.size(), 'Features size');

    // Test the getFeatureByName method
    AFFFeatureCtrl.Feature feature = featureConfigImpl.getFeatureByName(
      'EnableAdvancedReporting'
    );
    System.assertNotEquals(null, feature, 'Expected feature');
    System.assertEquals(
      'Allows users to access advanced reporting features',
      feature.description(),
      'Feature description'
    );

    // Test the setFeature method
    AFF_Features_Control_Config__mdt newFeatureConfig = new AFF_Features_Control_Config__mdt(
      DeveloperName = 'EnableDataExport',
      FeatureDescription__c = 'Allows users to export data to external systems',
      IsEnabled__c = true
    );

    // Note: We cannot insert custom metadata records in tests, so this part is just for demonstration
    // insert newFeatureConfig;
    AFFDml.ChangeUnit cu = (new AFFMockDml.ChangeUnitMock())
      .addRecord(newFeatureConfig)
      .setDmlType(AFFDml.T_INSERT)
      .applyChange();

    AFFFeatureCtrl.FeatureImpl newFeature = new AFFFeatureCtrl.FeatureImpl(
      newFeatureConfig
    );
    featureConfigImpl.setFeature(newFeature);
    AFFFeatureCtrl.Feature retrievedFeature = featureConfigImpl.getFeatureByName(
      'EnableDataExport'
    );
    System.assertNotEquals(null, retrievedFeature, 'Expected feature');
    System.assertEquals(
      'Allows users to export data to external systems',
      retrievedFeature.description(),
      'Feature description'
    );
  }

  /**
   * Class which we will use to control that our executors are working properly.
   */
  private class CtrlVault {
    public Map<String, Object> items = new Map<String, Object>();
  }

  /**
   * Executor for testing
   */
  private class TestExecutor implements AFFBase.Executor {
    private String purpose;
    private CtrlVault vault;

    public TestExecutor(String purpose, CtrlVault vault) {
      this.purpose = purpose;
      this.vault = vault;
    }

    public void execute() {
      vault.items.put(purpose, purpose);
    }
  }

  /**
   * Tests the AFFFeatureCtrl.FeatureConfigMgr class
   */
  @IsTest
  static void testFeatureConfigMgr() {
    List<AFF_Features_Control_Config__mdt> featureConfigs = initFeatureConfigs();

    Test.startTest();

    // Create a FeatureConfigImpl instance
    AFFFeatureCtrl.FeatureConfigImpl featureConfigImpl = new AFFFeatureCtrl.FeatureConfigImpl();
    featureConfigImpl.setFeatures(
      new List<AFFFeatureCtrl.Feature>{
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[0]),
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[1])
      }
    );

    // Create a FeatureConfigMgr instance
    AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr = new AFFFeatureCtrl.FeatureConfigMgr(
      featureConfigImpl
    );
    // Test the isEnabled method
    AFFBase.Category featureCategory = new AFFBase.SimpleCategoryImpl(
      'EnableAdvancedReporting'
    );
    System.assertEquals(
      true,
      featureConfigMgr.isEnabled(featureCategory),
      'Feature is enabled'
    );
    // Test the enableFeature method
    featureConfigMgr.enableFeature(featureCategory, false);
    System.assertEquals(
      false,
      featureConfigMgr.isEnabled(featureCategory),
      'Feature is disabled'
    );

    // We will use it control executions
    CtrlVault vault = new CtrlVault();

    // Test the addExecutor method
    String execPurpose = 'EnableAdvancedReporting::CreateReport';
    AFFBase.Executor executor = new TestExecutor(execPurpose, vault);

    featureConfigMgr.addExecutor(featureCategory, executor);
    featureConfigMgr.executeAllForCategory(featureCategory);
    // Since the feature is disabled, the executor should not be added
    System.assertEquals(
      vault.items.containsKey(execPurpose),
      false,
      'Executor should not be added'
    );
    // Enable the feature and add the executor again
    featureConfigMgr.enableFeature(featureCategory, true);
    System.assertEquals(
      true,
      featureConfigMgr.isEnabled(featureCategory),
      'Executor should not be added'
    );
    featureConfigMgr.addExecutor(featureCategory, executor);
    featureConfigMgr.executeAllForCategory(featureCategory);
    System.assertEquals(
      vault.items.containsKey(execPurpose),
      true,
      'Executor should be added'
    );

    Test.stopTest();
  }

  /**
   * Implementation of the AFFFeatureCtrl.FeatureEnabler interface
   */
  private class FeatureEnablerForDesignatedUser implements AFFFeatureCtrl.FeatureEnabler {
    /**
     * Only the user with the name 'alloweduser@testorg.com' is allowed to have the feature enabled.
     */
    public Boolean isEnabled() {
      return UserInfo.getUserName() == 'alloweduser@testorg.com';
    }
  }

  /**
   * create user using name. Name is splitted by space and used to create user.
   */
  private static User createUser(String name) {
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
    List<String> nameParts = name.split(' ');
    User u = new User(
      FirstName = nameParts[0],
      LastName = nameParts[1],
      ProfileId = p.Id,
      Alias = 'standt',
      Email = name.replaceAll(' ', '') + '@testorg.com',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      UserName = name.replaceAll(' ', '') + '@testorg.com'
    );
    return u;
  }

  /**
   * Test the AFFFeatureCtrl.FeatureConfigImpl class with AFFFeatureCtrl.FeatureEnabler
   *
   * We would like to limit feature access per user. So in this test we will use 2 users,
   * one with advanced reporting enabled, and one with advanced reporting disabled.
   * Then we will create a feature with an executor that prints out some information.
   */
  @IsTest
  static void testFeatureConfigImplWithEnabler() {
    User allowedUser = createUser('Allowed User');

    List<AFF_Features_Control_Config__mdt> featureConfigs = initFeatureConfigs();

    AFFFeatureCtrl.FeatureConfig featureConfigImpl = new AFFFeatureCtrl.FeatureConfigImpl();
    featureConfigImpl.setFeatures(
      new List<AFFFeatureCtrl.Feature>{
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[0]),
        new AFFFeatureCtrl.FeatureImpl(featureConfigs[1])
      }
    );

    AFFFeatureCtrl.FeatureConfigMgr featureConfigMgr = new AFFFeatureCtrl.FeatureConfigMgr(
      featureConfigImpl,
      new List<AFFFeatureCtrl.FeatureEnabler>{
        new FeatureEnablerForDesignatedUser()
      }
    );

    final AFFBase.Category featureCategory = new AFFBase.SimpleCategoryImpl(
      'EnableAdvancedReporting'
    );

    Test.startTest();

    // Assert enablement
    System.assertEquals(
      false,
      featureConfigMgr.isEnabled(featureCategory),
      'Feature is disabled since User.Name is not "alloweduser@testorg.com"'
    );

    CtrlVault vault = new CtrlVault();

    final String execPurpose = 'EnableAdvancedReporting:Only for alloweduser@testorg.com';

    featureConfigMgr.addExecutor(
      featureCategory,
      new TestExecutor(execPurpose, vault)
    );

    // Check execution
    featureConfigMgr.executeAllForCategory(featureCategory);
    System.assertEquals(
      vault.items.containsKey(execPurpose),
      false,
      'Executor should not be executed since User.Name is not "alloweduser@testorg.com": ' +
      UserInfo.getUserName()
    );

    System.runAs(allowedUser) {
      // Assert enablement
      System.assertEquals(
        true,
        featureConfigMgr.isEnabled(featureCategory),
        'Feature is enabled since User.Name should be "alloweduser@testorg.com": ' +
        UserInfo.getUserName()
      );

      // Check execution
      featureConfigMgr.executeAllForCategory(featureCategory);
      System.assertEquals(
        true,
        vault.items.containsKey(execPurpose),
        'Executor should be executed since User.Name is "alloweduser@testorg.com": ' +
          UserInfo.getUserName() +
          '; vault: ' +
          vault
      );
    }

    Test.stopTest();
  }
}
