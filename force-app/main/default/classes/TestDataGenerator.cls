/**
 * Test Data Generator for Service Management App
 * 
 * This class creates realistic dummy data for testing the Service Management App.
 * 
 * Usage: Execute in Anonymous Apex or Developer Console
 * 
 * TestDataGenerator.createAllTestData();
 */
public class TestDataGenerator {
    
    public static void createAllTestData() {
        System.debug('=== Starting Test Data Generation ===');
        
        // Create Services
        List<Service__c> services = createServices();
        insert services;
        System.debug('Created ' + services.size() + ' Services');
        
        // Create Display Configurations
        List<Display_Configuration__c> displayConfigs = createDisplayConfigurations(services);
        insert displayConfigs;
        System.debug('Created ' + displayConfigs.size() + ' Display Configurations');
        
        // Create Service Sections
        List<Service_Section__c> sections = createServiceSections(displayConfigs);
        insert sections;
        System.debug('Created ' + sections.size() + ' Service Sections');
        
        // Create Service Section Fields
        List<Service_Section_Field__c> fields = createServiceSectionFields(sections);
        insert fields;
        System.debug('Created ' + fields.size() + ' Service Section Fields');
        
        // Create Statuses
        List<Status__c> statuses = createStatuses(services);
        insert statuses;
        System.debug('Created ' + statuses.size() + ' Statuses');
        
        // Create Service Documents
        List<Service_Document__c> documents = createServiceDocuments(services);
        insert documents;
        System.debug('Created ' + documents.size() + ' Service Documents');

        // Create Service Pricing
        List<Service_Pricing__c> pricings = createServicePricings(services, displayConfigs);
        insert pricings;
        System.debug('Created ' + pricings.size() + ' Service Pricing records');
        
        // Create Approval Steps
        List<Approval_Step__c> approvalSteps = createApprovalSteps(services, statuses);
        insert approvalSteps;
        System.debug('Created ' + approvalSteps.size() + ' Approval Steps');
        
        System.debug('=== Test Data Generation Complete ===');
        System.debug('Service IDs:');
        for (Service__c s : services) {
            System.debug('  - ' + s.Name + ': ' + s.Id);
        }
    }
    
    private static List<Service__c> createServices() {
        List<Service__c> services = new List<Service__c>();
        
        Service__c svc1 = new Service__c();
        svc1.Name = 'IT Support Request';
        svc1.Active__c = true;
        svc1.SLA_Days__c = '3';
        svc1.Sequence__c = 1;
        services.add(svc1);
        
        Service__c svc2 = new Service__c();
        svc2.Name = 'Employee Onboarding';
        svc2.Active__c = true;
        svc2.SLA_Days__c = '5';
        svc2.Sequence__c = 2;
        services.add(svc2);
        
        Service__c svc3 = new Service__c();
        svc3.Name = 'Partner Registration';
        svc3.Active__c = true;
        svc3.SLA_Days__c = '7';
        svc3.Sequence__c = 3;
        services.add(svc3);
        
        return services;
    }
    
    private static List<Display_Configuration__c> createDisplayConfigurations(List<Service__c> services) {
        List<Display_Configuration__c> configs = new List<Display_Configuration__c>();
        
        for (Service__c service : services) {
            configs.add(new Display_Configuration__c(
                Name = service.Name + ' - Display Config',
                Service__c = service.Id,
                Display_Label__c = service.Name + ' Form',
                Sequence__c = 1
            ));
        }
        
        return configs;
    }
    
    private static List<Service_Section__c> createServiceSections(List<Display_Configuration__c> configs) {
        List<Service_Section__c> sections = new List<Service_Section__c>();
        
        for (Display_Configuration__c config : configs) {
            // Section 1: Personal Information
            sections.add(new Service_Section__c(
                Name = 'Personal Information',
                Display_Configuration__c = config.Id,
                Description__c = 'Please provide your personal details',
                Sequence__c = 1,
                Collapsible__c = false
            ));
            
            // Section 2: Request Details
            sections.add(new Service_Section__c(
                Name = 'Request Details',
                Display_Configuration__c = config.Id,
                Description__c = 'Details about your request',
                Sequence__c = 2,
                Collapsible__c = true
            ));
            
            // Section 3: Additional Information
            sections.add(new Service_Section__c(
                Name = 'Additional Information',
                Display_Configuration__c = config.Id,
                Description__c = 'Any additional information you would like to provide',
                Sequence__c = 3,
                Collapsible__c = true
            ));
        }
        
        return sections;
    }
    
