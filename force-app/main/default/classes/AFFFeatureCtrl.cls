/**
 * AFF - Apex Foundation Framework.
 *
 * Author: Alex Shekhter
 *
 * This Apex code is designed to manage feature control within a Salesforce environment.
 * It includes classes and interfaces to define, manage, and query features that can be
 * enabled or disabled within the system.
 */
public inherited sharing abstract class AFFFeatureCtrl {
  /**
   * Custom exception for unknown features.
   */
  public inherited sharing class UnknownFeatureException extends Exception {
  }

  /**
   * Interface for a single feature.
   *
   * A feature can be explained as a set of functionalities in the system that can be enabled or disabled.
   *
   * A feature is an entity that can be enabled or disabled. It has a description and can be queried by name.
   */
  public interface Feature extends AFFBase.Entity {
    /**
     * Returns the human-readable description of this feature.
     *
     * @return The description, or an empty string if not set.
     */
    String description();

    /**
     * Returns whether this feature is currently enabled.
     *
     * @return True if enabled, false otherwise.
     */
    Boolean isEnabled();

    /**
     * Sets the enabled state of this feature.
     *
     * @param enabled True to enable, false to disable.
     */
    void setEnabled(Boolean enabled);
  }

  /**
   * Class that implements the Feature interface and holds metadata configuration for a single feature.
   */
  public inherited sharing class FeatureImpl extends AFFBase.EntityImpl implements Feature {
    /**
     * The description of this feature.
     */
    private String description;

    /**
     * Whether this feature is currently enabled.
     */
    private Boolean isEnabled;

    /**
     * Constructor to initialize the object with a metadata record for the feature configuration.
     *
     * @param featureConfig The metadata record for the feature configuration.
     */
    public FeatureImpl(AFF_Features_Control_Config__mdt featureConfig) {
      super(featureConfig.DeveloperName);
      this.description = featureConfig.FeatureDescription__c;
      this.isEnabled = featureConfig.IsEnabled__c;
    }

    /**
     * Returns the human-readable description of this feature.
     *
     * @return The description, or an empty string if not set.
     */
    public String description() {
      return description != null ? description : '';
    }

    /**
     * Returns whether this feature is currently enabled.
     *
     * @return True if enabled, false otherwise.
     */
    public Boolean isEnabled() {
      return Boolean.valueOf(isEnabled);
    }

    /**
     * Sets the enabled state of this feature.
     *
     * @param enabled True to enable, false to disable.
     */
    public void setEnabled(Boolean enabled) {
      this.isEnabled = enabled;
    }
  }

  /**
   * Interface for a feature configuration manager.
   *
   * A feature configuration manager is responsible for managing the configurations of features.
   * It can query features by name and update their enabled states.
   */
  public interface FeatureConfig {
    /**
     * Returns an iterable list of all configured features.
     *
     * @return An iterable list of all configured features.
     */
    List<Feature> getFeatures();

    /**
     * Sets the list of configured features.
     *
     * @param features The new list of configured features.
     */
    void setFeatures(List<Feature> features);

    /**
     * Returns a feature by its name, or null if not found.
     *
     * @param name The name of the feature to find.
     * @return The feature, or null if not found.
     */
    Feature getFeatureByName(String name);

    /**
     * Sets a single feature in the configuration.
     *
     * @param feature The new feature to set.
     */
    void setFeature(Feature feature);
  }

  /**
   * Class that implements the FeatureConfig interface and manages the configurations of features.
   */
  public inherited sharing class FeatureConfigImpl implements FeatureConfig {
    /**
     * The list of all configured features.
     */
    private List<Feature> features;

    /**
     * A map of feature names to their corresponding configuration objects.
     */
    private Map<String, Feature> featureMap;

    /**
     * Constructor to initialize the object with a metadata query for the feature configurations.
     */
    public FeatureConfigImpl() {
      features = new List<Feature>();
      featureMap = new Map<String, Feature>();

      // Query all feature configuration records in the system mode
      for (AFF_Features_Control_Config__mdt featureConfig : [
        SELECT DeveloperName, FeatureDescription__c, IsEnabled__c
        FROM AFF_Features_Control_Config__mdt
        WITH SYSTEM_MODE
      ]) {
        // Create a new feature configuration object and add it to the list and map
        Feature feature = new FeatureImpl(featureConfig);
        features.add(feature);
        featureMap.put(feature.name(), feature);
      }
    }

    /**
     * Returns an iterable list of all configured features.
     *
     * @return An iterable list of all configured features.
     */
    public List<Feature> getFeatures() {
      return new List<Feature>(features);
    }

    /**
     * Sets the list of configured features.
     *
     * @param features The new list of configured features.
     */
    public void setFeatures(List<Feature> features) {
      this.features = new List<Feature>(features);

      // Update the map with the new feature names
      for (Feature feature : features) {
        this.featureMap.put(feature.name(), feature);
      }
    }

    /**
     * Returns a feature by its name, or null if not found.
     *
     * @param name The name of the feature to find.
     * @return The feature, or null if not found.
     */
    public Feature getFeatureByName(String name) {
      return featureMap.get(name);
    }

    /**
     * Sets a single feature in the configuration.
     *
     * @param feature The new feature to set.
     */
    public void setFeature(Feature feature) {
      // Check if the feature already exists, and do nothing if it does
      Feature f = featureMap.get(feature.name());
      if (f == null) {
        featureMap.put(feature.name(), feature);
        features.add(feature);
      }
    }
  }

  /**
   * Interface to add additional constraints to the feature enablement.
   *
   * For example, we can enable/disable a feature for a particular user even if globally this feature is enabled.
   */
  public interface FeatureEnabler {
    /**
     * Returns true if the feature is enabled, false otherwise.
     */
    Boolean isEnabled();
  }

  /**
   * Class that manages the configurations of features.
   *
   * This class is used to manage the configurations of features.
   * It has a map of feature names to their corresponding configuration objects,
   * and can query features by name and update their enabled states.
   */
  public inherited sharing virtual class FeatureConfigMgr extends AFFBase.AbsExecutionManager {
    /**
     * The feature configuration manager that this object manages.
     */
    protected FeatureConfig controlConfigs;
    protected List<FeatureEnabler> enablers;

    /**
     * Constructor to initialize the object with a feature configuration manager.
     *
     * @param fc The feature configuration manager.
     */
    public FeatureConfigMgr(FeatureConfig fc) {
      controlConfigs = fc;
      enablers = new List<FeatureEnabler>();
    }

    /**
     * Constructor to initialize the object with a feature configuration manager and a list of feature enablers.
     *
     * @param fc The feature configuration manager.
     * @param enablers The list of feature enablers.
     */
    public FeatureConfigMgr(FeatureConfig fc, List<FeatureEnabler> enablers) {
      controlConfigs = fc;
      this.enablers = (enablers == null) ? new List<FeatureEnabler>() : enablers;
    }

    /**
     * Adds an executor for a category, but only if the corresponding feature is enabled.
     *
     * @param feature The category to add the executor for.
     * @param exe The executor to add.
     * @return This object, for method chaining.
     */
    public override AFFBase.ExecutionManager addExecutor(
      AFFBase.Category feature,
      Executor exe
    ) {
      // Check if the feature is enabled globally without checking FeatureEnablers
      Feature cfg = controlConfigs.getFeatureByName(feature.name());

      if ( cfg != null && cfg.isEnabled()) {
        super.addExecutor(feature, exe);
      } else {
        System.debug(
          LoggingLevel.INFO,
          '--->>> Feature ' + feature.name() + ' is not configured to be used.'
        );
      }
      return this;
    }

    /**
     * Checks that all feature enablers are enabled or not.
     *
     * @return true if all feature enablers are enabled, false otherwise.
     */
    protected virtual Boolean areAllFeatureEnablersEnabled() {
      for (FeatureEnabler fe : enablers) {
        if (!fe.isEnabled()) {
          return false;
        }
      }
      return true;
    }

    /**
     * Returns whether a category's corresponding feature is enabled.
     *
     * @param feature The category to check.
     * @return True if the feature is enabled, false otherwise.
     */
    public virtual Boolean isEnabled(AFFBase.Category feature) {
      Feature cfg = controlConfigs.getFeatureByName(feature.name());

      // Return true if the feature exists and is enabled
      return (cfg == null)
        ? false
        : cfg.IsEnabled() && areAllFeatureEnablersEnabled();
    }

    /**
     * Enables or disables a category's corresponding feature.
     * 
     * FeatureEnablers are not executed when the feature is set/changed.
     *
     * @param feature The category to enable or disable.
     * @param isEnabled True to enable, false to disable.
     * @return This object, for method chaining.
     */
    public virtual FeatureConfigMgr enableFeature(
      AFFBase.Category feature,
      Boolean isEnabled
    ) {
      Feature cfg = controlConfigs.getFeatureByName(feature.name());

      // Check if the feature exists
      if (cfg != null) {
        cfg.setEnabled(isEnabled);
      } else {
        System.debug(
          LoggingLevel.INFO,
          '--->>> Feature ' + feature.name() + ' is not configured to be used.'
        );
      }
      return this;
    }

    /**
     * Executes all executors for a category, but only if the corresponding feature is enabled.
     *
     * @param aCategory The category to execute for.
     */
    public override void executeAllForCategory(Category aCategory) {
      // Check if the feature is enabled
      if (isEnabled(aCategory)) {
        super.executeAllForCategory(aCategory);
      }
    }
  }
}
