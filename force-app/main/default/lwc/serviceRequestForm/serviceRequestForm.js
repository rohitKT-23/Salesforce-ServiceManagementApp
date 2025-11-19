import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getServiceFormData from '@salesforce/apex/ServiceRequestController.getServiceFormData';
import saveServiceRequest from '@salesforce/apex/ServiceRequestController.saveServiceRequest';
import updateServiceRequest from '@salesforce/apex/ServiceRequestController.updateServiceRequest';
import getServiceRequest from '@salesforce/apex/ServiceRequestController.getServiceRequest';
import getActiveServices from '@salesforce/apex/ServiceRequestController.getActiveServices';

export default class ServiceRequestForm extends NavigationMixin(LightningElement) {
    @api recordId; // Service Request ID (if editing)
    @api serviceId; // Service ID (if creating new) - optional, can be selected via combobox
    
    @track formData;
    @track fieldValues = {};
    @track statuses = [];
    @track documents = [];
    @track sections = [];
    @track conditionGroups = [];
    @track isLoading = false;
    @track isSaving = false;
    @track selectedStatus;
    @track services = [];
    @track selectedServiceId;
    @track showServiceSelector = true;
    
    get isEditMode() {
        return !!this.recordId;
    }
    
    get hasSections() {
        return this.sections && this.sections.length > 0;
    }
    
    get sortedSections() {
        if (!this.sections) return [];
        return [...this.sections].sort((a, b) => {
            return (a.Sequence__c || 0) - (b.Sequence__c || 0);
        });
    }
    
    get statusOptions() {
        return this.statuses.map(status => ({
            label: status.Name,
            value: status.Id
        }));
    }
    