    private static List<Service_Section_Field__c> createServiceSectionFields(List<Service_Section__c> sections) {
        List<Service_Section_Field__c> fields = new List<Service_Section_Field__c>();
        
        // Group sections by Display Configuration
        Map<Id, List<Service_Section__c>> sectionsByConfig = new Map<Id, List<Service_Section__c>>();
        for (Service_Section__c section : sections) {
            if (!sectionsByConfig.containsKey(section.Display_Configuration__c)) {
                sectionsByConfig.put(section.Display_Configuration__c, new List<Service_Section__c>());
            }
            sectionsByConfig.get(section.Display_Configuration__c).add(section);
        }
        
        for (Id configId : sectionsByConfig.keySet()) {
            List<Service_Section__c> configSections = sectionsByConfig.get(configId);
            
            // Find Personal Information section (Sequence 1)
            Service_Section__c personalSection = null;
            Service_Section__c requestSection = null;
            Service_Section__c additionalSection = null;
            
            for (Service_Section__c sec : configSections) {
                if (sec.Sequence__c == 1) personalSection = sec;
                if (sec.Sequence__c == 2) requestSection = sec;
                if (sec.Sequence__c == 3) additionalSection = sec;
            }
            
            // Personal Information Fields
            if (personalSection != null) {
                fields.add(new Service_Section_Field__c(
                    Name = 'First Name',
                    Service_Section__c = personalSection.Id,
                    API_Name__c = 'FirstName__c',
                    Display_Label__c = 'First Name',
                    Type__c = 'Text',
                    Sequence__c = 1
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Last Name',
                    Service_Section__c = personalSection.Id,
                    API_Name__c = 'LastName__c',
                    Display_Label__c = 'Last Name',
                    Type__c = 'Text',
                    Sequence__c = 2
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Email',
                    Service_Section__c = personalSection.Id,
                    API_Name__c = 'Email__c',
                    Display_Label__c = 'Email Address',
                    Type__c = 'Text',
                    Sequence__c = 3
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Phone',
                    Service_Section__c = personalSection.Id,
                    API_Name__c = 'Phone__c',
                    Display_Label__c = 'Phone Number',
                    Type__c = 'Text',
                    Sequence__c = 4
                ));
            }
            
            // Request Details Fields
            if (requestSection != null) {
                fields.add(new Service_Section_Field__c(
                    Name = 'Request Type',
                    Service_Section__c = requestSection.Id,
                    API_Name__c = 'RequestType__c',
                    Display_Label__c = 'Request Type',
                    Type__c = 'Picklist',
                    Picklist_Values__c = 'Hardware,Software,Network,Other',
                    Sequence__c = 1
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Priority',
                    Service_Section__c = requestSection.Id,
                    API_Name__c = 'Priority__c',
                    Display_Label__c = 'Priority',
                    Type__c = 'Picklist',
                    Picklist_Values__c = 'Low,Medium,High,Urgent',
                    Sequence__c = 2
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Description',
                    Service_Section__c = requestSection.Id,
                    API_Name__c = 'Description__c',
                    Display_Label__c = 'Request Description',
                    Type__c = 'Text',
                    Sequence__c = 3
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Requested Date',
                    Service_Section__c = requestSection.Id,
                    API_Name__c = 'RequestedDate__c',
                    Display_Label__c = 'Requested Date',
                    Type__c = 'Date',
                    Sequence__c = 4
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Budget Amount',
                    Service_Section__c = requestSection.Id,
                    API_Name__c = 'BudgetAmount__c',
                    Display_Label__c = 'Budget Amount',
                    Type__c = 'Currency',
                    Sequence__c = 5
                ));
            }
            
            // Additional Information Fields
            if (additionalSection != null) {
                fields.add(new Service_Section_Field__c(
                    Name = 'Department',
                    Service_Section__c = additionalSection.Id,
                    API_Name__c = 'Department__c',
                    Display_Label__c = 'Department',
                    Type__c = 'Text',
                    Sequence__c = 1
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Manager Name',
                    Service_Section__c = additionalSection.Id,
                    API_Name__c = 'ManagerName__c',
                    Display_Label__c = 'Manager Name',
                    Type__c = 'Text',
                    Sequence__c = 2
                ));
                
                fields.add(new Service_Section_Field__c(
                    Name = 'Employee Count',
                    Service_Section__c = additionalSection.Id,
                    API_Name__c = 'EmployeeCount__c',
                    Display_Label__c = 'Number of Employees',
                    Type__c = 'Number',
                    Sequence__c = 3
                ));
            }
        }
        
        return fields;
    }
    
