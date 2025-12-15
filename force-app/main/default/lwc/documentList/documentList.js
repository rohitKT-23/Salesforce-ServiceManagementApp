import { LightningElement, api } from 'lwc';

export default class DocumentList extends LightningElement {
    @api serviceDocumentId;
    @api requestDocuments = [];
    
    get documentsForThisServiceDocument() {
        if (!this.requestDocuments || !this.serviceDocumentId) {
            return [];
        }
        
        const self = this;
        return this.requestDocuments.filter(function(doc) {
            return doc.serviceDocumentId === self.serviceDocumentId;
        }).map(function(doc) {
            return {
                id: doc.id,
                name: doc.name,
                fileUrl: self.getFileUrl(doc.contentDocumentId),
                createdDate: doc.createdDate ? new Date(doc.createdDate).toLocaleString() : ''
            };
        });
    }
    
    get hasDocuments() {
        return this.documentsForThisServiceDocument.length > 0;
    }
    
    getFileUrl(contentDocumentId) {
        if (!contentDocumentId) {
            return '#';
        }
        return '/sfc/servlet.shepherd/document/download/' + contentDocumentId;
    }
}