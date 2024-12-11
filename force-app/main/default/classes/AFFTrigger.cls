/**
 * Apex Foundation Framework
 *
 * Author: Alex Shekhter 
 * 
 * Class for triggers
 */ 
public abstract class AFFTrigger {

    // Enum to define different types of trigger operations
    @TestVisible
    private enum TriggerType {
        AFTER_DEL, AFTER_INS, AFTER_UPD, 
        BEFORE_DEL, BEFORE_INS, BEFORE_UPD     
    }
    
    /**
    * TriggerCategory
    *
    * Custom class to represent a category for trigger operations
    */
    public class TriggerCategory extends AFFBase.SimpleCategoryImpl {
        @TestVisible
        private TriggerCategory( TriggerType tt ) {
            super( tt.name() ); 
        }
    }
    
    /// Predefined trigger categories (just a shortcuts)
    // Constants representing different trigger categories for easy reference
    public static final TriggerCategory AFTER_DEL_TRG   = new TriggerCategory( TriggerType.AFTER_DEL );
    public static final TriggerCategory AFTER_INS_TRG   = new TriggerCategory( TriggerType.AFTER_INS );
    public static final TriggerCategory AFTER_UPD_TRG   = new TriggerCategory( TriggerType.AFTER_UPD );
    public static final TriggerCategory BEFORE_DEL_TRG  = new TriggerCategory( TriggerType.BEFORE_DEL );
    public static final TriggerCategory BEFORE_INS_TRG  = new TriggerCategory( TriggerType.BEFORE_INS );
    public static final TriggerCategory BEFORE_UPD_TRG  = new TriggerCategory( TriggerType.BEFORE_UPD );

    // Custom exception for when a trigger category is not recognized
    public inherited sharing class WrongTriggerCategoryException extends Exception {}

    /**
    * TriggerExecutionManager
    *
    * Class to manage the execution of trigger actions, extending a base manager from AFFBase
    */
    public class TriggerExecutionManager extends AFFBase.AbsExecutionManager {

        // Method to add an executor (handler) for a specific category
        public override AFFBase.ExecutionManager addExecutor( 
                AFFBase.Category aCategory, AFFBase.Executor exec 
        ) {
            // Check if the provided category is of type TriggerCategory, otherwise throw an exception
            if ( !(aCategory instanceOf TriggerCategory) ) {
                throw new WrongTriggerCategoryException( 
                    'ERROR: TriggerExecutionManager.addExecutor expects TriggerCategory' 
                );
            }

            return super.addExecutor( aCategory, exec );
        }

        // Override method to execute all executors for the current trigger category
        public override void execute() {                        
            TriggerCategory tc = getTriggerCategory();
            System.assert(tc != null, 'ERROR: Undefined Trigger Category...'); 
            super.executeAllForCategory(tc);             
        }

        // Private method to determine the current trigger category based on trigger context
        private TriggerCategory getTriggerCategory() {
            if (Trigger.isInsert) {
                return Trigger.isBefore ? BEFORE_INS_TRG : AFTER_INS_TRG;
            } else if (Trigger.isUpdate) {
                return Trigger.isBefore ? BEFORE_UPD_TRG : AFTER_UPD_TRG;
            } else if (Trigger.isDelete) {
                return Trigger.isBefore ? BEFORE_DEL_TRG : AFTER_DEL_TRG;
            }
            return null;
        }        
    }    
}