    private static List<Status__c> createStatuses(List<Service__c> services) {
        List<Status__c> statuses = new List<Status__c>();
        
        // Note: Request_Status__c uses a Global Value Set "Status" 
        // We'll create statuses without Request_Status__c to avoid picklist errors
        // You can manually update Request_Status__c after creation if needed
        for (Service__c service : services) {
            statuses.add(new Status__c(
                Name = 'Draft',
                Service__c = service.Id,
                Active__c = true
            ));
            
            statuses.add(new Status__c(
                Name = 'New',
                Service__c = service.Id,
                Active__c = true
            ));
            
            statuses.add(new Status__c(
                Name = 'In Progress',
                Service__c = service.Id,
                Active__c = true
            ));
            
            statuses.add(new Status__c(
                Name = 'Under Review',
                Service__c = service.Id,
                Active__c = true
            ));
            
            statuses.add(new Status__c(
                Name = 'Approved',
                Service__c = service.Id,
                Active__c = true
            ));
            
            statuses.add(new Status__c(
                Name = 'Completed',
                Service__c = service.Id,
                Active__c = true
            ));
        }
        
        return statuses;
    }
    
    private static List<Service_Document__c> createServiceDocuments(List<Service__c> services) {
        List<Service_Document__c> documents = new List<Service_Document__c>();
        
        for (Service__c service : services) {
            documents.add(new Service_Document__c(
                Name = 'Identification Document',
                Service__c = service.Id,
                Document_Name__c = 'ID Proof',
                Mandatory__c = true,
                Allowed_Types__c = '.pdf',
                Sequence__c = 1
            ));
            
            documents.add(new Service_Document__c(
                Name = 'Supporting Documents',
                Service__c = service.Id,
                Document_Name__c = 'Supporting Documents',
                Mandatory__c = false,
                Allowed_Types__c = '.jpg',
                Sequence__c = 2
            ));
        }
        
        return documents;
    }

    private static List<Service_Pricing__c> createServicePricings(List<Service__c> services, List<Display_Configuration__c> configs) {
        List<Service_Pricing__c> pricings = new List<Service_Pricing__c>();
        Map<Id, Id> configByService = new Map<Id, Id>();
        for (Display_Configuration__c config : configs) {
            configByService.put(config.Service__c, config.Id);
        }

        for (Service__c service : services) {
            Decimal baseAmount = getBaseAmount(service.Name);
            Id configId = configByService.containsKey(service.Id) ? configByService.get(service.Id) : null;

            // Standard package
            pricings.add(new Service_Pricing__c(
                Name = service.Name + ' - Standard Package',
                Pricing_Name__c = 'Standard Package',
                Service__c = service.Id,
                Display_Configuration__c = configId,
                Amount__c = baseAmount,
                Discount__c = 0,
                Discount_Percentage__c = 0
            ));

            // Priority package with small discount
            Decimal priorityAmount = roundCurrency((baseAmount * 135) / 100); // +35%
            Decimal priorityDiscount = roundCurrency((priorityAmount * 5) / 100); // 5% discount
            pricings.add(new Service_Pricing__c(
                Name = service.Name + ' - Priority Package',
                Pricing_Name__c = 'Priority Package',
                Service__c = service.Id,
                Display_Configuration__c = configId,
                Amount__c = priorityAmount,
                Discount__c = priorityDiscount,
                Discount_Percentage__c = 5
            ));

            // Executive package with larger discount
            Decimal executiveAmount = roundCurrency((baseAmount * 175) / 100); // +75%
            Decimal executiveDiscount = roundCurrency((executiveAmount * 12) / 100); // 12% discount
            pricings.add(new Service_Pricing__c(
                Name = service.Name + ' - Executive Package',
                Pricing_Name__c = 'Executive Package',
                Service__c = service.Id,
                Display_Configuration__c = configId,
                Amount__c = executiveAmount,
                Discount__c = executiveDiscount,
                Discount_Percentage__c = 12
            ));
        }

        return pricings;
    }

