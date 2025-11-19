public with sharing class ApprovalStepsController {
    
    @AuraEnabled(cacheable=true)
    public static List<ApprovalStepWrapper> getApprovalSteps(String serviceRequestId) {
        List<ApprovalStepWrapper> steps = new List<ApprovalStepWrapper>();
        
        try {
            // Get Request Approval Steps (actual steps for this request)
            List<Request_Approval_Step__c> requestSteps = [
                SELECT Id, Sequence__c, Status__c, Status__r.Name,
                       Approval_Step__c, Approval_Step__r.Step_Description__c,
                       Approval_Step__r.Sequence__c, Service__c
                FROM Request_Approval_Step__c
                WHERE Service_Request__c = :serviceRequestId
                ORDER BY Sequence__c ASC
            ];
            
            // Get Service ID from first request step if available
            Id serviceId = null;
            if (!requestSteps.isEmpty() && requestSteps[0].Service__c != null) {
                serviceId = requestSteps[0].Service__c;
            }
            
            // Get all Approval Steps for the Service (template)
            List<Approval_Step__c> approvalSteps = new List<Approval_Step__c>();
            if (serviceId != null) {
                approvalSteps = [
                    SELECT Id, Sequence__c, Step_Description__c, Status__c, Status__r.Name
                    FROM Approval_Step__c
                    WHERE Service__c = :serviceId
                    ORDER BY Sequence__c ASC
                ];
            }
            
            // Create a map of request steps by approval step ID
            Map<Id, Request_Approval_Step__c> requestStepsMap = new Map<Id, Request_Approval_Step__c>();
            for (Request_Approval_Step__c rs : requestSteps) {
                if (rs.Approval_Step__c != null) {
                    requestStepsMap.put(rs.Approval_Step__c, rs);
                }
            }
            
            // Build wrapper list
            for (Approval_Step__c step : approvalSteps) {
                ApprovalStepWrapper wrapper = new ApprovalStepWrapper();
                wrapper.id = step.Id;
                wrapper.sequence = Integer.valueOf(step.Sequence__c);
                wrapper.description = step.Step_Description__c;
                wrapper.expectedStatus = step.Status__r != null ? step.Status__r.Name : '';
                
                // Check if this step has a corresponding request step
                Request_Approval_Step__c requestStep = requestStepsMap.get(step.Id);
                if (requestStep != null) {
                    wrapper.currentStatus = requestStep.Status__r != null ? requestStep.Status__r.Name : '';
                    wrapper.isCompleted = requestStep.Status__c != null;
                    wrapper.requestStepId = requestStep.Id;
                } else {
                    wrapper.currentStatus = '';
                    wrapper.isCompleted = false;
                }
                
                steps.add(wrapper);
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error loading approval steps: ' + e.getMessage());
        }
        
        return steps;
    }
    
    public class ApprovalStepWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public Integer sequence;
        @AuraEnabled public String description;
        @AuraEnabled public String expectedStatus;
        @AuraEnabled public String currentStatus;
        @AuraEnabled public Boolean isCompleted;
        @AuraEnabled public String requestStepId;
    }
}

