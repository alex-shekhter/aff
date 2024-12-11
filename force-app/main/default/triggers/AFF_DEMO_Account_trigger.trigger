trigger AFF_DEMO_Account_trigger on Account (
  before insert, after insert, 
  before update, after update,
  before delete, after delete,
  after undelete
) {
  new AFF_DEMO_AccountTriggerHandler(
      Trigger.new, Trigger.old,
     Trigger.newMap, Trigger.oldMap
  ).execute();
}