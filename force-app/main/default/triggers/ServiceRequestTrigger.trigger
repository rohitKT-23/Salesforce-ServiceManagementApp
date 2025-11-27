trigger ServiceRequestTrigger on Service_Request__c (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ServiceRequestTriggerHandler.afterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ServiceRequestTriggerHandler.afterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}

