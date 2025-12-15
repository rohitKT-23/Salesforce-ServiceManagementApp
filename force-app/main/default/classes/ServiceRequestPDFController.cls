/**
 * @description Controller for Service Request PDF generation
 * Fetches all related data for PDF rendering including service details,
 * pricing summary, uploaded documents, and approval timeline.
 */
public with sharing class ServiceRequestPDFController {
    
    // Properties for Visualforce binding
    public Service_Request__c serviceRequest { get; set; }
    public Service__c service { get; set; }
    public Service_Pricing__c pricing { get; set; }
    public List<Request_Document__c> documents { get; set; }
    public List<ApprovalStepInfo> approvalSteps { get; set; }
    public List<FieldValuePair> requestFields { get; set; }
    public User currentUser { get; set; }
    public DateTime generatedDateTime { get; set; }
    public String errorMessage { get; set; }
    
    // Recent requests for the generator page
    public List<Service_Request__c> recentRequests { 
        get {
            if (recentRequests == null) {
                try {
                    recentRequests = [
                        SELECT Id, Name, CreatedDate, Service__r.Name, Status__r.Name
                        FROM Service_Request__c
                        ORDER BY CreatedDate DESC
                        LIMIT 5
                    ];
                } catch (Exception e) {
                    recentRequests = new List<Service_Request__c>();
                }
            }
            return recentRequests;
        }
        set;
    }
    
    // Calculated totals
    public Decimal subtotal { get; set; }
    public Decimal discountAmount { get; set; }
    public Decimal totalAmount { get; set; }
    
    /**
     * @description Constructor - initializes data based on recordId parameter
     */
    public ServiceRequestPDFController() {
        initializeData(null);
    }
    
    /**
     * @description Constructor for standard controller extension
     */
    public ServiceRequestPDFController(ApexPages.StandardController stdController) {
        initializeData(stdController.getId());
    }
    
    /**
     * @description Initialize all data for the PDF
     */
    private void initializeData(String passedRecordId) {
        // Try to get recordId from multiple sources
        String recordId = passedRecordId;
        
        // If not passed, try URL parameter 'id'
        if (String.isBlank(recordId)) {
            recordId = ApexPages.currentPage().getParameters().get('id');
        }
        
        // Also try 'Id' (capital I) as some systems use this
        if (String.isBlank(recordId)) {
            recordId = ApexPages.currentPage().getParameters().get('Id');
        }
        
        // Also try 'recordId' parameter
        if (String.isBlank(recordId)) {
            recordId = ApexPages.currentPage().getParameters().get('recordId');
        }
        
        // Debug logging
        System.debug('ServiceRequestPDFController - recordId: ' + recordId);
        System.debug('ServiceRequestPDFController - URL params: ' + ApexPages.currentPage().getParameters());
        
        generatedDateTime = DateTime.now();
        documents = new List<Request_Document__c>();
        approvalSteps = new List<ApprovalStepInfo>();
        requestFields = new List<FieldValuePair>();
        subtotal = 0;
        discountAmount = 0;
        totalAmount = 0;
        
        if (String.isBlank(recordId)) {
            errorMessage = 'No Service Request ID provided. Please access this page with a valid Service Request record.';
            return;
        }
        
        try {
            // Get current user info
            currentUser = [
                SELECT Id, Name, Email, Title, Department, Phone
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            // Get Service Request with all standard fields
            List<Service_Request__c> requests = [
                SELECT Id, Name, CreatedDate, LastModifiedDate, OwnerId, Owner.Name,
                       Service__c, Service__r.Name, Service__r.SLA_Days__c, Service__r.Service_Type__c,
                       Service_Pricing__c, Service_Pricing__r.Name, Service_Pricing__r.Pricing_Name__c,
                       Service_Pricing__r.Amount__c, Service_Pricing__r.Discount__c,
                       Service_Pricing__r.Discount_Percentage__c, Service_Pricing__r.Total__c,
                       Status__c, Status__r.Name, Status__r.Request_Status__c
                FROM Service_Request__c
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (requests.isEmpty()) {
                errorMessage = 'Service Request not found.';
                return;
            }
            
            serviceRequest = requests[0];
            
            // Get Service details
            if (serviceRequest.Service__c != null) {
                List<Service__c> services = [
                    SELECT Id, Name, Active__c, SLA_Days__c, Service_Type__c, Version__c
                    FROM Service__c
                    WHERE Id = :serviceRequest.Service__c
                    LIMIT 1
                ];
                if (!services.isEmpty()) {
                    service = services[0];
                }
            }
            
            // Get Pricing details
            if (serviceRequest.Service_Pricing__c != null) {
                List<Service_Pricing__c> pricings = [
                    SELECT Id, Name, Pricing_Name__c, Amount__c, Discount__c,
                           Discount_Percentage__c, Total__c
                    FROM Service_Pricing__c
                    WHERE Id = :serviceRequest.Service_Pricing__c
                    LIMIT 1
                ];
                if (!pricings.isEmpty()) {
                    pricing = pricings[0];
                    calculateTotals();
                }
            }
            
            // Get dynamic field values from the record
            loadDynamicFields(recordId);
            
            // Get uploaded documents
            documents = [
                SELECT Id, Name, Content_Document_Id__c, Type__c, Sequence__c,
                       Service_Document__c, Service_Document__r.Document_Name__c,
                       CreatedDate, CreatedBy.Name
                FROM Request_Document__c
                WHERE Service_Request__c = :recordId
                ORDER BY Sequence__c ASC, CreatedDate ASC
            ];
            
            // Get approval timeline
            loadApprovalSteps(recordId);
            
        } catch (Exception e) {
            errorMessage = 'Error loading data: ' + e.getMessage();
            System.debug('ServiceRequestPDFController Error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Calculate pricing totals
     */
    private void calculateTotals() {
        if (pricing != null) {
            subtotal = pricing.Amount__c != null ? pricing.Amount__c : 0;
            discountAmount = pricing.Discount__c != null ? pricing.Discount__c : 0;
            totalAmount = pricing.Total__c != null ? pricing.Total__c : subtotal - discountAmount;
        }
    }
    
    /**
     * @description Load dynamic fields from Service Request using describe
     */
    private void loadDynamicFields(String recordId) {
        try {
            // Get all fields from Service_Request__c
            Schema.DescribeSObjectResult describeResult = Service_Request__c.SObjectType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = describeResult.fields.getMap();
            
            // Build dynamic query with all accessible fields
            List<String> fieldNames = new List<String>();
            for (String fieldName : fieldMap.keySet()) {
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                if (fieldDescribe.isAccessible() && fieldDescribe.isCustom()) {
                    // Skip lookup fields and standard system fields
                    if (fieldDescribe.getType() != Schema.DisplayType.REFERENCE) {
                        fieldNames.add(fieldName);
                    }
                }
            }
            
            if (!fieldNames.isEmpty()) {
                String query = 'SELECT ' + String.join(fieldNames, ', ') + ' FROM Service_Request__c WHERE Id = :recordId LIMIT 1';
                List<Service_Request__c> results = Database.query(query);
                
                if (!results.isEmpty()) {
                    Service_Request__c record = results[0];
                    
                    for (String fieldName : fieldNames) {
                        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
                        Object fieldValue = record.get(fieldName);
                        
                        if (fieldValue != null && String.valueOf(fieldValue) != '') {
                            FieldValuePair fvp = new FieldValuePair();
                            fvp.label = fieldDescribe.getLabel();
                            fvp.value = formatFieldValue(fieldValue, fieldDescribe.getType());
                            fvp.apiName = fieldName;
                            requestFields.add(fvp);
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error loading dynamic fields: ' + e.getMessage());
        }
    }
    
    /**
     * @description Format field value based on type
     */
    private String formatFieldValue(Object value, Schema.DisplayType fieldType) {
        if (value == null) return '';
        
        if (fieldType == Schema.DisplayType.DATE) {
            return ((Date)value).format();
        } else if (fieldType == Schema.DisplayType.DATETIME) {
            return ((DateTime)value).format();
        } else if (fieldType == Schema.DisplayType.CURRENCY || fieldType == Schema.DisplayType.DOUBLE) {
            return String.valueOf(value);
        } else if (fieldType == Schema.DisplayType.BOOLEAN) {
            return (Boolean)value ? 'Yes' : 'No';
        }
        
        return String.valueOf(value);
    }
    
    /**
     * @description Load approval steps timeline
     */
    private void loadApprovalSteps(String recordId) {
        try {
            if (serviceRequest.Service__c == null) {
                return;
            }
            
            Id serviceId = serviceRequest.Service__c;
            
            // Get Request Approval Steps
            List<Request_Approval_Step__c> requestSteps = [
                SELECT Id, Sequence__c, Status__c, Status__r.Name,
                       Approval_Step__c, Approval_Step__r.Step_Description__c,
                       CreatedDate, LastModifiedDate
                FROM Request_Approval_Step__c
                WHERE Service_Request__c = :recordId
                ORDER BY Sequence__c ASC
            ];
            
            // Get Approval Steps template
            List<Approval_Step__c> templateSteps = [
                SELECT Id, Sequence__c, Step_Description__c, Status__c, Status__r.Name
                FROM Approval_Step__c
                WHERE Service__c = :serviceId
                ORDER BY Sequence__c ASC
            ];
            
            // Map request steps by approval step ID
            Map<Id, Request_Approval_Step__c> requestStepsMap = new Map<Id, Request_Approval_Step__c>();
            for (Request_Approval_Step__c rs : requestSteps) {
                if (rs.Approval_Step__c != null) {
                    requestStepsMap.put(rs.Approval_Step__c, rs);
                }
            }
            
            // Determine current status index
            Id currentStatusId = serviceRequest.Status__c;
            Integer currentStatusIndex = -1;
            
            for (Integer i = 0; i < templateSteps.size(); i++) {
                if (currentStatusId != null && templateSteps[i].Status__c == currentStatusId) {
                    currentStatusIndex = i;
                    break;
                }
            }
            
            // Build approval steps list
            for (Integer i = 0; i < templateSteps.size(); i++) {
                Approval_Step__c step = templateSteps[i];
                ApprovalStepInfo info = new ApprovalStepInfo();
                info.sequence = Integer.valueOf(step.Sequence__c);
                info.description = step.Step_Description__c;
                info.expectedStatus = step.Status__r != null ? step.Status__r.Name : '';
                
                Request_Approval_Step__c reqStep = requestStepsMap.get(step.Id);
                if (reqStep != null) {
                    info.currentStatus = reqStep.Status__r != null ? reqStep.Status__r.Name : '';
                    info.completedDate = reqStep.LastModifiedDate;
                    info.isCompleted = true;
                } else if (currentStatusIndex != -1 && i < currentStatusIndex) {
                    info.isCompleted = true;
                    info.currentStatus = info.expectedStatus;
                } else if (currentStatusIndex != -1 && i == currentStatusIndex) {
                    info.isCompleted = (i == templateSteps.size() - 1);
                    info.currentStatus = serviceRequest.Status__r != null ? serviceRequest.Status__r.Name : '';
                } else {
                    info.isCompleted = false;
                    info.currentStatus = 'Pending';
                }
                
                approvalSteps.add(info);
            }
            
        } catch (Exception e) {
            System.debug('Error loading approval steps: ' + e.getMessage());
        }
    }
    
    /**
     * @description Wrapper class for field-value pairs
     */
    public class FieldValuePair {
        public String label { get; set; }
        public String value { get; set; }
        public String apiName { get; set; }
    }
    
    /**
     * @description Wrapper class for approval step information
     */
    public class ApprovalStepInfo {
        public Integer sequence { get; set; }
        public String description { get; set; }
        public String expectedStatus { get; set; }
        public String currentStatus { get; set; }
        public Boolean isCompleted { get; set; }
        public DateTime completedDate { get; set; }
        
        public String getFormattedDate() {
            if (completedDate != null) {
                return completedDate.format('MMM dd, yyyy HH:mm');
            }
            return '';
        }
        
        public String getStatusIcon() {
            return isCompleted ? '✓' : '○';
        }
    }
    
    /**
     * @description Remote action to search Service Requests by name
     * @param searchTerm Search term to filter by name
     * @return List of Service Request wrapper objects
     */
    @RemoteAction
    public static List<ServiceRequestOption> searchServiceRequests(String searchTerm) {
        List<ServiceRequestOption> options = new List<ServiceRequestOption>();
        
        try {
            String searchPattern = '%' + (String.isNotBlank(searchTerm) ? searchTerm : '') + '%';
            
            List<Service_Request__c> requests = [
                SELECT Id, Name, CreatedDate, Service__r.Name, Status__r.Name
                FROM Service_Request__c
                WHERE Name LIKE :searchPattern
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];
            
            for (Service_Request__c req : requests) {
                ServiceRequestOption option = new ServiceRequestOption();
                option.id = req.Id;
                option.name = req.Name;
                option.serviceName = req.Service__r != null ? req.Service__r.Name : '';
                option.status = req.Status__r != null ? req.Status__r.Name : '';
                option.createdDate = req.CreatedDate;
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('Error searching service requests: ' + e.getMessage());
        }
        
        return options;
    }
    
    /**
     * @description Wrapper class for Service Request dropdown options
     */
    public class ServiceRequestOption {
        public String id { get; set; }
        public String name { get; set; }
        public String serviceName { get; set; }
        public String status { get; set; }
        public DateTime createdDate { get; set; }
    }
}

