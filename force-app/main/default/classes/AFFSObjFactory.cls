/*
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * Factory classes for SObjects
 */
public inherited sharing abstract class AFFSObjFactory {
  /**
   * An interface for setting fields on an SObject.
   */
  public interface FieldSetter {
    /**
     * Sets the value of a field on an SObject.
     * @param: sobj - The SObject to set the value for.
     * @param: fieldName - The name of the field to set the value for.
     */
    void setValue(SObject sobj, String fieldName);
  }

  /**
   * An interface for creating instances of SObjects.
   */
  public interface Factory {
    /**
     * Creates a new instance of an SObject.
     * @return SObject
     */
    SObject create();
  }

  /**
   * An exception class for handling cases where a field does not exist on an SObject.
   */
  public inherited sharing class WrongFieldException extends Exception {
  }

  /**
   * An enum for representing field-level security settings.
   */
  public enum FieldLevelSecurity {
    FLS_CREATE,
    FLS_READ,
    FLS_WRITE
  }

  /**
   * A class for creating standard instances of SObjects based on given parameters.
   */
  public inherited sharing virtual class StandardFactory implements Factory {
    /**
     * Fields to set on the new SObject
     */
    protected List<Schema.DescribeFieldResult> fields;
    /**
     * Field name to field describe map
     */
    protected Map<String, Schema.DescribeFieldResult> fieldsByName;
    /**
     * Map of the field names to FieldSetters.
     */
    protected Map<String, FieldSetter> fieldSettersByFieldName;

    /**
     * SObject type to use to create our SObject
     */
    protected Schema.SObjectType sobjType;

    /**
     * StandardFactory constructor
     * @param sobjType - The SObjectType to create instances of.
     * @param fields - The fields to set on the SObject.
     * @param fieldSettersByFieldName - A map of field names to FieldSetter instances.
     */
    public StandardFactory(
      Schema.SObjectType sobjType,
      List<String> fields,
      Map<String, FieldSetter> fieldSettersByFieldName
    ) {
      this.sobjType = sobjType;

      this.fields = new List<Schema.DescribeFieldResult>();
      this.fieldsByName = new Map<String, Schema.DescribeFieldResult>();

      Map<String, Schema.SObjectField> sobjFldsByName = sobjType.getDescribe()
        .fields.getMap();
      for (String f : fields) {
        Schema.SObjectField sof = sobjFldsByName.get(f);
        if (sof == null) {
          throw new WrongFieldException('Unknown Field name: ' + f + ';');
        }
        Schema.DescribeFieldResult dfr = sof.getDescribe();
        this.fields.add(dfr);
        fieldsByName.put(f, dfr);
      }

      this.fieldSettersByFieldName = fieldSettersByFieldName;
    }

    /**
     * Apply field-level security to the fields in the SObject. Chainable
     *
     * Filters out fields which don't conform to the FieldLevelSecurity settings
     *
     * @param fieldLevelSecuritySettings - The FieldLevelSecurity settings to apply.
     * @return The StandardFactory instance.
     */
    @SuppressWarnings('PMD.CognitiveComplexity')
    public virtual StandardFactory applyFieldLevelSecurity(
      List<FieldLevelSecurity> fieldLevelSecuritySettings
    ) {
      List<Schema.DescribeFieldResult> filteredFields = new List<Schema.DescribeFieldResult>();

      for (Schema.DescribeFieldResult fieldDescribeResult : fields) {
        Integer requiredSecurityCount = 0;

        for (FieldLevelSecurity fls : fieldLevelSecuritySettings) {
          if (fls == FieldLevelSecurity.FLS_CREATE && fieldDescribeResult.isCreateable() ) {
            requiredSecurityCount++;
          }
          
          if (fls == FieldLevelSecurity.FLS_READ && fieldDescribeResult.isAccessible()) {
            requiredSecurityCount++;
          } 
          
          if (fls == FieldLevelSecurity.FLS_WRITE && fieldDescribeResult.isUpdateable()) {
            requiredSecurityCount++;
          }

          if (requiredSecurityCount == fieldLevelSecuritySettings.size()) {
            filteredFields.add(fieldDescribeResult);
          } else {
            fieldsByName.remove(fieldDescribeResult.getName());
          }
        }
      }

      fields = filteredFields;

      return this;
    }

    /**
     * Create a new SObject instance.
     *
     * @return The new SObject instance.
     */
    public virtual SObject create() {
      SObject sobj = sobjType.newSObject();
      for (Schema.DescribeFieldResult fld : fields) {
        FieldSetter fs = fieldSettersByFieldName.get(fld.getName());
        if (fs == null) {
          sobj.put(fld.getName(), fld.getDefaultValue());
        } else {
          fs.setValue(sobj, fld.getName());
        }
      }
      return sobj;
    }
  }
}
