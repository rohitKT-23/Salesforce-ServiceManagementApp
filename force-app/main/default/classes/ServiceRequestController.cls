public with sharing class ServiceRequestController {
    
    @AuraEnabled(cacheable=true)
    public static ServiceFormData getServiceFormData(String serviceId) {
        ServiceFormData formData = new ServiceFormData();
        
        try {
            // Get Display Configuration for the Service
            List<Display_Configuration__c> displayConfigs = [
                SELECT Id FROM Display_Configuration__c 
                WHERE Service__c = :serviceId 
                LIMIT 1
            ];
            
            List<Service_Section__c> sections = new List<Service_Section__c>();
            
            if (!displayConfigs.isEmpty()) {
                // Get Service Sections with fields (linked through Display_Configuration__c)
                sections = [
                    SELECT Id, Name, Description__c, Sequence__c, Collapsible__c,
                           Display_Configuration__c, Condition_Group__c,
                           (SELECT Id, Name, API_Name__c, Display_Label__c, Type__c, 
                                   Sequence__c, Condition_Group__c
                            FROM Service_Section_Fields__r
                            ORDER BY Sequence__c ASC)
                    FROM Service_Section__c
                    WHERE Display_Configuration__c = :displayConfigs[0].Id
                    ORDER BY Sequence__c ASC
                ];
            }
            
            // Get Statuses
            List<Status__c> statuses = [
                SELECT Id, Name, Request_Status__c
                FROM Status__c
                WHERE Service__c = :serviceId
                ORDER BY Name ASC
            ];
            
            // Get Service Documents
            List<Service_Document__c> documents = [
                SELECT Id, Name, Document_Name__c, Mandatory__c, 
                       Allowed_Types__c, Sequence__c
                FROM Service_Document__c
                WHERE Service__c = :serviceId
                ORDER BY Sequence__c ASC
            ];
            
            // Get Condition Groups with Conditions
            Set<Id> conditionGroupIds = new Set<Id>();
            for (Service_Section__c section : sections) {
                if (section.Condition_Group__c != null) {
                    conditionGroupIds.add(section.Condition_Group__c);
                }
                for (Service_Section_Field__c field : section.Service_Section_Fields__r) {
                    if (field.Condition_Group__c != null) {
                        conditionGroupIds.add(field.Condition_Group__c);
                    }
                }
            }
            
            Map<Id, Condition_Group__c> conditionGroupsMap = new Map<Id, Condition_Group__c>([
                SELECT Id, Conditional_Logic__c,
                       (SELECT Id, Field_API_Name__c, Operator__c, Value__c, Sequence__c
                        FROM Conditions__r
                        ORDER BY Sequence__c ASC)
                FROM Condition_Group__c
                WHERE Id IN :conditionGroupIds
            ]);
            
            formData.sections = sections;
            formData.statuses = statuses;
            formData.documents = documents;
            formData.conditionGroups = conditionGroupsMap.values();
            
        } catch (Exception e) {
            throw new AuraHandledException('Error loading service form data: ' + e.getMessage());
        }
        
        return formData;
    }
    
    @AuraEnabled
    public static String saveServiceRequest(String serviceId, Map<String, Object> fieldValues) {
        try {
            Service_Request__c request = new Service_Request__c();
            // Note: Service_Request__c needs a Service__c lookup field
            // For now, we'll set it if the field exists
            try {
                request.put('Service__c', serviceId);
            } catch (Exception ex) {
                // Field doesn't exist, skip it
            }
            
            // Set field values dynamically
            for (String apiName : fieldValues.keySet()) {
                try {
                    request.put(apiName, fieldValues.get(apiName));
                } catch (Exception ex) {
                    // Skip fields that don't exist
                    System.debug('Field ' + apiName + ' does not exist: ' + ex.getMessage());
                }
            }
            
            insert request;
            return request.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving service request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateServiceRequest(String requestId, Map<String, Object> fieldValues) {
        try {
            Service_Request__c request = new Service_Request__c(Id = requestId);
            
            // Update field values dynamically
            for (String apiName : fieldValues.keySet()) {
                request.put(apiName, fieldValues.get(apiName));
            }
            
            update request;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating service request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Service_Request__c getServiceRequest(String requestId) {
        try {
            // Note: Adjust fields based on what actually exists on Service_Request__c
            return [
                SELECT Id, Name
                FROM Service_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error loading service request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<ServiceWrapper> getActiveServices() {
        try {
            List<ServiceWrapper> services = new List<ServiceWrapper>();
            List<Service__c> serviceList = [
                SELECT Id, Name, Active__c, SLA_Days__c
                FROM Service__c
                WHERE Active__c = true
                ORDER BY Sequence__c ASC, Name ASC
            ];
            
            for (Service__c svc : serviceList) {
                services.add(new ServiceWrapper(svc.Id, svc.Name, svc.SLA_Days__c));
            }
            
            return services;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading services: ' + e.getMessage());
        }
    }
    
    public class ServiceWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String slaDays;
        
        public ServiceWrapper(String id, String name, String slaDays) {
            this.id = id;
            this.name = name;
            this.slaDays = slaDays;
        }
    }
    
    public class ServiceFormData {
        @AuraEnabled public List<Service_Section__c> sections;
        @AuraEnabled public List<Status__c> statuses;
        @AuraEnabled public List<Service_Document__c> documents;
        @AuraEnabled public List<Condition_Group__c> conditionGroups;
    }
}