    private static Decimal getBaseAmount(String serviceName) {
        if (serviceName == null) {
            return 1000;
        }

        serviceName = serviceName.toLowerCase();
        if (serviceName.contains('it support')) {
            return 500;
        } else if (serviceName.contains('onboarding')) {
            return 1500;
        } else if (serviceName.contains('partner')) {
            return 2500;
        }
        return 1000;
    }

    private static Decimal roundCurrency(Decimal amount) {
        if (amount == null) {
            return null;
        }
        return amount.setScale(0, RoundingMode.HALF_UP);
    }
    
    private static List<Approval_Step__c> createApprovalSteps(List<Service__c> services, List<Status__c> statuses) {
        List<Approval_Step__c> steps = new List<Approval_Step__c>();
        
        // Group statuses by service
        Map<Id, List<Status__c>> statusesByService = new Map<Id, List<Status__c>>();
        for (Status__c status : statuses) {
            if (!statusesByService.containsKey(status.Service__c)) {
                statusesByService.put(status.Service__c, new List<Status__c>());
            }
            statusesByService.get(status.Service__c).add(status);
        }
        
        for (Service__c service : services) {
            List<Status__c> serviceStatuses = statusesByService.get(service.Id);
            if (serviceStatuses == null || serviceStatuses.isEmpty()) continue;
            
            // Find specific statuses
            Status__c newStatus = null;
            Status__c inProgressStatus = null;
            Status__c approvedStatus = null;
            Status__c completedStatus = null;
            
            // Match statuses by Name since Request_Status__c uses Global Value Set
            for (Status__c s : serviceStatuses) {
                if (s.Name == 'New') newStatus = s;
                if (s.Name == 'In Progress') inProgressStatus = s;
                if (s.Name == 'Approved') approvedStatus = s;
                if (s.Name == 'Completed') completedStatus = s;
            }
            
            if (newStatus != null) {
                steps.add(new Approval_Step__c(
                    Name = 'Initial Review',
                    Service__c = service.Id,
                    Sequence__c = 1,
                    Step_Description__c = 'Initial review of the request',
                    Status__c = newStatus.Id,
                    Visible_on_Portal__c = true
                ));
            }
            
            if (inProgressStatus != null) {
                steps.add(new Approval_Step__c(
                    Name = 'Manager Approval',
                    Service__c = service.Id,
                    Sequence__c = 2,
                    Step_Description__c = 'Manager approval required',
                    Status__c = inProgressStatus.Id,
                    Visible_on_Portal__c = true
                ));
            }
            
            if (approvedStatus != null) {
                steps.add(new Approval_Step__c(
                    Name = 'Final Approval',
                    Service__c = service.Id,
                    Sequence__c = 3,
                    Step_Description__c = 'Final approval from department head',
                    Status__c = approvedStatus.Id,
                    Visible_on_Portal__c = true
                ));
            }
            
            if (completedStatus != null) {
                steps.add(new Approval_Step__c(
                    Name = 'Completion',
                    Service__c = service.Id,
                    Sequence__c = 4,
                    Step_Description__c = 'Request completed',
                    Status__c = completedStatus.Id,
                    Visible_on_Portal__c = true
                ));
            }
        }
        
        return steps;
    }
    
