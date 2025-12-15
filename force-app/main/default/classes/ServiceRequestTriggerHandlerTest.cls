@isTest
private class ServiceRequestTriggerHandlerTest {
    @isTest
    static void testCreatesRequestStepsOnInsert() {
        Service__c service = createService('Service A');
        Map<String, Id> statusMap = createStatuses(service.Id);
        createApprovalSteps(service.Id, statusMap);

        Service_Request__c request = new Service_Request__c(
            Name = 'Test Request',
            Service__c = service.Id,
            Status__c = statusMap.get('New')
        );
        insert request;

        List<Request_Approval_Step__c> requestSteps = [
            SELECT Service_Request__c, Approval_Step__c, Status__c, Sequence__c, Name
            FROM Request_Approval_Step__c
            WHERE Service_Request__c = :request.Id
            ORDER BY Sequence__c
        ];

        System.assertEquals(4, requestSteps.size(), 'All approval steps should be created');
        System.assertEquals(statusMap.get('New'), requestSteps[0].Status__c, 'Current step should store the request status');
        System.assertEquals(null, requestSteps[1].Status__c, 'Future steps remain pending');
        System.assertEquals(request.Name + ' - New', requestSteps[0].Name, 'Name should include request and status');
        System.assertEquals(request.Name + ' - In Progress', requestSteps[1].Name, 'Pending step should still show expected status');
    }

    @isTest
    static void testSyncsStatusesOnUpdate() {
        Service__c service = createService('Service B');
        Map<String, Id> statusMap = createStatuses(service.Id);
        createApprovalSteps(service.Id, statusMap);

        Service_Request__c request = new Service_Request__c(
            Name = 'Sync Request',
            Service__c = service.Id,
            Status__c = statusMap.get('New')
        );
        insert request;

        request.Status__c = statusMap.get('Approved');
        update request;

        List<Request_Approval_Step__c> afterUpdateSteps = [
            SELECT Status__c, Sequence__c, Name
            FROM Request_Approval_Step__c
            WHERE Service_Request__c = :request.Id
            ORDER BY Sequence__c
        ];

        System.assertEquals(statusMap.get('New'), afterUpdateSteps[0].Status__c, 'First step should remain completed');
        System.assertEquals(statusMap.get('In Progress'), afterUpdateSteps[1].Status__c, 'Second step should be marked complete');
        System.assertEquals(statusMap.get('Approved'), afterUpdateSteps[2].Status__c, 'Current approval step uses request status');
        System.assertEquals(null, afterUpdateSteps[3].Status__c, 'Future step stays pending');
        System.assertEquals(request.Name + ' - Approved', afterUpdateSteps[2].Name, 'Name should reflect current status');
        System.assertEquals(request.Name + ' - Completed', afterUpdateSteps[3].Name, 'Pending final step should show expected status');

        request.Status__c = statusMap.get('Completed');
        update request;

        Request_Approval_Step__c finalStep = [
            SELECT Status__c, Name
            FROM Request_Approval_Step__c
            WHERE Service_Request__c = :request.Id AND Sequence__c = 4
            LIMIT 1
        ];
        System.assertEquals(statusMap.get('Completed'), finalStep.Status__c, 'Last step should capture the completed status');
        System.assertEquals(request.Name + ' - Completed', finalStep.Name, 'Final step name should include completed status');
    }

    private static Service__c createService(String name) {
        Service__c service = new Service__c(
            Name = name,
            Active__c = true,
            SLA_Days__c = '5',
            Sequence__c = 1
        );
        insert service;
        return service;
    }

    private static Map<String, Id> createStatuses(Id serviceId) {
        List<Status__c> statuses = new List<Status__c>{
            new Status__c(Name = 'New', Service__c = serviceId, Active__c = true),
            new Status__c(Name = 'In Progress', Service__c = serviceId, Active__c = true),
            new Status__c(Name = 'Approved', Service__c = serviceId, Active__c = true),
            new Status__c(Name = 'Completed', Service__c = serviceId, Active__c = true)
        };
        insert statuses;

        Map<String, Id> statusMap = new Map<String, Id>();
        for (Status__c status : statuses) {
            statusMap.put(status.Name, status.Id);
        }
        return statusMap;
    }

    private static void createApprovalSteps(Id serviceId, Map<String, Id> statusMap) {
        List<Approval_Step__c> steps = new List<Approval_Step__c>{
            new Approval_Step__c(
                Name = 'Initial review',
                Service__c = serviceId,
                Sequence__c = 1,
                Step_Description__c = 'Initial review of the request',
                Status__c = statusMap.get('New'),
                Visible_on_Portal__c = true
            ),
            new Approval_Step__c(
                Name = 'Manager approval',
                Service__c = serviceId,
                Sequence__c = 2,
                Step_Description__c = 'Manager approval required',
                Status__c = statusMap.get('In Progress'),
                Visible_on_Portal__c = true
            ),
            new Approval_Step__c(
                Name = 'Department approval',
                Service__c = serviceId,
                Sequence__c = 3,
                Step_Description__c = 'Department head approval',
                Status__c = statusMap.get('Approved'),
                Visible_on_Portal__c = true
            ),
            new Approval_Step__c(
                Name = 'Completion',
                Service__c = serviceId,
                Sequence__c = 4,
                Step_Description__c = 'Request completed',
                Status__c = statusMap.get('Completed'),
                Visible_on_Portal__c = true
            )
        };
        insert steps;
    }
}