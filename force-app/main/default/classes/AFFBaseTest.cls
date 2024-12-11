/*
 * AFF - Apex Foundation Framework
 * 
 * Author: Alex Shekhter
 * 
 * AFFBase test class
 */
@isTest
public class AFFBaseTest {

    /**
     * Tests that AFFBase.EntityImpl instances can be sorted and compared correctly.
     */
    @isTest
    public static void testEntityImpl() {
        // Start a test case
        Test.startTest();

        // Create a list of AFFBase.EntityImpl instances in various states
        List<AFFBase.EntityImpl> eis = new List<AFFBase.EntityImpl>{
            // Null instance
            new AFFBase.EntityImpl( null ),

            // Empty string instance
            new AFFBase.EntityImpl( '' ),

            // Single character instance
            new AFFBase.EntityImpl( 'c' ),

            // Another null instance (for sorting purposes)
            new AFFBase.EntityImpl( null ),

            // Two single character instances ('b' and 'a')
            new AFFBase.EntityImpl( 'b' ),
            new AFFBase.EntityImpl( 'a' ),

            // Another empty string instance (for sorting purposes)
            new AFFBase.EntityImpl( '' )
        };

        // Create a sorted list of AFFBase.EntityImpl instances
        List<AFFBase.EntityImpl> sortedEis = new List<AFFBase.EntityImpl>{
            new AFFBase.EntityImpl( '' ),
            new AFFBase.EntityImpl( '' ),
            new AFFBase.EntityImpl( 'a' ),
            new AFFBase.EntityImpl( 'b' ),
            new AFFBase.EntityImpl( 'c' ),
            new AFFBase.EntityImpl( null ),
            new AFFBase.EntityImpl( null )
        };

        // Initialize a counter for the loop
        Integer i = 0;

        // Get the sizes of both lists
        Integer sz0 = eis.size();
        Integer sz1 = sortedEis.size();

        // Assert that both lists have the same size
        System.assert( sz0 == sz1, 'Size should be the same' );

        // Loop through both lists and assert that each element is equal
        eis.sort();        
        for ( ; i < sz0; i++ ) {
            System.assert( eis[ i ].equals( sortedEis[ i ] ), 'Element ' + i + ' should be the same' );

            // Also assert that the hash codes of each element are equal
            System.assert( eis[ i ].hashCode() == sortedEis[ i ].hashCode(), 'Element ' + i + 'hashCodes should be the same' );
        }

        // Stop the test case
        Test.stopTest();
    }

    /**
     * A subclass of AFFBase.AbsExecutionManager for testing purposes.
     */
    private class ExecMgrTest extends AFFBase.AbsExecutionManager {}

    /**
     * Predefined categories for testing execution managers.
     */
    public static final AFFBase.SimpleCategoryImpl ADDITION_CAT = new AFFBase.SimpleCategoryImpl( 'Addition' );

    public static final AFFBase.SimpleCategoryImpl SUBSTRACTION_CAT = new AFFBase.SimpleCategoryImpl( 'Substraction' );

    public static final AFFBase.SimpleCategoryImpl MULTIPLICATION_CAT = new AFFBase.SimpleCategoryImpl( 'Multiplication' );

    public static final AFFBase.SimpleCategoryImpl DIVISION_CAT = new AFFBase.SimpleCategoryImpl( 'Division' );

    /**
     * A class to hold an integer value.
     */
    public class IntVault {
        /**
         * The stored integer value.
         */
        public Integer value { get; set; }

        /**
         * IntegerConstructor to initialize the value.
         * 
         * @param v The value to initialize the vault with.
         */
        public IntVault( Integer v ) {
            this.value = v;
        }
    }

    /**
     * An implementation of AFFBase.Executor for testing purposes.
     */
    public virtual class IntAdditionExecutor implements AFFBase.Executor {
        protected IntVault iv;

        // The value to add
        protected Integer rval;

        /**
         * Constructor to initialize the vault and the value to add.
         * 
         * @param iv The vault to add to.
         * @param add The value to add.
         */
        public IntAdditionExecutor( IntVault iv, Integer add ) {
            this.iv = iv;
            rval = add;
        }

        /**
         * Method to execute the addition operation.
         */
        public virtual void execute() {
            // Add the value to the vault
            iv.value += rval;
        }
    }

