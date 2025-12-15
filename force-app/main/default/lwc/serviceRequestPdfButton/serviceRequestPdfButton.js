import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';

// Fields to check if the record exists
const FIELDS = ['Service_Request__c.Id', 'Service_Request__c.Name'];

/**
 * @description LWC component to generate and download PDF for Service Request
 * Supports multiple display variants: button, icon-only, and menu-item
 */
export default class ServiceRequestPdfButton extends NavigationMixin(LightningElement) {
    // Public properties
    @api recordId;
    @api buttonLabel = 'Download PDF';
    @api buttonTitle = 'Download Service Request as PDF';
    @api buttonVariant = 'brand'; // neutral, brand, brand-outline, destructive, success
    @api iconName = 'utility:pdf_ext';
    @api iconPosition = 'left'; // left, right
    @api displayVariant = 'button'; // button, icon, menuItem
    @api iconVariant = 'border-filled'; // bare, container, border, border-filled, border-inverse
    @api iconSize = 'medium'; // xx-small, x-small, small, medium, large
    @api openInNewTab = false;

    // Private reactive properties
    isLoading = false;
    error = null;
    recordData = null;

    /**
     * @description Wire adapter to get record data and validate record exists
     */
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.recordData = data;
            this.error = null;
        } else if (error) {
            this.error = error;
            this.recordData = null;
            console.error('Error loading record:', error);
        }
    }

    /**
     * @description Computed property for button display variant
     */
    get isButtonVariant() {
        return this.displayVariant === 'button';
    }

    /**
     * @description Computed property for icon-only display variant
     */
    get isIconVariant() {
        return this.displayVariant === 'icon';
    }

    /**
     * @description Computed property for menu item display variant
     */
    get isMenuItemVariant() {
        return this.displayVariant === 'menuItem';
    }

    /**
     * @description Computed property to check if button should be disabled
     */
    get isDisabled() {
        return this.isLoading || !this.recordId;
    }

    /**
     * @description Handle the PDF download action
     */
    handleDownloadPdf() {
        if (!this.recordId) {
            this.showToast('Error', 'No Service Request ID available.', 'error');
            return;
        }

        if (this.error) {
            this.showToast('Error', 'Unable to access Service Request record.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            // Build the PDF URL
            const pdfUrl = this.buildPdfUrl();
            
            console.log('Opening PDF URL:', pdfUrl);

            // Always open PDF in new tab (best UX for PDF documents)
            // Using window.open ensures it works in Lightning Experience
            this.openPdfInNewTab(pdfUrl);

            // Show success message
            this.showToast('Success', 'PDF is being generated in a new tab...', 'success');

        } catch (error) {
            console.error('Error generating PDF:', error);
            this.showToast('Error', 'Failed to generate PDF. Please try again.', 'error');
        } finally {
            // Reset loading state after a short delay
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => {
                this.isLoading = false;
            }, 1000);
        }
    }

    /**
     * @description Build the Visualforce PDF URL
     * @returns {string} The complete PDF URL
     */
    buildPdfUrl() {
        // For Lightning Experience, we need to use the correct Visualforce domain
        // The VF page URL format: /apex/PageName?id=recordId
        // In LEX, window.location.origin gives lightning domain, but VF pages 
        // are served from visual.force.com subdomain
        
        // Get the instance URL from the current location
        let baseUrl = window.location.origin;
        
        // Check if we're in Lightning Experience (lightning domain)
        if (baseUrl.includes('.lightning.force.com')) {
            // Convert lightning domain to visualforce domain
            // e.g., https://myorg.lightning.force.com -> https://myorg--c.vf.force.com
            // However, the simplest approach is to use relative URL which Salesforce handles
            return `/apex/ServiceRequestPDF?id=${this.recordId}`;
        }
        
        // For classic or other domains, use relative URL
        return `/apex/ServiceRequestPDF?id=${this.recordId}`;
    }

    /**
     * @description Open the PDF in a new browser tab
     * @param {string} url - The PDF URL to open
     */
    openPdfInNewTab(url) {
        // For relative URLs, we need the full URL
        let fullUrl = url;
        if (url.startsWith('/')) {
            fullUrl = window.location.origin + url;
        }
        
        console.log('Full PDF URL:', fullUrl);
        
        // Open in new tab
        window.open(fullUrl, '_blank', 'noopener,noreferrer');
    }

    /**
     * @description Navigate to the PDF page using Lightning Navigation
     */
    navigateToPdfPage() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.buildPdfUrl()
            }
        });
    }

    /**
     * @description Show a toast notification
     * @param {string} title - Toast title
     * @param {string} message - Toast message
     * @param {string} variant - Toast variant (success, error, warning, info)
     */
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    /**
     * @description Public method to trigger PDF download programmatically
     */
    @api
    downloadPdf() {
        this.handleDownloadPdf();
    }

    /**
     * @description Public method to get the PDF URL without downloading
     * @returns {string} The PDF URL
     */
    @api
    getPdfUrl() {
        if (!this.recordId) {
            return null;
        }
        return this.buildPdfUrl();
    }
}

