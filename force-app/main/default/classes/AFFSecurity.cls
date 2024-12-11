/*
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * SObject and FLS Security helpers
 */
public inherited sharing class AFFSecurity {

    /**
     *  Interface defining methods to check CRUD operations for a field.
     */
    public interface FLSCrudChecker {
        /**
         *  Check if the field is accessible.
         *
         * @return true if the field is accessible, false otherwise
         */
        Boolean isAccessible();

        /**
         *  Check if the field can be created (i.e., inserted).
         *
         * @return true if the field can be created, false otherwise
         */
        Boolean isCreateable();

        /**
         *  Check if the field can be updated.
         *
         * @return true if the field can be updated, false otherwise
         */
        Boolean isUpdateable();
    }

    // We use this interface and implementation classes to reduce complexity 
    // of the Security.FieldChecker class
    /**
     *  Interface defining a method to check access for a field.
     */
    private interface FLSAccessChecker {
        /**
         *  Check if the field has good access (e.g., is accessible).
         *
         * @param fldDescr Description of the field to check
         * @return true if the field has good access, false otherwise
         */
        Boolean isGood( Schema.DescribeFieldResult fldDescr );
    }

    /**
     *  Implementation class for checking field accessibility.
     */
    private inherited sharing class FldAccessabilityChecker implements FLSAccessChecker {
        /**
         *  Check if the field is accessible.
         *
         * @param fldDescr Description of the field to check
         * @return true if the field is accessible, false otherwise
         */
        public Boolean isGood( Schema.DescribeFieldResult fldDescr ) {
            return fldDescr.isAccessible();
        }
    }

    /**
     *  Implementation class for checking field creatability.
     */
    private inherited sharing class FldCreatabilityChecker implements FLSAccessChecker {
        /**
         *  Check if the field can be created (i.e., inserted).
         *
         * @param fldDescr Description of the field to check
         * @return true if the field can be created, false otherwise
         */
        public Boolean isGood( Schema.DescribeFieldResult fldDescr ) {
            return fldDescr.isCreateable();
        }
    }

    /**
     *  Implementation class for checking field updatability.
     */
    private inherited sharing class FldUpdatabilityChecker implements FLSAccessChecker {
        /**
         *  Check if the field can be updated.
         *
         * @param fldDescr Description of the field to check
         * @return true if the field can be updated, false otherwise
         */
        public Boolean isGood( Schema.DescribeFieldResult fldDescr ) {
            return fldDescr.isUpdateable();
        }
    }

    /**
     *  Interface defining methods to check CRUD operations for an object.
     */
    public interface SObjCrudChecker extends FLSCrudChecker {
        /**
         *  Check if the object can be deleted.
         *
         * @return true if the object can be deleted, false otherwise
         */
        Boolean isDeletable();
    }

    /**
     *  Implementation class for checking CRUD operations on a field.
     */
    public inherited sharing class FieldChecker implements FLSCrudChecker {
        /**
         * List of fields to check.
         */
        private List<Schema.DescribeFieldResult> fieldsToCheck;

        // We will cache our permissions lazily, that is why we init them with NULL explicitely
        /**
         * Cached result for field accessibility check.
         */
        private Boolean pIsAccessible = null;

        /**
         * Cached result for field updatable check.
         */
        private Boolean pIsUpdatable = null;

        /**
         * Cached result for field creatable check.
         */
        private Boolean pIsCreatable = null;

        /**
         *  Constructor to initialize the field checker with an object type and a list of fields to check.
         *
         * @param objType Object type to check
         * @param fieldsToCheck List of fields to check
         */
        public FieldChecker(SObjectType objType, List<String> fieldsToCheck) {
            Map<String,Schema.SObjectField> fields = objType.getDescribe().fields.getMap();
            this.fieldsToCheck = new List<Schema.DescribeFieldResult>();
            for (String field : fieldsToCheck) {
                this.fieldsToCheck.add(fields.get(field).getDescribe());
            }
        }

        /**
         *  Helper method to check access level for a field.
         *
         * @param checker Checker to use
         * @return true if the field has good access, false otherwise
         */
        private Boolean checkAccessLevel( FLSAccessChecker checker ) {
            for ( Schema.DescribeFieldResult fldDescr : fieldsToCheck ) {
                if ( !checker.isGood( fldDescr ) ) {
                    return false;
                }
            }
            return true;
        }

        /**
         *  Check if the field is accessible.
         *
         * @return true if the field is accessible, false otherwise
         */
        public Boolean isAccessible() {
            if ( pIsAccessible == null ) {
                 pIsAccessible = checkAccessLevel( new FldAccessabilityChecker() );
            }
            return pIsAccessible;
        }

        /**
         *  Check if the field can be created (i.e., inserted).
         *
         * @return true if the field can be created, false otherwise
         */
        public Boolean isCreateable() {
            if ( pIsCreatable == null ) {
                pIsCreatable = checkAccessLevel( new FldCreatabilityChecker() );
            }
            return pIsCreatable;
        }

        /**
         *  Check if the field can be updated.
         *
         * @return true if the field can be updated, false otherwise
         */
        public Boolean isUpdateable() {
            if ( pIsUpdatable == null ) {
                pIsUpdatable = checkAccessLevel( new FldUpdatabilityChecker() );
            }
            return pIsUpdatable;
        }
    }

    /**
     *  Implementation class for checking CRUD operations on an object.
     */
    public inherited sharing class SObjectChecker implements SObjCrudChecker {
        /**
         * Object type to check.
         */
        private SObjectType objType;

        /**
         * Description of the object to check.
         */
        private Schema.DescribeSObjectResult objDescr;

        /**
         *  Constructor to initialize the object checker with an object type.
         *
         * @param objType Object type to check
         */
        public SObjectChecker(SObjectType objType) {
            this.objType = objType;
            this.objDescr = this.objType.getDescribe();
        }

        /**
         *  Check if the object is accessible.
         *
         * @return true if the object is accessible, false otherwise
         */
        public Boolean isAccessible() {
            return objDescr.isAccessible();
        }

        /**
         *  Check if the object can be created (i.e., inserted).
         *
         * @return true if the object can be created, false otherwise
         */
        public Boolean isCreateable() {
            return objDescr.isCreateable();
        }

        /**
         *  Check if the object can be updated.
         *
         * @return true if the object can be updated, false otherwise
         */
        public Boolean isUpdateable() {
            return objDescr.isUndeletable();
        }

        /**
         *  Check if the object can be deleted.
         *
         * @return true if the object can be deleted, false otherwise
         */
        public Boolean isDeletable() {
            return objDescr.isDeletable();
        }
    }
}