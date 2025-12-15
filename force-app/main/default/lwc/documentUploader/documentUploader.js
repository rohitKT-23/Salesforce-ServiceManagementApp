import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import linkDocumentToRequest from '@salesforce/apex/ServiceRequestController.linkDocumentToRequest';
import getRequestDocuments from '@salesforce/apex/ServiceRequestController.getRequestDocuments';

export default class DocumentUploader extends LightningElement {
    @api documents = [];
    @api serviceRequestId;
    
    @track uploadedFiles = [];
    @track requestDocuments = [];
    @track fileDataMap = new Map();
    _currentServiceRequestId;
    
    connectedCallback() {
        console.log('DocumentUploader connectedCallback, serviceRequestId:', this.serviceRequestId);
        
        if (this.serviceRequestId) {
            this._currentServiceRequestId = this.serviceRequestId;
            this.loadRequestDocuments();
        }
    }
    
    renderedCallback() {
        // Watch for changes in serviceRequestId prop
        if (this.serviceRequestId && this.serviceRequestId !== this._currentServiceRequestId) {
            console.log('serviceRequestId prop changed from', this._currentServiceRequestId, 'to', this.serviceRequestId);
            this._currentServiceRequestId = this.serviceRequestId;
            this.loadRequestDocuments();
            
            // Link any pending documents when serviceRequestId becomes available
            if (this.uploadedFiles && this.uploadedFiles.length > 0) {
                console.log('Found pending files in renderedCallback, linking...');
                console.log('Pending files count:', this.uploadedFiles.length);
                this.linkPendingDocuments(this.serviceRequestId);
            }
        }
    }
    
    
    get hasDocuments() {
        return this.documents && this.documents.length > 0;
    }
    
    get sortedDocuments() {
        if (!this.documents) return [];
        const self = this;
        const docsCopy = this.documents.slice(); // Create a copy
        return docsCopy.sort(function(a, b) {
            return (a.Sequence__c || 0) - (b.Sequence__c || 0);
        }).map(function(doc) {
            const docCopy = {};
            // Copy all properties
            for (const key in doc) {
                if (doc.hasOwnProperty(key)) {
                    docCopy[key] = doc[key];
                }
            }
            docCopy.allowedTypesArray = self.getAllowedTypesForDocument(doc);
            return docCopy;
        });
    }
    
    getAllowedTypesForDocument(document) {
        if (!document || !document.Allowed_Types__c) {
            return [];
        }
        
        // Parse allowed types - remove leading dot if present and add it back
        const types = document.Allowed_Types__c.split(/[;,]/).map(function(t) {
            const trimmed = t.trim();
            // Ensure it starts with a dot
            return trimmed.startsWith('.') ? trimmed : '.' + trimmed;
        }).filter(function(t) {
            return t.length > 1; // More than just the dot
        });
        
        return types;
    }
    
    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        const documentId = event.target.dataset.documentId;
        
        if (!uploadedFiles || uploadedFiles.length === 0) {
            return;
        }
        
        // Get the document configuration
        const document = this.documents.find(function(d) {
            return d.Id === documentId;
        });
        
        if (!document) {
            this.showError('Document configuration not found');
            return;
        }
        
        // Validate file types
        const allowedTypes = this.getAllowedTypesForDocument(document);
        const invalidFiles = [];
        
        uploadedFiles.forEach(function(file) {
            const fileExtension = '.' + file.name.split('.').pop().toLowerCase();
            if (allowedTypes.length > 0 && !allowedTypes.includes(fileExtension)) {
                invalidFiles.push(file.name);
            }
        });
        
        if (invalidFiles.length > 0) {
            this.showError('Invalid file type. Allowed types: ' + allowedTypes.join(', '));
            return;
        }
        
        // Process each uploaded file
        const self = this;
        uploadedFiles.forEach(function(file) {
            self.processUploadedFile(file, documentId);
        });
        
