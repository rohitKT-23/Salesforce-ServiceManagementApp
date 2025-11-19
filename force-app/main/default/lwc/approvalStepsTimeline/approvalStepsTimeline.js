import { LightningElement, api, track } from 'lwc';
import getApprovalSteps from '@salesforce/apex/ApprovalStepsController.getApprovalSteps';
import searchServiceRequests from '@salesforce/apex/ServiceRequestController.searchServiceRequests';

export default class ApprovalStepsTimeline extends LightningElement {
    @api recordId; // Service Request ID (optional - can be passed from parent)
    
    @track steps = [];
    @track isLoading = false;
    @track error;
    @track selectedServiceRequestId;
    @track serviceRequestOptions = [];
    @track isSearchingRequests = false;
    @track searchTerm = '';
    @track searchTimeout;
    
    connectedCallback() {
        // If recordId is passed from parent, load steps directly
        if (this.recordId) {
            this.selectedServiceRequestId = this.recordId;
            this.loadApprovalSteps();
        }
    }
    
    loadApprovalSteps() {
        const requestId = this.selectedServiceRequestId || this.recordId;
        if (!requestId) {
            return;
        }
        
        this.isLoading = true;
        this.error = null;
        
        const self = this;
        getApprovalSteps({ serviceRequestId: requestId })
            .then(function(result) {
                self.steps = result || [];
            })
            .catch(function(error) {
                const errorMessage = error.body && error.body.message ? error.body.message : error.message;
                self.error = errorMessage || 'Error loading approval steps';
                console.error('Error loading approval steps:', error);
            })
            .finally(function() {
                self.isLoading = false;
            });
    }
    
    handleServiceRequestSearch(event) {
        const searchValue = event.detail.value;
        this.searchTerm = searchValue;
        
        // Clear previous timeout
        if (this.searchTimeout) {
            clearTimeout(this.searchTimeout);
        }
        
        // Reset selection when search changes
        this.selectedServiceRequestId = null;
        this.steps = [];
        
        if (!searchValue || searchValue.trim().length < 2) {
            this.serviceRequestOptions = [];
            return;
        }
        
        // Debounce search - wait 300ms after user stops typing
        const self = this;
        this.searchTimeout = setTimeout(function() {
            self.performSearch(searchValue.trim());
        }, 300);
    }
    
    performSearch(searchTerm) {
        this.isSearchingRequests = true;
        const self = this;
        
        searchServiceRequests({ searchTerm: searchTerm })
            .then(function(requests) {
                if (requests && requests.length > 0) {
                    self.serviceRequestOptions = requests.map(function(req) {
                        const dateStr = req.createdDate ? new Date(req.createdDate).toLocaleDateString() : '';
                        const label = req.name + (req.serviceName ? ' - ' + req.serviceName : '') + (dateStr ? ' (' + dateStr + ')' : '');
                        return {
                            label: label,
                            value: req.id
                        };
                    });
                } else {
                    self.serviceRequestOptions = [{
                        label: 'No results found',
                        value: ''
                    }];
                }
                self.isSearchingRequests = false;
            })
            .catch(function(error) {
                console.error('Error searching service requests:', error);
                const errorMessage = error.body && error.body.message ? error.body.message : error.message;
                self.showError('Error searching: ' + errorMessage);
                self.isSearchingRequests = false;
                self.serviceRequestOptions = [];
            });
    }
    
    handleServiceRequestChange(event) {
        this.selectedServiceRequestId = event.detail.value;
        if (this.selectedServiceRequestId) {
            this.loadApprovalSteps();
        } else {
            this.steps = [];
        }
    }
    
    get hasServiceRequestOptions() {
        return this.serviceRequestOptions && this.serviceRequestOptions.length > 0;
    }
    
    get showSearchSection() {
        // Show search section if recordId is not passed from parent
        return !this.recordId;
    }
    
    showError(message) {
        // Dispatch error event or show toast
        const errorEvent = new CustomEvent('error', {
            detail: { message: message },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(errorEvent);
    }
    
    get hasSteps() {
        return this.steps && this.steps.length > 0;
    }
    
    get sortedSteps() {
        if (!this.steps) return [];
        const stepsCopy = this.steps.slice(); // Create a copy
        return stepsCopy.sort(function(a, b) {
            return (a.sequence || 0) - (b.sequence || 0);
        });
    }
    
    get stepsWithClasses() {
        const self = this;
        return this.sortedSteps.map(function(step) {
            const isCurrent = self.isCurrentStep(step);
            const stepCopy = {};
            // Copy all properties
            for (const key in step) {
                if (step.hasOwnProperty(key)) {
                    stepCopy[key] = step[key];
                }
            }
            
            // Add computed properties
            stepCopy.statusClass = step.isCompleted 
                ? 'slds-timeline__item_expandable slds-is-complete'
                : isCurrent 
                    ? 'slds-timeline__item_expandable slds-is-current'
                    : 'slds-timeline__item_expandable slds-is-pending';
            stepCopy.icon = step.isCompleted ? 'utility:success' : 'utility:clock';
            stepCopy.iconVariant = step.isCompleted ? 'success' : (isCurrent ? 'warning' : 'default');
            stepCopy.statusLabel = step.isCompleted ? 'Completed' : (isCurrent ? 'In Progress' : 'Pending');
            
            return stepCopy;
        });
    }
    
    isCurrentStep(step) {
        // A step is current if it's the first incomplete step
        const sortedSteps = this.sortedSteps;
        const firstIncompleteIndex = sortedSteps.findIndex(function(s) {
            return !s.isCompleted;
        });
        return firstIncompleteIndex >= 0 && sortedSteps[firstIncompleteIndex].id === step.id;
    }
    
}

