/**
 *
 * AFF - Apex foundation Framework
 *
 * Author: Alex Shekhter
 *
 * @description Class that implements Salesforce Limits related features
 */
public inherited sharing abstract class AFFLimit {
  public inherited sharing class Budget {
    private final Integer soqlBudget;
    private final Integer dmlStatementsBudget;
    private final Integer cpuTimeBudget;
    private final Integer heapSizeBudget;

    /**
     * @description Constructor that establishes the budget for each limit.
     * @param safetyFactor A percentage (e.g., 80) representing the max limit
     * consumption before the budget is considered exhausted.
     */
    public Budget(Integer safetyFactor) {
      // Ensure safety factor is within a reasonable range (e.g., 50-95)
      Integer factor = Math.max(50, Math.min(safetyFactor, 95));
      Decimal factorDecimal = (Decimal) factor / 100;

      this.soqlBudget = (Integer) (Limits.getLimitQueries() * factorDecimal);
      this.dmlStatementsBudget = (Integer) (Limits.getLimitDmlStatements() *
      factorDecimal);
      this.cpuTimeBudget = (Integer) (Limits.getLimitCpuTime() * factorDecimal);
      this.heapSizeBudget = (Integer) (Limits.getLimitHeapSize() *
      factorDecimal);
    }

    /**
     * @description Checks if all monitored limits are still within the defined budget.
     * @return Boolean - True if the process can safely continue.
     */
    public Boolean canContinue() {
      if (Limits.getQueries() >= this.soqlBudget) {
        System.debug(
          LoggingLevel.WARN,
          'AFFLimit.Budget: SOQL limit threshold reached.'
        );
        return false;
      }
      if (Limits.getDmlStatements() >= this.dmlStatementsBudget) {
        System.debug(
          LoggingLevel.WARN,
          'AFFLimit.Budget: DML Statements limit threshold reached.'
        );
        return false;
      }
      if (Limits.getCpuTime() >= this.cpuTimeBudget) {
        System.debug(
          LoggingLevel.WARN,
          'AFFLimit.Budget: CPU Time limit threshold reached.'
        );
        return false;
      }
      if (Limits.getHeapSize() >= this.heapSizeBudget) {
        System.debug(
          LoggingLevel.WARN,
          'AFFLimit.Budget: Heap Size limit threshold reached.'
        );
        return false;
      }

      return true;
    }
  }
}
