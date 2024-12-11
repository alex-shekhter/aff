/*
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * Base class
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public inherited sharing abstract class AFFBase {

    /* ===============================================================
        Named Entities
    =============================================================== */    

    /**
     * Entity interface to enforce compile-time checks
     * instead of using Strings where applicable.
     */ 
    public interface Entity {
        /**
        * name
        * @return String
        */
        String name();
    
        /**
         * equals
         * @param o
         * @return Boolean
         */
        Boolean equals( Object o );
    
        /**
         * hashCode
         * @return Integer
        */
        Integer hashCode();
    }

    /**
     * Simple implementation of the @see Entity interface
     */
    public inherited sharing virtual class EntityImpl implements Entity, Comparable {
        protected String nm;

        /**
         * Constructor method for class EntityImpl.
         * @param nm
         */
        public EntityImpl( final String nm ) {
            this.nm = nm;
        }

        /**
         * This method returns name of the entity.
         * @return String
         */
        public virtual String name() {
            return nm;
        }

        /**
         * equals.
         * @param obj
         * @return Boolean
         */
        public Boolean equals(Object obj) {
            if (obj == null) {
                return false;
            }
            AFFBase.EntityImpl other = (AFFBase.EntityImpl)obj;
            if (other.name() == null && this.nm == null) {
                return true;
            }
            return (this.nm == null ? false : this.nm.equals(other.name()));
        }
        
        /**
         * hashCode.
         * @return Integer
         */
        public virtual Integer hashCode() {
            return (nm == null) ? 0 : nm.hashCode(); 
        }

        /**
         * compareTo.
         * @param o
         * @return Integer
         */
        public virtual Integer compareTo( Object o ) {
            EntityImpl ei = (EntityImpl)o;

            Integer res = 0;
            if ( nm == null ) {
                res = ( ei.nm == null ) ? 0 : 1;
            } else if ( ei.nm == null ) {
                res = -1;
            } else {
                res = nm.compareTo( ei.nm );
            }
            return res;
        }
    }

    /* ===============================================================
        Executors
    =============================================================== */    

    /**
     * Executor interface to execute various tasks/business logic
     */
    public interface Executor {
        /**
         * execute.
         */
        void execute();
    }

    /**
     * DataSetterExecutor interface is for setting data for the executor
     */
    public interface DataSetter {
        /**
         *  - setData.
         * @param o
         */
        DataSetter setData( Object o );
    }

    /**
     * DataGetterExecutor interface is for getting data for the executor
     */
    public interface DataGetter {
        /**
         * getData.
         * @return Object
         */
        Object getData();
    }

    /**
     * Category
     */
    public interface Category extends Entity {}

    /**
     * Exception thrown if Category at runtime is wrong
     */
    public inherited sharing class WrongCategoryException extends Exception {}

    /**
     * Runtime exception if instance of the ExecutionManager is wrong
     */
    public inherited sharing class WrongExecutionManagerException extends Exception {}

    /**
     * Categorised ExecutionManager
     */ 
    public interface ExecutionManager {
        /**
         * addExecutor.
         *
         * @param exe
         */
        ExecutionManager addExecutor( Executor exe );

        /**
         * addExecutor.
         * @param cat
         * @param exe
         * @return ExecutionManager
         */
        ExecutionManager addExecutor( Category cat, Executor exe );
        
        /**
         * execute.
         */
        void             execute();     
    }

    /**
    * AbsExecutionManager
    *
    * Abstract class to execute chains of the categorized executors
    */
    public inherited sharing abstract class AbsExecutionManager implements ExecutionManager {
      
        protected Map<Category,List<Executor>> executors = new Map<Category,List<Executor>>();
        protected List<Category> categoriesInOrder = new List<Category>();

        /**
         *  addExecutor to the existing last category in the order
         *
         * @param exe
         */
        public virtual ExecutionManager addExecutor( Executor exe ) {
            Category lastCat = (categoriesInOrder.size() > 0) ? 
               categoriesInOrder.get( categoriesInOrder.size() - 1 ) : null;
            
            if (lastCat == null ) {
                throw new WrongCategoryException( 
                    'At least ont category must be added before calling this method' 
                );
            }

            List<Executor> lst = executors.get( lastCat );
            if (lst == null) {
               lst = new List<Executor>();
            }
            lst.add( exe );

            executors.put( lastCat, lst );

            return this;
        }
        
        /**
         * Chainable method to add executor to particular category.
         *
         * @param  aCategory Object, representing @see Category for executor. 
         *          This object need to satisfy Map's key requirements
         * @param  exec Executor to be added to category.
         * @return - Instance of the @see ExecutionManager, so it can be chainable.
         */
        public virtual ExecutionManager addExecutor( 
                Category aCategory, Executor exec 
        ) {
            List<Executor> lst = executors.get( aCategory );
            if ( lst == null ) {
                lst = new List<Executor>();
                executors.put( aCategory, lst );
                categoriesInOrder.add( aCategory );
            }
            lst.add( exec );
            return this;
        }

        /**
         * Method to execute all executors for the category. Do not do anything if Category
         * not registered...
         *
         * @param aCategory Category we would like to execute executors for.
         */
        public virtual void executeAllForCategory( Category aCategory ) {
            List<Executor> lst = executors.get( aCategory );
            if ( lst != null ) {
                Integer sz = lst.size();
                for ( Integer i = 0; i < sz; i++ ) {
                    lst[ i ].execute();
                }
            }
        }
        
        /**
         * Execute all @see Executor for all categories @see Category at once.
         */
        public virtual void execute() {
            for ( Category c : categoriesInOrder ) {
                executeAllForCategory( c );
            }
        }
    }

    /**
    * SimpleCategoryImpl
    *
    * Simple implemtation of the @see Category interface
    */
    public virtual inherited sharing class SimpleCategoryImpl extends EntityImpl implements Category {
        /**
         * constructor method for class SimpleCategoryImpl.
         * @param nm
         */
        public SimpleCategoryImpl( final String nm ) { super( nm ); }
    }
       
}