        this.showSuccess('File uploaded successfully');
    }
    
    processUploadedFile(file, documentId) {
        const currentServiceRequestId = this.serviceRequestId || this._currentServiceRequestId;
        
        if (!currentServiceRequestId) {
            // Store for later linking when service request is created
            this.uploadedFiles.push({
                id: file.documentId,
                name: file.name,
                documentId: documentId,
                contentDocumentId: file.documentId
            });
            console.log('Document stored for later linking:', file.name);
            return;
        }
        
        // Link document to service request via Apex
        console.log('Linking document immediately:', file.name, 'to request:', currentServiceRequestId);
        this.linkSingleDocument(file.documentId, documentId, file.name);
    }
    
    linkSingleDocument(contentDocumentId, serviceDocumentId, fileName) {
        const self = this;
        const currentServiceRequestId = this.serviceRequestId || this._currentServiceRequestId;
        
        if (!currentServiceRequestId) {
            console.error('No service request ID available for linking document');
            return;
        }
        
        console.log('Calling linkDocumentToRequest with:', {
            serviceRequestId: currentServiceRequestId,
            contentDocumentId: contentDocumentId,
            serviceDocumentId: serviceDocumentId,
            fileName: fileName
        });
        
        linkDocumentToRequest({
            serviceRequestId: currentServiceRequestId,
            contentDocumentId: contentDocumentId,
            serviceDocumentId: serviceDocumentId,
            fileName: fileName
        })
        .then(function() {
            console.log('Document linked successfully, reloading...');
            // Reload documents after linking
            self.loadRequestDocuments();
        })
        .catch(function(error) {
            console.error('Error linking document:', error);
            const errorMessage = error.body && error.body.message ? error.body.message : error.message;
            self.showError('Error linking document: ' + errorMessage);
        });
    }
    
    @api
    linkPendingDocuments(serviceRequestId) {
        console.log('=== linkPendingDocuments START ===');
        console.log('linkPendingDocuments called with serviceRequestId:', serviceRequestId);
        console.log('this.uploadedFiles:', this.uploadedFiles);
        console.log('Pending files count:', this.uploadedFiles ? this.uploadedFiles.length : 0);
        
        if (!serviceRequestId) {
            console.error('No serviceRequestId provided');
            return;
        }
        
        // Update serviceRequestId
        this.serviceRequestId = serviceRequestId;
        this._currentServiceRequestId = serviceRequestId;
        console.log('Updated serviceRequestId to:', this.serviceRequestId);
        
        // Link all pending files
        if (this.uploadedFiles && this.uploadedFiles.length > 0) {
            const self = this;
            const filesToLink = [];
            
            // Create a proper copy using traditional loop
            for (let i = 0; i < this.uploadedFiles.length; i++) {
                filesToLink.push(this.uploadedFiles[i]);
            }
            
            console.log('Files to link:', filesToLink.length);
            console.log('Files:', JSON.stringify(filesToLink));
            
            // Clear pending files first to avoid duplicates
            this.uploadedFiles = [];
            
            // Link files one by one with delay to avoid race conditions
            for (let i = 0; i < filesToLink.length; i++) {
                const file = filesToLink[i];
                const index = i;
                console.log('Scheduling link for file:', file.name, 'at index:', index);
                
                setTimeout(function() {
                    console.log('Linking file now:', file.name);
                    self.linkSingleDocument(file.contentDocumentId, file.documentId, file.name);
                }, index * 300);
            }
            
            // Reload documents after all files are linked
            setTimeout(function() {
                console.log('Reloading documents after linking all files');
                self.loadRequestDocuments();
            }, (filesToLink.length * 300) + 500);
        } else {
            console.log('No pending files to link');
            // Still reload in case documents were linked elsewhere
            const self = this;
            setTimeout(function() {
                self.loadRequestDocuments();
            }, 500);
        }
        console.log('=== linkPendingDocuments END ===');
    }
    
    loadRequestDocuments() {
        const currentServiceRequestId = this.serviceRequestId || this._currentServiceRequestId;
        
        if (!currentServiceRequestId) {
            console.log('No service request ID, skipping document load');
            return;
        }
        
        console.log('Loading request documents for:', currentServiceRequestId);
        const self = this;
        getRequestDocuments({ serviceRequestId: currentServiceRequestId })
            .then(function(documents) {
                console.log('Loaded documents:', documents ? documents.length : 0);
                self.requestDocuments = documents || [];
            })
            .catch(function(error) {
                console.error('Error loading documents:', error);
            });
    }
    
    get hasUploadedDocs() {
        return this.requestDocuments && this.requestDocuments.length > 0;
    }
    
    get uploadedDocsList() {
        // Return all uploaded documents with file URLs
        if (!this.requestDocuments || this.requestDocuments.length === 0) {
            return [];
        }
        
        const self = this;
        return this.requestDocuments.map(function(doc) {
            return {
                id: doc.id,
                name: doc.name,
                contentDocumentId: doc.contentDocumentId,
                fileUrl: self.getFileUrl(doc.contentDocumentId),
                createdDate: doc.createdDate ? new Date(doc.createdDate).toLocaleString() : '',
                serviceDocumentId: doc.serviceDocumentId
            };
        });
    }
    
    getUploadedDocumentsForDocument(documentId) {
        if (!this.requestDocuments || !documentId) {
            return [];
        }
        
        const self = this;
        return this.requestDocuments.filter(function(doc) {
            return doc.serviceDocumentId === documentId;
        }).map(function(doc) {
            return {
                id: doc.id,
                name: doc.name,
                contentDocumentId: doc.contentDocumentId,
                fileUrl: self.getFileUrl(doc.contentDocumentId),
                createdDate: doc.createdDate ? new Date(doc.createdDate).toLocaleString() : ''
            };
        });
    }
    
    getFileUrl(contentDocumentId) {
        if (!contentDocumentId) {
            return '#';
        }
        return '/sfc/servlet.shepherd/document/download/' + contentDocumentId;
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