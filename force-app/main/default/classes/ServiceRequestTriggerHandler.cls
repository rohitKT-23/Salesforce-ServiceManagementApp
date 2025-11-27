public with sharing class ServiceRequestTriggerHandler {
    private static Boolean isExecuting = false;

    public static void afterInsert(List<Service_Request__c> newList) {
        if (isExecuting) {
            return;
        }
        isExecuting = true;
        try {
            syncRequestApprovalSteps(newList, new Set<Id>());
        } finally {
            isExecuting = false;
        }
    }

    public static void afterUpdate(List<Service_Request__c> newList, Map<Id, Service_Request__c> oldMap) {
        if (isExecuting) {
            return;
        }
        Set<Id> resetRequestIds = new Set<Id>();
        List<Service_Request__c> requestsToProcess = new List<Service_Request__c>();

        for (Service_Request__c sr : newList) {
            Service_Request__c oldSr = oldMap.get(sr.Id);

            // Only process records where Service or Status is populated
            if (sr.Service__c == null) {
                continue;
            }

            Boolean serviceChanged = oldSr == null || sr.Service__c != oldSr.Service__c;
            Boolean statusChanged = oldSr == null || sr.Status__c != oldSr.Status__c;

            if (serviceChanged) {
                resetRequestIds.add(sr.Id);
            }

            if (serviceChanged || statusChanged) {
                requestsToProcess.add(sr);
            }
        }

        if (requestsToProcess.isEmpty()) {
            return;
        }

        isExecuting = true;
        try {
            syncRequestApprovalSteps(requestsToProcess, resetRequestIds);
        } finally {
            isExecuting = false;
        }
    }

    private static void syncRequestApprovalSteps(List<Service_Request__c> requests, Set<Id> resetRequestIds) {
        List<Service_Request__c> validRequests = new List<Service_Request__c>();
        for (Service_Request__c sr : requests) {
            if (sr.Service__c != null) {
                validRequests.add(sr);
            }
        }

        if (validRequests.isEmpty()) {
            return;
        }

        if (resetRequestIds != null && !resetRequestIds.isEmpty()) {
            List<Request_Approval_Step__c> stepsToDelete = [
                SELECT Id
                FROM Request_Approval_Step__c
                WHERE Service_Request__c IN :resetRequestIds
            ];
            if (!stepsToDelete.isEmpty()) {
                delete stepsToDelete;
            }
        }

        Set<Id> serviceIds = new Set<Id>();
        Set<Id> requestIds = new Set<Id>();
        for (Service_Request__c sr : validRequests) {
            serviceIds.add(sr.Service__c);
            requestIds.add(sr.Id);
        }

        Map<Id, List<Approval_Step__c>> stepsByService = loadApprovalSteps(serviceIds);
        Map<Id, Map<Id, Request_Approval_Step__c>> requestStepMap = loadExistingRequestSteps(requestIds);
        Map<Id, String> statusNames = loadStatusNames(serviceIds);

        List<Request_Approval_Step__c> stepsToInsert = new List<Request_Approval_Step__c>();

        for (Service_Request__c sr : validRequests) {
            List<Approval_Step__c> approvalSteps = stepsByService.get(sr.Service__c);
            if (approvalSteps == null || approvalSteps.isEmpty()) {
                continue;
            }

            Map<Id, Request_Approval_Step__c> stepsForRequest = requestStepMap.get(sr.Id);
            if (stepsForRequest == null) {
                stepsForRequest = new Map<Id, Request_Approval_Step__c>();
                requestStepMap.put(sr.Id, stepsForRequest);
            }

            for (Approval_Step__c step : approvalSteps) {
                if (!stepsForRequest.containsKey(step.Id)) {
                    Request_Approval_Step__c ras = new Request_Approval_Step__c();
                    ras.Service_Request__c = sr.Id;
                    ras.Service__c = sr.Service__c;
                    ras.Approval_Step__c = step.Id;
                    ras.Sequence__c = step.Sequence__c;
                    ras.Name = buildStepName(sr.Name, step.Status__c, statusNames, step.Sequence__c);
                    stepsToInsert.add(ras);
                    stepsForRequest.put(step.Id, ras);
                }
            }
        }

        if (!stepsToInsert.isEmpty()) {
            insert stepsToInsert;
        }

        updateRequestStepStatuses(validRequests, stepsByService, requestStepMap, statusNames);
    }

    private static Map<Id, List<Approval_Step__c>> loadApprovalSteps(Set<Id> serviceIds) {
        Map<Id, List<Approval_Step__c>> stepsByService = new Map<Id, List<Approval_Step__c>>();
        if (serviceIds.isEmpty()) {
            return stepsByService;
        }

        List<Approval_Step__c> approvalSteps = [
            SELECT Id, Service__c, Sequence__c, Status__c
            FROM Approval_Step__c
            WHERE Service__c IN :serviceIds
            ORDER BY Sequence__c ASC
        ];

        for (Approval_Step__c step : approvalSteps) {
            if (!stepsByService.containsKey(step.Service__c)) {
                stepsByService.put(step.Service__c, new List<Approval_Step__c>());
            }
            stepsByService.get(step.Service__c).add(step);
        }
        return stepsByService;
    }

    private static Map<Id, Map<Id, Request_Approval_Step__c>> loadExistingRequestSteps(Set<Id> requestIds) {
        Map<Id, Map<Id, Request_Approval_Step__c>> requestStepMap = new Map<Id, Map<Id, Request_Approval_Step__c>>();
        if (requestIds.isEmpty()) {
            return requestStepMap;
        }

        List<Request_Approval_Step__c> existingSteps = [
            SELECT Id, Service_Request__c, Approval_Step__c, Service__c, Sequence__c, Status__c
            FROM Request_Approval_Step__c
            WHERE Service_Request__c IN :requestIds
        ];

        for (Request_Approval_Step__c ras : existingSteps) {
            if (!requestStepMap.containsKey(ras.Service_Request__c)) {
                requestStepMap.put(ras.Service_Request__c, new Map<Id, Request_Approval_Step__c>());
            }
            requestStepMap.get(ras.Service_Request__c).put(ras.Approval_Step__c, ras);
        }
        return requestStepMap;
    }

    private static void updateRequestStepStatuses(
        List<Service_Request__c> requests,
        Map<Id, List<Approval_Step__c>> stepsByService,
        Map<Id, Map<Id, Request_Approval_Step__c>> requestStepMap,
        Map<Id, String> statusNames
    ) {
        List<Request_Approval_Step__c> stepsToUpdate = new List<Request_Approval_Step__c>();

        for (Service_Request__c sr : requests) {
            List<Approval_Step__c> approvalSteps = stepsByService.get(sr.Service__c);
            if (approvalSteps == null || approvalSteps.isEmpty()) {
                continue;
            }

            Map<Id, Request_Approval_Step__c> stepsForRequest = requestStepMap.get(sr.Id);
            if (stepsForRequest == null || stepsForRequest.isEmpty()) {
                continue;
            }

            Integer currentIndex = getCurrentStatusIndex(sr.Status__c, approvalSteps);
            if (currentIndex == -1 && sr.Status__c == null) {
                continue;
            }

            for (Integer i = 0; i < approvalSteps.size(); i++) {
                Approval_Step__c templateStep = approvalSteps[i];
                Request_Approval_Step__c requestStep = stepsForRequest.get(templateStep.Id);
                if (requestStep == null) {
                    continue;
                }

                Id desiredStatusId;
                if (currentIndex == -1) {
                    desiredStatusId = requestStep.Status__c;
                } else if (i < currentIndex) {
                    desiredStatusId = templateStep.Status__c;
                } else if (i == currentIndex) {
                    desiredStatusId = sr.Status__c;
                } else {
                    desiredStatusId = null;
                }

                Id nameStatusId = desiredStatusId != null ? desiredStatusId : templateStep.Status__c;
                String desiredName = buildStepName(sr.Name, nameStatusId, statusNames, templateStep.Sequence__c);

                Boolean statusChanged = requestStep.Status__c != desiredStatusId;
                Boolean nameChanged = desiredName != requestStep.Name;

                if (statusChanged) {
                    requestStep.Status__c = desiredStatusId;
                }
                if (nameChanged) {
                    requestStep.Name = desiredName;
                }
                if ((statusChanged || nameChanged) && requestStep.Id != null) {
                    stepsToUpdate.add(requestStep);
                }
            }
        }

        if (!stepsToUpdate.isEmpty()) {
            update stepsToUpdate;
        }
    }

    private static Integer getCurrentStatusIndex(Id currentStatusId, List<Approval_Step__c> steps) {
        if (currentStatusId == null || steps == null) {
            return -1;
        }

        for (Integer i = 0; i < steps.size(); i++) {
            Approval_Step__c templateStep = steps[i];
            if (templateStep.Status__c == currentStatusId) {
                return i;
            }
        }
        return -1;
    }

    private static Map<Id, String> loadStatusNames(Set<Id> serviceIds) {
        Map<Id, String> statusNames = new Map<Id, String>();
        if (serviceIds.isEmpty()) {
            return statusNames;
        }

        for (Status__c statusRecord : [
            SELECT Id, Name, Service__c
            FROM Status__c
            WHERE Service__c IN :serviceIds
        ]) {
            statusNames.put(statusRecord.Id, statusRecord.Name);
        }
        return statusNames;
    }

    private static String buildStepName(String requestName, Id statusId, Map<Id, String> statusNames, Decimal sequenceNumber) {
        String statusLabel = statusId != null && statusNames.containsKey(statusId)
            ? statusNames.get(statusId)
            : null;

        if (statusLabel == null && sequenceNumber != null) {
            statusLabel = 'Step ' + String.valueOf(sequenceNumber.intValue());
        }

        if (String.isBlank(requestName)) {
            requestName = 'Service Request';
        }

        String composedName = statusLabel != null
            ? requestName + ' - ' + statusLabel
            : requestName;

        if (composedName.length() > 80) {
            composedName = composedName.substring(0, 80);
        }
        return composedName;
    }
}

