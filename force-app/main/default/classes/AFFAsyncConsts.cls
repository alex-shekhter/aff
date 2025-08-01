/**
 *
 * AFF - Apex Foundation Framework
 *
 * Author: Alex Shekhter
 *
 * This class centralizes all string constants used by the AFFAsync framework
 * to improve maintainability and prevent errors from typos in string literals.
 */
public inherited sharing class AFFAsyncConsts {
    // --- Statuses ---
    public static final String STATUS_NEW = 'New';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_IN_PROGRESS = 'InProgress';
    public static final String STATUS_COMPLETED = 'Completed';
    public static final String STATUS_FAILED = 'Failed';
    public static final String STATUS_COMPENSATED = 'Compensated';
    public static final String STATUS_COMPENSATING = 'Compensating';
    public static final String STATUS_COMPENSATION_FAILED = 'Compensation_Failed';
    public static final String STATUS_AWAITING_COMPENSATION = 'AwaitingCompensation';

    // --- Directions ---
    public static final String DIRECTION_DOWN = 'Down';
    public static final String DIRECTION_UP = 'Up';

    // --- State Machine Keys (Direction_Status) ---
    public static final String STATE_KEY_DOWN_PENDING = 'Down_Pending';
    public static final String STATE_KEY_DOWN_IN_PROGRESS = 'Down_InProgress';
    public static final String STATE_KEY_UP_COMPLETED = 'Up_Completed';
    public static final String STATE_KEY_UP_IN_PROGRESS = 'Up_InProgress';
    public static final String STATE_KEY_UP_COMPENSATING = 'Up_Compensating';
    public static final String STATE_KEY_UP_FAILED = 'Up_Failed';
    
    // --- Error Messages ---
    public static final String ERROR_JOB_STATE_NULL = 'JobState cannot be null.';
    public static final String ERROR_JOB_ID_NULL = 'Job ID cannot be null.';
    public static final String ERROR_JOBS_LIST_INVALID = 'Jobs must be a non-null, non-empty list of JobState instances';
    public static final String ERROR_COULD_NOT_FIND_CLASS = 'Could not find class: ';
    public static final String ERROR_COULD_NOT_INSTANTIATE_STEP = 'Could not instantiate step class: ';
    public static final String ERROR_PERMANENT_FAILURE_PREFIX = 'Action failed after ';
    public static final String ERROR_PERMANENT_FAILURE_SUFFIX = ' attempts.';
    public static final String ERROR_UNKNOWN_STATE_TRANSITION = 'Unknown state transition for key: ';
    public static final String ERROR_CRITICAL_ORCHESTRATOR_FAILURE = 'Critical orchestrator failure: ';
}