    /**
     * A subclass of IntAdditionExecutor for subtracting values.
     */
    public class IntSubstractionExecutor extends IntAdditionExecutor {

        /**
         * Constructor to initialize the vault and the value to subtract.
         * 
         * @param iv The vault to subtract from.
         * @param sub The value to subtract.
         */
        public IntSubstractionExecutor( IntVault iv, Integer sub ) {
            super( iv, sub );
        }

        /**
         * Method to execute the subtraction operation.
         */
        public override void execute() {
            // Subtract the value from the vault
            iv.value -= rval;
        }
    }

    /**
     * A subclass of AFFBase.AbsExecutionManager for testing execution managers.
     */
    public class MathExecMgr extends AFFBase.AbsExecutionManager {}

    /**
     * Tests that execution managers can be used to execute operations on a vault.
     */
    @IsTest
    private static void testExecutionManager() {
        // Create an instance of IntVault
        IntVault iv = new IntVault( 10 );

        // Start a test case
        Test.startTest();

        // Add executors for addition and subtraction to the execution manager
        (new MathExecMgr())
            .addExecutor( ADDITION_CAT, new IntAdditionExecutor( iv, 5 ) )
            .addExecutor( ADDITION_CAT, new IntAdditionExecutor( iv, 5 ) )
            .addExecutor( SUBSTRACTION_CAT, new IntSubstractionExecutor( iv, 2 ) )
            .addExecutor( SUBSTRACTION_CAT, new IntSubstractionExecutor( iv, -3 ) )
            .execute();

        // Stop the test case
        Test.stopTest();

        // Assert that the final value in the vault is correct
        final Integer trg = 21;
        System.assert( iv.value == trg, 'Value should be ' + trg );
    }

    /**
     * Tests that addExecutor without explicit category works
     */
    @IsTest
    private static void testAddExecutorWithoutCategorySunny() {
        // Create an instance of IntVault
        IntVault iv = new IntVault( 10 );

        // Start a test case
        Test.startTest();

        Boolean exceptionThrown = false;
        try {
            // Add executors for addition and subtraction to the execution manager
            (new MathExecMgr())
                .addExecutor( ADDITION_CAT, new IntAdditionExecutor( iv, 5 ) )
                .addExecutor( new IntAdditionExecutor( iv, 5 ) )
                .addExecutor( SUBSTRACTION_CAT, new IntSubstractionExecutor( iv, 2 ) )
                .addExecutor( new IntSubstractionExecutor( iv, -3 ) )
                .execute();
        }
        catch ( AFFBase.WrongCategoryException e ) {
            exceptionThrown = true;
        }
        // Stop the test case
        Test.stopTest();

        System.assert( !exceptionThrown, 'We do not expect WrongCategoryException to be thrown' );

        // Assert that the final value in the vault is correct
        final Integer trg = 21;
        System.assert( iv.value == trg, 'Value should be ' + trg );
    }

    /**
     * Tests that addExecutor without explocit category fails if no category is provided before the call
      */
    @IsTest
    private static void testAddExecutorWithoutCategoryFail() {
        // Create an instance of IntVault
        IntVault iv = new IntVault( 10 );

        // Start a test case
        Test.startTest();

        Boolean exceptionThrown = false;
        try {
            // Add executors for addition and subtraction to the execution manager
            (new MathExecMgr())
                .addExecutor( new IntAdditionExecutor( iv, 5 ) )
                .addExecutor( ADDITION_CAT, new IntAdditionExecutor( iv, 5 ) )
                .addExecutor( SUBSTRACTION_CAT, new IntSubstractionExecutor( iv, 2 ) )
                .addExecutor( SUBSTRACTION_CAT, new IntSubstractionExecutor( iv, -3 ) )
                .execute();
        }
        catch ( AFFBase.WrongCategoryException e ) {
            exceptionThrown = true;
        }
        // Stop the test case
        Test.stopTest();

        System.assert( exceptionThrown, 'We expect that WrongCategoryException will be thrown' );

        // Assert that the final value in the vault is correct
        final Integer trg = 10;
        System.assert( iv.value == trg, 'Value should be ' + trg );
    }

}