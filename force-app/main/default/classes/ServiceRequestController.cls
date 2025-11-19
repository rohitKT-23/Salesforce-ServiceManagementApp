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
                                   Sequence__c, Condition_Group__c, Picklist_Values__c
                            FROM Service_Section_Fields__r
                            ORDER BY Sequence__c ASC)
                    FROM Service_Section__c
                    WHERE Display_Configuration__c = :displayConfigs[0].Id
                    ORDER BY Sequence__c ASC
                ];
            }
            
            // Get Statuses - Order to show Draft first, then alphabetically
            List<Status__c> statuses = [
                SELECT Id, Name, Request_Status__c
                FROM Status__c
                WHERE Service__c = :serviceId
                ORDER BY Name ASC
            ];
            
            // Reorder to put Draft first if it exists
            List<Status__c> orderedStatuses = new List<Status__c>();
            Status__c draftStatus = null;
            
            for (Status__c status : statuses) {
                if (status.Name == 'Draft') {
                    draftStatus = status;
                } else {
                    orderedStatuses.add(status);
                }
            }
            
            // Put Draft at the beginning
            if (draftStatus != null) {
                statuses = new List<Status__c>{draftStatus};
                statuses.addAll(orderedStatuses);
            }
            
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
            // Get Service Name
            String serviceName = '';
            try {
                Service__c service = [SELECT Name FROM Service__c WHERE Id = :serviceId LIMIT 1];
                serviceName = service.Name;
            } catch (Exception ex) {
                System.debug('Error getting service name: ' + ex.getMessage());
            }
            
            // Get First Name from Personal Information section
            String firstName = '';
            if (fieldValues.containsKey('FirstName__c')) {
                Object firstNameObj = fieldValues.get('FirstName__c');
                if (firstNameObj != null) {
                    firstName = String.valueOf(firstNameObj).trim();
                }
            }
            
            // Get Priority from Request Details section
            String priority = '';
            if (fieldValues.containsKey('Priority__c')) {
                Object priorityObj = fieldValues.get('Priority__c');
                if (priorityObj != null) {
                    priority = String.valueOf(priorityObj).trim();
                }
            }
            
            // Build custom name: ServiceName-FirstName-Priority (with dash)
            List<String> nameParts = new List<String>();
            if (serviceName != '') nameParts.add(serviceName);
            if (firstName != '') nameParts.add(firstName);
            if (priority != '') nameParts.add(priority);
            String customName = String.join(nameParts, '-');

            // If no custom name could be built, use default
            if (customName == '') {
                customName = 'Service Request';
            }

            Service_Request__c request = new Service_Request__c();
            // Set custom name
            request.Name = customName;

            // Set Service__c lookup field if it exists
            try {
                request.put('Service__c', serviceId);
            } catch (Exception ex) {
                // Field doesn't exist, skip it
            }

            // Set field values dynamically
            for (String apiName : fieldValues.keySet()) {
                try {
                    // Skip Name field as we're setting it manually
                    if (apiName.toLowerCase() != 'name') {
                        request.put(apiName, fieldValues.get(apiName));
                    }
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
    
    @AuraEnabled(cacheable=true)
    public static List<ServiceRequestWrapper> searchServiceRequests(String searchTerm) {
        try {
            List<ServiceRequestWrapper> requests = new List<ServiceRequestWrapper>();
            String searchPattern = '%' + (searchTerm != null ? searchTerm : '') + '%';
            
            List<Service_Request__c> requestList = [
                SELECT Id, Name, Service__c, Service__r.Name, CreatedDate, Status__c, Status__r.Name
                FROM Service_Request__c
                WHERE Name LIKE :searchPattern
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            for (Service_Request__c req : requestList) {
                requests.add(new ServiceRequestWrapper(
                    req.Id,
                    req.Name,
                    req.Service__r != null ? req.Service__r.Name : '',
                    req.CreatedDate,
                    req.Status__r != null ? req.Status__r.Name : ''
                ));
            }
            
            return requests;
        } catch (Exception e) {
            throw new AuraHandledException('Error searching service requests: ' + e.getMessage());
        }
    }
    
    public class ServiceRequestWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String serviceName;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String status;
        
        public ServiceRequestWrapper(String id, String name, String serviceName, DateTime createdDate, String status) {
            this.id = id;
            this.name = name;
            this.serviceName = serviceName;
            this.createdDate = createdDate;
            this.status = status;
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
    
    @AuraEnabled
    public static void linkDocumentToRequest(String serviceRequestId, String contentDocumentId, String serviceDocumentId, String fileName) {
        try {
            // Get Service Request to get Service__c
            Service_Request__c serviceRequest = [
                SELECT Id, Service__c, Name
                FROM Service_Request__c
                WHERE Id = :serviceRequestId
                LIMIT 1
            ];
            
            // Get ContentDocument to get file name and type
            ContentDocument contentDoc = [
                SELECT Id, Title, FileExtension
                FROM ContentDocument
                WHERE Id = :contentDocumentId
                LIMIT 1
            ];
            
            // Get file extension for Type field
            String fileExtension = contentDoc.FileExtension != null ? '.' + contentDoc.FileExtension.toLowerCase() : '';
            // Ensure it's a valid picklist value (.pdf or .jpg)
            if (fileExtension != '.pdf' && fileExtension != '.jpg') {
                fileExtension = ''; // Leave empty if not valid
            }
            
            // Get next sequence number for this service request
            List<Request_Document__c> existingDocs = [
                SELECT Sequence__c
                FROM Request_Document__c
                WHERE Service_Request__c = :serviceRequestId
                ORDER BY Sequence__c DESC NULLS LAST
                LIMIT 1
            ];
            
            Decimal nextSequence = 1;
            if (!existingDocs.isEmpty() && existingDocs[0].Sequence__c != null) {
                nextSequence = existingDocs[0].Sequence__c + 1;
            }
            
            // Create Request_Document__c record
            Request_Document__c requestDoc = new Request_Document__c();
            requestDoc.Service_Request__c = serviceRequestId;
            requestDoc.Content_Document_Id__c = contentDocumentId;
            requestDoc.Name = fileName != null ? fileName : contentDoc.Title; // Request Document Name
            requestDoc.Sequence__c = nextSequence; // Sequence number
            requestDoc.Service__c = serviceRequest.Service__c; // Service from Service Request
            
            // Set Type if valid
            if (fileExtension != '') {
                requestDoc.Type__c = fileExtension;
            }
            
            // Get Service Document details if provided
            if (serviceDocumentId != null) {
                Service_Document__c serviceDoc = [
                    SELECT Id, Service__c, Name, Document_Name__c 
                    FROM Service_Document__c 
                    WHERE Id = :serviceDocumentId 
                    LIMIT 1
                ];
                requestDoc.Service_Document__c = serviceDocumentId;
                // Use Service Document's Service if available, otherwise use from Service Request
                if (serviceDoc.Service__c != null) {
                    requestDoc.Service__c = serviceDoc.Service__c;
                }
            }
            
            insert requestDoc;
            System.debug('Request_Document__c created successfully: ' + requestDoc.Id);
            System.debug('Request Document Name: ' + requestDoc.Name);
            System.debug('Service: ' + requestDoc.Service__c);
            System.debug('Sequence: ' + requestDoc.Sequence__c);
            System.debug('Type: ' + requestDoc.Type__c);
            
            // Create ContentDocumentLinks to link file to both Service Request and Request Document
            // This makes the file visible in Files/Notes & Attachments related list on both records
            List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
            
            // Check existing links
            List<ContentDocumentLink> existingLinks = [
                SELECT Id, LinkedEntityId
                FROM ContentDocumentLink 
                WHERE ContentDocumentId = :contentDocumentId 
                AND (LinkedEntityId = :serviceRequestId OR LinkedEntityId = :requestDoc.Id)
            ];
            
            Set<Id> linkedEntityIds = new Set<Id>();
            for (ContentDocumentLink link : existingLinks) {
                linkedEntityIds.add(link.LinkedEntityId);
            }
            
            // Link to Service Request if not already linked
            if (!linkedEntityIds.contains(serviceRequestId)) {
                ContentDocumentLink cdlServiceRequest = new ContentDocumentLink();
                cdlServiceRequest.ContentDocumentId = contentDocumentId;
                cdlServiceRequest.LinkedEntityId = serviceRequestId; // Link to Service Request
                cdlServiceRequest.ShareType = 'V'; // Viewer permission
                cdlServiceRequest.Visibility = 'AllUsers'; // Visible to all users
                linksToInsert.add(cdlServiceRequest);
                System.debug('Adding ContentDocumentLink for Service Request: ' + serviceRequestId);
            }
            
            // Link to Request Document if not already linked
            if (!linkedEntityIds.contains(requestDoc.Id)) {
                ContentDocumentLink cdlRequestDoc = new ContentDocumentLink();
                cdlRequestDoc.ContentDocumentId = contentDocumentId;
                cdlRequestDoc.LinkedEntityId = requestDoc.Id; // Link to Request Document
                cdlRequestDoc.ShareType = 'V'; // Viewer permission
                cdlRequestDoc.Visibility = 'AllUsers'; // Visible to all users
                linksToInsert.add(cdlRequestDoc);
                System.debug('Adding ContentDocumentLink for Request Document: ' + requestDoc.Id);
            }
            
            if (!linksToInsert.isEmpty()) {
                insert linksToInsert;
                System.debug('ContentDocumentLinks created successfully. Count: ' + linksToInsert.size());
            } else {
                System.debug('All ContentDocumentLinks already exist');
            }
        } catch (Exception e) {
            System.debug('Error in linkDocumentToRequest: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error linking document to request: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<DocumentWrapper> getRequestDocuments(String serviceRequestId) {
        try {
            List<DocumentWrapper> documents = new List<DocumentWrapper>();
            List<Request_Document__c> requestDocs = [
                SELECT Id, Name, Content_Document_Id__c, Service_Document__c,
                       Service_Document__r.Document_Name__c, Service_Document__r.Name,
                       CreatedDate
                FROM Request_Document__c
                WHERE Service_Request__c = :serviceRequestId
                ORDER BY CreatedDate DESC
            ];
            
            for (Request_Document__c doc : requestDocs) {
                documents.add(new DocumentWrapper(
                    doc.Id,
                    doc.Name,
                    doc.Content_Document_Id__c,
                    doc.Service_Document__c,
                    doc.Service_Document__r != null ? doc.Service_Document__r.Document_Name__c : null,
                    doc.CreatedDate
                ));
            }
            
            return documents;
        } catch (Exception e) {
            throw new AuraHandledException('Error loading request documents: ' + e.getMessage());
        }
    }
    
    public class DocumentWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String serviceDocumentId;
        @AuraEnabled public String documentName;
        @AuraEnabled public DateTime createdDate;
        
        public DocumentWrapper(String id, String name, String contentDocumentId, String serviceDocumentId, String documentName, DateTime createdDate) {
            this.id = id;
            this.name = name;
            this.contentDocumentId = contentDocumentId;
            this.serviceDocumentId = serviceDocumentId;
            this.documentName = documentName;
            this.createdDate = createdDate;
        }
    }
    
    public class ServiceFormData {
        @AuraEnabled public List<Service_Section__c> sections;
        @AuraEnabled public List<Status__c> statuses;
        @AuraEnabled public List<Service_Document__c> documents;
        @AuraEnabled public List<Condition_Group__c> conditionGroups;
    }
}

