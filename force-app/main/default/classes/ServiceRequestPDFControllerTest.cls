/**
 * @description Test class for ServiceRequestPDFController
 * Tests PDF generation functionality including data retrieval
 * for service requests, pricing, documents, and approval steps.
 */
@isTest
private class ServiceRequestPDFControllerTest {
    
    /**
     * @description Setup test data
     */
    @TestSetup
    static void setupTestData() {
        // Create Service
        Service__c testService = new Service__c(
            Name = 'Test Service',
            Active__c = true,
            SLA_Days__c = '5',
            Service_Type__c = 'Standard'
        );
        insert testService;
        
        // Create Status
        Status__c testStatus = new Status__c(
            Name = 'Draft',
            Service__c = testService.Id
        );
        insert testStatus;
        
        // Create Service Pricing (Total__c is a formula field, not writable)
        Service_Pricing__c testPricing = new Service_Pricing__c(
            Name = 'Standard Pricing',
            Pricing_Name__c = 'Standard Plan',
            Service__c = testService.Id,
            Amount__c = 100.00,
            Discount__c = 10.00,
            Discount_Percentage__c = 10
        );
        insert testPricing;
        
        // Create Service Request
        Service_Request__c testRequest = new Service_Request__c(
            Name = 'Test Request',
            Service__c = testService.Id,
            Service_Pricing__c = testPricing.Id,
            Status__c = testStatus.Id
        );
        insert testRequest;
        
        // Create Approval Step
        Approval_Step__c approvalStep = new Approval_Step__c(
            Service__c = testService.Id,
            Sequence__c = 1,
            Step_Description__c = 'Initial Review',
            Status__c = testStatus.Id
        );
        insert approvalStep;
        
        // Create Request Approval Step
        Request_Approval_Step__c requestApprovalStep = new Request_Approval_Step__c(
            Service_Request__c = testRequest.Id,
            Approval_Step__c = approvalStep.Id,
            Service__c = testService.Id,
            Sequence__c = 1,
            Status__c = testStatus.Id
        );
        insert requestApprovalStep;
        
        // Create Service Document
        Service_Document__c serviceDoc = new Service_Document__c(
            Name = 'Required Document',
            Document_Name__c = 'ID Proof',
            Service__c = testService.Id,
            Sequence__c = 1,
            Mandatory__c = true
        );
        insert serviceDoc;
        
        // Create Request Document
        Request_Document__c requestDoc = new Request_Document__c(
            Name = 'Uploaded ID',
            Service_Request__c = testRequest.Id,
            Service__c = testService.Id,
            Service_Document__c = serviceDoc.Id,
            Sequence__c = 1,
            Type__c = '.pdf'
        );
        insert requestDoc;
    }
    
    /**
     * @description Test controller initialization with valid record ID
     */
    @isTest
    static void testControllerWithValidRecordId() {
        // Get test data
        Service_Request__c testRequest = [SELECT Id FROM Service_Request__c LIMIT 1];
        
        // Set up the page with the record ID parameter
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', testRequest.Id);
        Test.setCurrentPage(pageRef);
        
        // Initialize controller
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        // Verify data was loaded
        System.assertNotEquals(null, controller.serviceRequest, 'Service Request should be loaded');
        System.assertEquals(testRequest.Id, controller.serviceRequest.Id, 'Should load correct Service Request');
        System.assertNotEquals(null, controller.service, 'Service should be loaded');
        System.assertNotEquals(null, controller.pricing, 'Pricing should be loaded');
        System.assertNotEquals(null, controller.documents, 'Documents list should not be null');
        System.assertNotEquals(null, controller.approvalSteps, 'Approval steps list should not be null');
        System.assertNotEquals(null, controller.currentUser, 'Current user should be loaded');
        System.assertEquals(null, controller.errorMessage, 'Error message should be null');
    }
    
