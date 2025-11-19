import { LightningElement, api } from 'lwc';

export default class DynamicField extends LightningElement {
    @api field;
    @api value;
    
    get fieldLabel() {
        return this.field?.Display_Label__c || this.field?.API_Name__c || '';
    }
    
    get fieldType() {
        return this.field?.Type__c || 'Text';
    }
    
    get fieldApiName() {
        return this.field?.API_Name__c || '';
    }
    
    get isRequired() {
        // You can add Required__c field check here if needed
        return false;
    }
    
    get isText() {
        return this.fieldType === 'Text';
    }
    
    get isNumber() {
        return this.fieldType === 'Number' || this.fieldType === 'Decimal';
    }
    
    get isCurrency() {
        return this.fieldType === 'Currency';
    }
    
    get isDate() {
        return this.fieldType === 'Date';
    }
    
    get isPicklist() {
        return this.fieldType === 'Picklist';
    }
    
    get isMultipicklist() {
        return this.fieldType === 'Multipicklist';
    }
    
    get picklistOptions() {
        // For now, return empty. You can enhance this to fetch from a related object
        // or parse from a field like Picklist_Values__c if you have one
        return [];
    }
    
    handleChange(event) {
        let value = event.target.value;
        
        // Convert to number if needed
        if (this.isNumber || this.isCurrency) {
            value = value ? parseFloat(value) : null;
        }
        
        this.dispatchEvent(
            new CustomEvent('fieldchange', {
                detail: {
                    apiName: this.fieldApiName,
                    value: value
                },
                bubbles: true,
                composed: true
            })
        );
    }
}

