import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DocumentUploader extends LightningElement {
    @api documents = [];
    @api serviceRequestId;
    
    @track uploadedFiles = [];
    @track fileDataMap = new Map();
    
    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }
    
    get sortedDocuments() {
        if (!this.documents) return [];
        return [...this.documents].sort((a, b) => {
            return (a.Sequence__c || 0) - (b.Sequence__c || 0);
        });
    }
    
    get allowedFileTypes() {
        return ['.pdf', '.jpg', '.jpeg'];
    }
    
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const documentId = event.target.dataset.documentId;
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }
        
        // Process each uploaded file
        uploadedFiles.forEach(file => {
            this.processUploadedFile(file, documentId);
        });
        
        this.showSuccess('File uploaded successfully');
    }
    
    processUploadedFile(file, documentId) {
        // Note: Request_Document__c currently only has Service__c lookup
        // You may need to add a Service_Request__c lookup field to properly link documents to requests
        // For now, we're just tracking the uploaded files
        
        this.uploadedFiles.push({
            id: file.documentId,
            name: file.name,
            documentId: documentId,
            contentDocumentId: file.documentId
        });
        
        // TODO: Create Request_Document__c record via Apex if Service_Request__c field is added
        // The Apex method would create the record linking the file to the service request
    }
    
    getServiceIdFromDocument(documentId) {
        const doc = this.documents.find(d => d.Id === documentId);
        return doc?.Service__c || null;
    }
    
    getFileType(fileName) {
        const extension = fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
        return extension;
    }
    
    validateFileType(fileName) {
        const extension = fileName.substring(fileName.lastIndexOf('.')).toLowerCase();
        return this.allowedFileTypes.includes(extension);
    }
    
    getDocumentLabel(document) {
        return document.Display_Label__c || document.Name || 'Document';
    }
    
    getDocumentRequired(document) {
        return document.Mandatory__c === true;
    }
    
    getAllowedTypesForDocument(document) {
        // Parse allowed types from the document
        // Assuming Allowed_Types__c is a picklist or text field
        if (document.Allowed_Types__c) {
            // Handle picklist values - could be semicolon or comma separated
            const types = document.Allowed_Types__c.split(/[;,]/).map(t => t.trim());
            return types.filter(t => t.length > 0);
        }
        return this.allowedFileTypes;
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