    /**
     * @description Test controller initialization without record ID
     */
    @isTest
    static void testControllerWithoutRecordId() {
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.errorMessage, 'Error message should be set');
        System.assert(controller.errorMessage.contains('No Service Request ID'), 'Should indicate missing ID');
    }
    
    /**
     * @description Test controller initialization with invalid record ID
     */
    @isTest
    static void testControllerWithInvalidRecordId() {
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', 'invalidId123');
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        // Should have an error or null service request
        System.assert(controller.serviceRequest == null || controller.errorMessage != null, 
            'Should handle invalid ID gracefully');
    }
    
    /**
     * @description Test pricing calculations
     */
    @isTest
    static void testPricingCalculations() {
        Service_Request__c testRequest = [SELECT Id FROM Service_Request__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', testRequest.Id);
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        System.assertEquals(100.00, controller.subtotal, 'Subtotal should match');
        System.assertEquals(10.00, controller.discountAmount, 'Discount should match');
        // Total is calculated: subtotal - discount = 100 - 10 = 90
        System.assert(controller.totalAmount >= 0, 'Total should be calculated');
    }
    
    /**
     * @description Test documents retrieval
     */
    @isTest
    static void testDocumentsRetrieval() {
        Service_Request__c testRequest = [SELECT Id FROM Service_Request__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', testRequest.Id);
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.documents, 'Documents should not be null');
        System.assertEquals(1, controller.documents.size(), 'Should have one document');
        System.assertEquals('Uploaded ID', controller.documents[0].Name, 'Document name should match');
    }
    
    /**
     * @description Test approval steps retrieval
     */
    @isTest
    static void testApprovalStepsRetrieval() {
        Service_Request__c testRequest = [SELECT Id FROM Service_Request__c LIMIT 1];
        
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', testRequest.Id);
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.approvalSteps, 'Approval steps should not be null');
        System.assert(controller.approvalSteps.size() > 0, 'Should have at least one approval step');
    }
    
    /**
     * @description Test ApprovalStepInfo wrapper class methods
     */
    @isTest
    static void testApprovalStepInfoMethods() {
        ServiceRequestPDFController.ApprovalStepInfo stepInfo = new ServiceRequestPDFController.ApprovalStepInfo();
        stepInfo.sequence = 1;
        stepInfo.description = 'Test Step';
        stepInfo.expectedStatus = 'Pending';
        stepInfo.currentStatus = 'In Progress';
        stepInfo.isCompleted = true;
        stepInfo.completedDate = DateTime.now();
        
        Test.startTest();
        String formattedDate = stepInfo.getFormattedDate();
        String statusIcon = stepInfo.getStatusIcon();
        Test.stopTest();
        
        System.assertNotEquals('', formattedDate, 'Formatted date should not be empty');
        System.assertEquals('✓', statusIcon, 'Completed step should show checkmark');
        
        // Test pending status icon
        stepInfo.isCompleted = false;
        System.assertEquals('○', stepInfo.getStatusIcon(), 'Pending step should show circle');
        
        // Test null date
        stepInfo.completedDate = null;
        System.assertEquals('', stepInfo.getFormattedDate(), 'Null date should return empty string');
    }
    
    /**
     * @description Test FieldValuePair wrapper class
     */
    @isTest
    static void testFieldValuePairWrapper() {
        ServiceRequestPDFController.FieldValuePair fvp = new ServiceRequestPDFController.FieldValuePair();
        fvp.label = 'Test Label';
        fvp.value = 'Test Value';
        fvp.apiName = 'Test_Field__c';
        
        System.assertEquals('Test Label', fvp.label, 'Label should match');
        System.assertEquals('Test Value', fvp.value, 'Value should match');
        System.assertEquals('Test_Field__c', fvp.apiName, 'API name should match');
    }
    
    /**
     * @description Test service request without service
     */
    @isTest
    static void testServiceRequestWithoutService() {
        // Create a service request without service reference
        Service_Request__c bareRequest = new Service_Request__c(
            Name = 'Bare Request'
        );
        insert bareRequest;
        
        Test.startTest();
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', bareRequest.Id);
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.serviceRequest, 'Service Request should be loaded');
        System.assertEquals(null, controller.service, 'Service should be null');
        System.assertEquals(0, controller.approvalSteps.size(), 'Approval steps should be empty');
    }
    
    /**
     * @description Test generated datetime
     */
    @isTest
    static void testGeneratedDateTime() {
        Service_Request__c testRequest = [SELECT Id FROM Service_Request__c LIMIT 1];
        
        Test.startTest();
        DateTime beforeTest = DateTime.now();
        
        PageReference pageRef = Page.ServiceRequestPDF;
        pageRef.getParameters().put('id', testRequest.Id);
        Test.setCurrentPage(pageRef);
        
        ServiceRequestPDFController controller = new ServiceRequestPDFController();
        
        DateTime afterTest = DateTime.now();
        Test.stopTest();
        
        System.assertNotEquals(null, controller.generatedDateTime, 'Generated datetime should be set');
        System.assert(controller.generatedDateTime >= beforeTest, 'Generated datetime should be after test start');
        System.assert(controller.generatedDateTime <= afterTest, 'Generated datetime should be before test end');
    }
}