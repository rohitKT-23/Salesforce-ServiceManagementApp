import { LightningElement, api, track, wire } from 'lwc';
import getApprovalSteps from '@salesforce/apex/ApprovalStepsController.getApprovalSteps';

export default class ApprovalStepsTimeline extends LightningElement {
    @api recordId; // Service Request ID
    
    @track steps = [];
    @track isLoading = false;
    @track error;
    
    connectedCallback() {
        if (this.recordId) {
            this.loadApprovalSteps();
        }
    }
    
    loadApprovalSteps() {
        this.isLoading = true;
        this.error = null;
        
        getApprovalSteps({ serviceRequestId: this.recordId })
            .then(result => {
                this.steps = result || [];
            })
            .catch(error => {
                this.error = error.body?.message || error.message || 'Error loading approval steps';
                console.error('Error loading approval steps:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    get hasSteps() {
        return this.steps && this.steps.length > 0;
    }
    
    get sortedSteps() {
        if (!this.steps) return [];
        return [...this.steps].sort((a, b) => {
            return (a.sequence || 0) - (b.sequence || 0);
        });
    }
    
    get stepsWithClasses() {
        return this.sortedSteps.map(step => {
            const isCurrent = this.isCurrentStep(step);
            return {
                ...step,
                statusClass: step.isCompleted 
                    ? 'slds-timeline__item_expandable slds-is-complete'
                    : isCurrent 
                        ? 'slds-timeline__item_expandable slds-is-current'
                        : 'slds-timeline__item_expandable slds-is-pending',
                icon: step.isCompleted ? 'utility:success' : 'utility:clock',
                iconVariant: step.isCompleted ? 'success' : (isCurrent ? 'warning' : 'default'),
                statusLabel: step.isCompleted ? 'Completed' : (isCurrent ? 'In Progress' : 'Pending')
            };
        });
    }
    
    isCurrentStep(step) {
        // A step is current if it's the first incomplete step
        const sortedSteps = this.sortedSteps;
        const firstIncompleteIndex = sortedSteps.findIndex(s => !s.isCompleted);
        return firstIncompleteIndex >= 0 && sortedSteps[firstIncompleteIndex].id === step.id;
    }
    
}

