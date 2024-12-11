/**
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Abstract base class for DML (Create, Update, Delete) operations.
 */
public inherited sharing abstract class AFFDml {

    /**
     * Private inner class representing different types of DML operations.
     */
    public inherited sharing class DmlType extends AFFBase.SimpleCategoryImpl {
        /**
         * Constructor to create a new DmlType instance with the given name.
         *
         * @param name The name of the DmlType instance.
         */        
        private DmlType( String name ) {
            super( name );
        }
    }

    // Constants representing different types of DML operations
    private static final DmlType T_EMPTY = new DmlType( '' ); // Represents an empty or undefined DML type
    public static final DmlType T_INSERT = new DmlType( 'insert' ); // Insert operation
    public static final DmlType T_UPDATE = new DmlType( 'update' ); // Update operation
    public static final DmlType T_UPSERT = new DmlType( 'upsert' ); // Upsert (Insert or update) operation
    public static final DmlType T_DELETE = new DmlType( 'delete' ); // Delete operation

    // BadDataExecption - Exception thrown when a bad data is encountered during DML operation.
    public inherited sharing class BadDataException extends Exception {}

    /**
     * Interface representing a single unit of change.
     */    
    public interface ChangeUnit {
        /**
         * Sets the type of DML operation for this change unit.
         *
         * @param type The DmlType instance to set.
         * @return This change unit instance (for chaining).
         */
        ChangeUnit setDmlType( DmlType type );

        /**
         * Gets data records related to particular DML operation from the Change Unit.
         * 
         * @return The List<SObject> related to particular DML operation or null if not available.
         */
        List<Sobject> getRecordsByDmlType( DmlType type );

        /**
         * Removes data records related to particular DML operation from the Change Unit.
         * 
         * @return This change unit instance (for chaining).
         */
        ChangeUnit clearRecordsByDmlType( DmlType type );

        /**
         * Clear all data records for all DML operations from the Change Unit.
         * 
         * @return This change unit instance (for chaining).
         */
        ChangeUnit clearAllRecords();

        /**
         * Adds the record for this change unit.
         *
         * @param obj The SObject instance to set.
         * @return This change unit instance (for chaining).
         */        
        ChangeUnit addRecord( SObject obj );

        /**
         * Adds the records for this change unit from a list of SObjects.
         *
         * @param objs The list of SObject instances to set.
         * @return This change unit instance (for chaining).
         */        
        ChangeUnit addRecords( List<SObject> objs );
        
        /**
         * Applies the changes represented by this change unit.
         *
         * @return This change unit instance (for chaining).
         */        
        ChangeUnit applyChange();
    }

    /**
     * Enum representing different access modes for DML operations.
     */
    public enum AccessMode { SYSTEM_MODE, USER_MODE }

    /**
     * Default implementation of the ChangeUnit interface.
     */
    public inherited sharing virtual class DefaultChangeUnitImpl implements ChangeUnit {

        protected Map<DmlType,List<SObject>> dataMap = new Map<DmlType,List<SObject>>();
        protected DmlType currDmlType;

        protected AccessMode access;

        /**
         * Constructor to create a new DefaultChangeUnitImpl instance with the given access mode.
         *
         * @param access The access mode to set (is NULL - default is USER_MODE).
         */
        public DefaultChangeUnitImpl( AccessMode access ) {
            this.access = (access == null) ? AccessMode.USER_MODE : access;
            dataMap.put( T_EMPTY, new List<SObject>() );
            currDmlType = T_EMPTY;
        }

        /**
         * Sets the type of DML operation for this change unit.
         *
         * @param type The DmlType instance to set.
         * @return This change unit instance (for chaining).
         */        
        public virtual ChangeUnit setDmlType( DmlType type ) {
            this.currDmlType = (type == null) ? T_EMPTY : type;

            if ( !T_EMPTY.equals( currDmlType ) ) {
                List<SObject> objs = dataMap.get( T_EMPTY );
                if ( objs != null && !objs.isEmpty() ) {
                    dataMap.put( currDmlType, objs );
                    dataMap.put( T_EMPTY, null );
                }
            }

            return this;
        }

        /**
         * Gets the list of SObjects associated with the given DML type.
         *
         * @param type The DmlType instance to get the list for.
         * @return The list of SObject instances or a null if not found.
         */
        public virtual List<Sobject> getRecordsByDmlType( DmlType type ) {
            return dataMap.get( type );
        }

        /**
         * Removes data records related to particular DML operation from the Change Unit.
         * 
         * @return This change unit instance (for chaining).
         */
        public virtual ChangeUnit clearRecordsByDmlType( DmlType type ) {
            List<Sobject> objs = dataMap.get( type );
            if ( objs!= null ) {
                dataMap.remove( type  );
            }
            return this;
        }

        /**
         * Clear all data records for all DML operations from the Change Unit.
         * 
         * @return This change unit instance (for chaining).
         */
        public virtual ChangeUnit clearAllRecords() {
            currDmlType = T_EMPTY;
            dataMap.clear();
            dataMap.put( T_EMPTY, new List<Sobject>() );

            return this;
        }


        /**
         * Gets the list of SObjects associated with the given DML type.
         *
         * @param type The DmlType instance to get the list for.
         * @return The list of SObject instances, empty list if type is found or a null if type is null.
         */
        protected virtual List<Sobject> getDataList( DmlType type ) {
            if ( type == null ) {
                return null;
            }

            List<SObject> sobjs = dataMap.get( type );
            if ( sobjs == null ) {
                sobjs = new List<SObject>();
                dataMap.put( type, sobjs );
            }

            return sobjs;
        }

        /**
         * Sets the data for this change unit from a single SObject.
         *
         * @param obj The SObject instance to set.
         * @return This change unit instance (for chaining).
         */
        public virtual ChangeUnit addRecord( SObject obj  ) {
            getDataList( currDmlType ).add( obj );
            return this ;
        }

        /**
         * Sets the data for this change unit from a list of SObjects.
         *
         * @param objs The list of SObject instances to set.
         * @return This change unit instance (for chaining).
         */        
        public virtual ChangeUnit addRecords( List<SObject> objs  ) {
            getDataList( currDmlType ).addAll( objs );
            return this ;
        }

        /**
         * Applies the insert DML operation for the associated data list.
         *
         * @param data The list of SObjects to insert.
         */        
        protected virtual void insertData( List<SObject> data ) {
            if ( data != null && !data.isEmpty() ) {
                if ( access == AccessMode.USER_MODE ) {
                    insert as user data;
                } else {
                    insert as system data;
                }
            }
        }

        /**
         * Applies the update DML operation for the associated data list.
         *
         * @param data The list of SObjects to update.
         */
        protected virtual void updateData( List<SObject> data ) {
            if ( data != null && !data.isEmpty() ) {
                if ( access == AccessMode.USER_MODE ) {
                    update as user data;
                } else {
                    update as system data;
                }
            }
        }

        /**
         * Applies the upsert DML operation for the associated data list.
         *
         * @param data The list of SObjects to upsert.
         */
        protected virtual void upsertData( List<SObject> data ) {
            if ( data != null && !data.isEmpty() ) {
                if ( access == AccessMode.USER_MODE ) {
                    upsert as user data;
                } else {
                    upsert as system data;
                }
            }
        }

        /**
         * Applies the delete DML operation for the associated data list.
         *
         * @param data The list of SObjects to delete.
         */        
        protected virtual void deleteData( List<SObject> data ) {
            if ( data != null && !data.isEmpty() ) {
                if ( access == AccessMode.USER_MODE ) {
                    delete as user data;
                } else {
                    delete as system data;
                }
            }
        }

        /**
         * Applies the changes represented by this change unit.
         *
         * @return This change unit instance (for chaining).
         */
        public virtual ChangeUnit applyChange() {

            List<SObject> data = dataMap.get( T_EMPTY );
            if ( data != null && !data.isEmpty() ) {
                throw new BadDataException( 'DML data type has not been set before applyChange() call...' );
            }
            
            // TODO: Think about more effective way to apply change.
            insertData( getDataList( T_INSERT ) );
            updateData( getDataList( T_UPDATE ) );
            upsertData( getDataList( T_UPSERT ) );
            deleteData( getDataList( T_DELETE ) );
            
            return this;
        }
    }
}