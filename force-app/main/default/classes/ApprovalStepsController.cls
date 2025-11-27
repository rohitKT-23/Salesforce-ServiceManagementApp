public with sharing class ApprovalStepsController {
    
    @AuraEnabled(cacheable=true)
    public static List<ApprovalStepWrapper> getApprovalSteps(String serviceRequestId) {
        List<ApprovalStepWrapper> steps = new List<ApprovalStepWrapper>();
        
        try {
            // Get Service Request to get Service ID
            List<Service_Request__c> serviceRequests = [
                SELECT Id, Service__c, Status__c, Status__r.Name
                FROM Service_Request__c
                WHERE Id = :serviceRequestId
                LIMIT 1
            ];
            
            if (serviceRequests.isEmpty() || serviceRequests[0].Service__c == null) {
                System.debug('No Service Request found or Service is null for ID: ' + serviceRequestId);
                return steps; // Return empty list
            }
            
            Id serviceId = serviceRequests[0].Service__c;
            System.debug('Service ID: ' + serviceId);
            
            // Get Request Approval Steps (actual steps for this request)
            List<Request_Approval_Step__c> requestSteps = [
                SELECT Id, Sequence__c, Status__c, Status__r.Name,
                       Approval_Step__c, Approval_Step__r.Step_Description__c,
                       Approval_Step__r.Sequence__c, Service__c
                FROM Request_Approval_Step__c
                WHERE Service_Request__c = :serviceRequestId
                ORDER BY Sequence__c ASC
            ];
            
            System.debug('Request Steps count: ' + requestSteps.size());
            
            // Get all Approval Steps for the Service (template)
            List<Approval_Step__c> approvalSteps = [
                SELECT Id, Sequence__c, Step_Description__c, Status__c, Status__r.Name
                FROM Approval_Step__c
                WHERE Service__c = :serviceId
                ORDER BY Sequence__c ASC
            ];
            
            System.debug('Approval Steps count: ' + approvalSteps.size());
            
            // Create a map of request steps by approval step ID
            Map<Id, Request_Approval_Step__c> requestStepsMap = new Map<Id, Request_Approval_Step__c>();
            for (Request_Approval_Step__c rs : requestSteps) {
                if (rs.Approval_Step__c != null) {
                    requestStepsMap.put(rs.Approval_Step__c, rs);
                }
            }
            
            // Determine the index of the current service request status within the approval steps
            Id currentStatusId = serviceRequests[0].Status__c;
            String currentStatusName = serviceRequests[0].Status__r != null ? serviceRequests[0].Status__r.Name : '';
            Integer currentStatusIndex = -1;
            
            for (Integer idx = 0; idx < approvalSteps.size(); idx++) {
                Approval_Step__c statusStep = approvalSteps[idx];
                Boolean idMatches = currentStatusId != null && statusStep.Status__c == currentStatusId;
                Boolean nameMatches = String.isNotBlank(currentStatusName) 
                    && statusStep.Status__r != null 
                    && statusStep.Status__r.Name == currentStatusName;
                
                if (idMatches || nameMatches) {
                    currentStatusIndex = idx;
                    break;
                }
            }
            
            // Build wrapper list
            for (Integer i = 0; i < approvalSteps.size(); i++) {
                Approval_Step__c step = approvalSteps[i];
                ApprovalStepWrapper wrapper = new ApprovalStepWrapper();
                wrapper.id = step.Id;
                wrapper.sequence = Integer.valueOf(step.Sequence__c);
                wrapper.description = step.Step_Description__c;
                wrapper.expectedStatus = step.Status__r != null ? step.Status__r.Name : '';
                
                // Check if this step has a corresponding request step
                Request_Approval_Step__c requestStep = requestStepsMap.get(step.Id);
                if (requestStep != null) {
                    wrapper.currentStatus = requestStep.Status__r != null ? requestStep.Status__r.Name : '';
                    wrapper.requestStepId = requestStep.Id;
                }
                
                Boolean isLastStep = (i == approvalSteps.size() - 1);
                Boolean statusFoundInTemplate = currentStatusIndex != -1;
                
                if (statusFoundInTemplate) {
                    if (i < currentStatusIndex) {
                        wrapper.isCompleted = true;
                        if (String.isBlank(wrapper.currentStatus)) {
                            wrapper.currentStatus = wrapper.expectedStatus;
                        }
                    } else if (i == currentStatusIndex) {
                        wrapper.isCompleted = isLastStep && currentStatusId == step.Status__c;
                        if (String.isBlank(wrapper.currentStatus) && String.isNotBlank(currentStatusName)) {
                            wrapper.currentStatus = currentStatusName;
                        }
                    } else {
                        wrapper.isCompleted = false;
                        if (String.isBlank(wrapper.currentStatus)) {
                            wrapper.currentStatus = '';
                        }
                    }
                } else if (requestStep != null) {
                    wrapper.isCompleted = requestStep.Status__c != null;
                } else if (String.isNotBlank(currentStatusName)) {
                    // No matching status in template but we still surface the current status on the first step
                    if (i == 0) {
                        wrapper.currentStatus = currentStatusName;
                    }
                    wrapper.isCompleted = false;
                } else {
                    wrapper.currentStatus = '';
                    wrapper.isCompleted = false;
                }
                
                steps.add(wrapper);
            }
            
        } catch (Exception e) {
            System.debug('Error in getApprovalSteps: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
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