    get hasStatuses() {
        return this.statuses && this.statuses.length > 0;
    }
    
    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }
    
    get saveButtonLabel() {
        return this.isEditMode ? 'Update' : 'Save';
    }
    
    get serviceOptions() {
        return this.services.map(service => ({
            label: service.name + (service.slaDays ? ` (SLA: ${service.slaDays} days)` : ''),
            value: service.id
        }));
    }
    
    get hasServiceSelected() {
        return !!this.selectedServiceId;
    }
    
    get showForm() {
        return this.hasServiceSelected && !this.isLoading;
    }
    
    connectedCallback() {
        // Load available services
        this.loadServices();
        
        // If serviceId is provided as property or URL param, use it
        if (!this.isEditMode) {
            if (this.serviceId) {
                this.selectedServiceId = this.serviceId;
                this.showServiceSelector = false;
                this.loadFormData();
            } else {
                // Try to get serviceId from URL parameters
                const urlParams = new URLSearchParams(window.location.search);
                const serviceIdFromUrl = urlParams.get('serviceId') || urlParams.get('c__serviceId');
                if (serviceIdFromUrl) {
                    this.selectedServiceId = serviceIdFromUrl;
                    this.serviceId = serviceIdFromUrl;
                    this.showServiceSelector = false;
                    this.loadFormData();
                }
            }
        } else {
            // For edit mode, load form data directly
            this.loadFormData();
        }
    }
    
    loadServices() {
        getActiveServices()
            .then(services => {
                this.services = services;
            })
            .catch(error => {
                console.error('Error loading services:', error);
                this.showError('Error loading services: ' + (error.body?.message || error.message));
            });
    }
    
    handleServiceChange(event) {
        this.selectedServiceId = event.detail.value;
        this.serviceId = event.detail.value;
        this.showServiceSelector = false;
        this.loadFormData();
    }
    
    handleServiceSelectorBack() {
        this.selectedServiceId = null;
        this.serviceId = null;
        this.showServiceSelector = true;
        this.sections = [];
        this.statuses = [];
        this.documents = [];
        this.fieldValues = {};
        this.selectedStatus = null;
    }
    
    loadFormData() {
        const serviceIdToLoad = this.isEditMode ? null : (this.selectedServiceId || this.serviceId);
        
        if (!serviceIdToLoad && !this.recordId) {
            // Don't show error if we're in create mode and service selector is showing
            if (!this.showServiceSelector) {
                this.showError('Please select a service to continue');
            }
            return;
        }
        
        this.isLoading = true;
        
        if (this.isEditMode) {
            // For edit mode, we need the serviceId passed as a property
            // Or you can add a Service__c lookup field to Service_Request__c
            if (this.serviceId) {
                getServiceFormData({ serviceId: this.serviceId })
                    .then(data => {
                        this.processFormData(data);
                        this.loadExistingRequestData();
                    })
                    .catch(error => {
                        this.showError('Error loading form data: ' + error.body?.message || error.message);
                    })
                    .finally(() => {
                        this.isLoading = false;
                    });
            } else {
                this.showError('Service ID is required for editing. Please add Service__c lookup field to Service_Request__c or pass serviceId property.');
                this.isLoading = false;
            }
        } else {
            getServiceFormData({ serviceId: serviceIdToLoad })
                .then(data => {
                    this.processFormData(data);
                })
                .catch(error => {
                    this.showError('Error loading form data: ' + error.body?.message || error.message);
                })
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }
    
    processFormData(data) {
        this.formData = data;
        this.sections = data.sections || [];
        this.statuses = data.statuses || [];
        this.documents = data.documents || [];
        this.conditionGroups = data.conditionGroups || [];
        
        // Set default status if available
        if (this.statuses.length > 0 && !this.selectedStatus) {
            this.selectedStatus = this.statuses[0].Id;
        }
    }
    
    loadExistingRequestData() {
        // Load existing field values from the request
        // This would need to be enhanced based on your actual field structure
        // For now, we'll just set the status
        getServiceRequest({ requestId: this.recordId })
            .then(request => {
                if (request.Status__c) {
                    this.selectedStatus = request.Status__c;
                }
            })
            .catch(error => {
                console.error('Error loading request data:', error);
            });
    }
    
    handleFieldChange(event) {
        const { apiName, value } = event.detail;
        this.fieldValues[apiName] = value;
        
        // Re-evaluate visibility of fields/sections based on conditions
        // This will trigger reactive updates in child components
    }
    
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
    }
    
    handleSave() {
        if (!this.validateForm()) {
            return;
        }
        
        this.isSaving = true;
        
        const requestData = {
            ...this.fieldValues,
            Status__c: this.selectedStatus
        };
        
        if (this.isEditMode) {
            updateServiceRequest({
                requestId: this.recordId,
                fieldValues: requestData
            })
            .then(() => {
                this.showSuccess('Service Request updated successfully');
                this.navigateToRecord();
            })
            .catch(error => {
                this.showError('Error updating request: ' + error.body?.message || error.message);
            })
            .finally(() => {
                this.isSaving = false;
            });
        } else {
            saveServiceRequest({
                serviceId: this.selectedServiceId || this.serviceId,
                fieldValues: requestData
            })
            .then(requestId => {
                this.showSuccess('Service Request created successfully');
                this.navigateToRecord(requestId);
            })
            .catch(error => {
                this.showError('Error saving request: ' + error.body?.message || error.message);
            })
            .finally(() => {
                this.isSaving = false;
            });
        }
    }
    
    handleCancel() {
        if (this.isEditMode) {
            this.navigateToRecord();
        } else {
            // Navigate back or close
            this.dispatchEvent(new CustomEvent('cancel'));
        }
    }
    
    validateForm() {
        // Add validation logic here
        // Check required fields, etc.
        return true;
    }
    
    navigateToRecord(requestId) {
        const recordIdToNavigate = requestId || this.recordId;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordIdToNavigate,
                actionName: 'view'
            }
        });
    }
    
    showSuccess(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: message,
                variant: 'success'
            })
        );
    }
    
    showError(message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: message,
                variant: 'error'
            })
        );
    }
}

