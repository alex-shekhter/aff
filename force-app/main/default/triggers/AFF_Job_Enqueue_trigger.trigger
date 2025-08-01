trigger AFF_Job_Enqueue_trigger on AFF_Job_Enqueue__e (after insert) {
  /**
   * We are going to use Platform Event Engine to execute our jobs
   */
  new AFFAsyncEng.PlatformEventExecutor( (List<AFF_Job_Enqueue__e>)Trigger.new ).execute();
}