    /**
     * Add Draft status to existing services
     * Use this if Draft status is missing from your services
     */
    public static void addDraftStatus() {
        System.debug('=== Adding Draft Status ===');
        
        // Get all services
        List<Service__c> services = [SELECT Id FROM Service__c];
        System.debug('Found ' + services.size() + ' services');
        
        // Get existing statuses
        List<Status__c> existingStatuses = [
            SELECT Id, Name, Service__c 
            FROM Status__c 
            WHERE Service__c IN :services
        ];
        
        // Create a map of service IDs to existing status names
        Map<Id, Set<String>> statusesByService = new Map<Id, Set<String>>();
        for (Status__c status : existingStatuses) {
            if (!statusesByService.containsKey(status.Service__c)) {
                statusesByService.put(status.Service__c, new Set<String>());
            }
            statusesByService.get(status.Service__c).add(status.Name);
        }
        
        // Create Draft status for services that don't have it
        List<Status__c> draftStatuses = new List<Status__c>();
        for (Service__c service : services) {
            Set<String> existingNames = statusesByService.get(service.Id);
            if (existingNames == null || !existingNames.contains('Draft')) {
                draftStatuses.add(new Status__c(
                    Name = 'Draft',
                    Service__c = service.Id,
                    Active__c = true
                ));
            }
        }
        
        if (!draftStatuses.isEmpty()) {
            insert draftStatuses;
            System.debug('Created ' + draftStatuses.size() + ' Draft statuses');
        } else {
            System.debug('All services already have Draft status');
        }
    }

    /**
     * Create sample pricing tiers for all existing services.
     * Safe to run multiple times; consider deleting old pricing records first if needed.
     */
    public static void createPricingForExistingServices() {
        System.debug('=== Creating Pricing for Existing Services ===');

        List<Service__c> services = [SELECT Id, Name FROM Service__c];
        if (services.isEmpty()) {
            System.debug('No services found. Aborting pricing creation.');
            return;
        }

        List<Display_Configuration__c> configs = [
            SELECT Id, Service__c
            FROM Display_Configuration__c
            WHERE Service__c IN :services
        ];

        List<Service_Pricing__c> pricings = createServicePricings(services, configs);
        if (!pricings.isEmpty()) {
            insert pricings;
            System.debug('Inserted ' + pricings.size() + ' Service Pricing records');
        } else {
            System.debug('No pricing records generated.');
        }
    }
    
    /**
     * Update existing Service Section Fields with Picklist Values
     * Use this if you have existing fields without Picklist_Values__c populated
     */
    public static void updatePicklistValues() {
        System.debug('=== Updating Picklist Values ===');
        
        List<Service_Section_Field__c> fieldsToUpdate = new List<Service_Section_Field__c>();
        
        // Find all picklist fields (can't filter Long Text Area in WHERE clause)
        List<Service_Section_Field__c> picklistFields = [
            SELECT Id, Name, API_Name__c, Type__c, Picklist_Values__c
            FROM Service_Section_Field__c
            WHERE Type__c = 'Picklist'
        ];
        
        System.debug('Found ' + picklistFields.size() + ' picklist fields');
        
        for (Service_Section_Field__c field : picklistFields) {
            // Check if field needs values (null or empty)
            if (String.isBlank(field.Picklist_Values__c)) {
                // Set default values based on field name/API name
                if (field.API_Name__c == 'RequestType__c' || field.Name.contains('Request Type')) {
                    field.Picklist_Values__c = 'Hardware,Software,Network,Other';
                    fieldsToUpdate.add(field);
                } else if (field.API_Name__c == 'Priority__c' || field.Name.contains('Priority')) {
                    field.Picklist_Values__c = 'Low,Medium,High,Urgent';
                    fieldsToUpdate.add(field);
                }
            }
        }
        
        if (!fieldsToUpdate.isEmpty()) {
            update fieldsToUpdate;
            System.debug('Updated ' + fieldsToUpdate.size() + ' fields with picklist values');
        } else {
            System.debug('No fields needed updating');
        }
    }
}

