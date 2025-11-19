import { LightningElement, api } from 'lwc';

export default class DynamicField extends LightningElement {
    @api field;
    @api value;
    
    get fieldLabel() {
        if (!this.field) {
            return '';
        }
        return this.field.Display_Label__c || this.field.API_Name__c || '';
    }
    
    get fieldType() {
        if (!this.field) {
            return 'Text';
        }
        return this.field.Type__c || 'Text';
    }
    
    get fieldApiName() {
        if (!this.field) {
            return '';
        }
        return this.field.API_Name__c || this.field.Name || '';
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
    
    get textPlaceholder() {
        const label = this.fieldLabel || 'value';
        return `Enter ${label}`;
    }
    
    get picklistPlaceholder() {
        const label = this.fieldLabel || 'option';
        return `Select ${label}`;
    }
    
    get picklistOptions() {
        if (!this.field || !this.field.Picklist_Values__c) {
            const apiName = this.field ? this.field.API_Name__c : 'unknown';
            console.warn('Picklist field missing values:', apiName, this.field);
            return [];
        }
        
        // Parse comma-separated values
        const values = this.field.Picklist_Values__c.split(',')
            .map(function(v) { return v.trim(); })
            .filter(function(v) { return v.length > 0; });
        
        // Convert to combobox options format
        const options = values.map(function(value) {
            return {
                label: value,
                value: value
            };
        });
        
        const apiName = this.field.API_Name__c || 'unknown';
        console.log('Picklist options for', apiName, ':', options);
        return options;
    }
    
    get multipicklistValue() {
        if (!this.value) {
            return [];
        }
        // If value is a string (semicolon-separated), convert to array
        if (typeof this.value === 'string') {
            return this.value.split(';').filter(function(v) {
                return v.trim().length > 0;
            });
        }
        // If already an array, return as is
        return Array.isArray(this.value) ? this.value : [];
    }
    
    handleChange(event) {
        // Prevent any errors from breaking the form
        if (!event) {
            return;
        }
        
        try {
            // Safely get value from event - compatible syntax
            let value = '';
            if (event.target && event.target.value !== undefined) {
                value = event.target.value;
            } else if (event.detail && event.detail.value !== undefined) {
                value = event.detail.value;
            }
            
            // Get field info directly without using getters to avoid proxy issues
            const field = this.field;
            if (!field) {
                console.warn('Field is missing in handleChange');
                return;
            }
            
            const apiName = field.API_Name__c || field.Name || '';
            if (!apiName || apiName === '') {
                console.warn('Field API Name is missing:', field);
                return;
            }
            
            // Get field type directly
            const fieldType = field.Type__c || 'Text';
            const isNumberType = fieldType === 'Number' || fieldType === 'Decimal';
            const isCurrencyType = fieldType === 'Currency';
            
            // Convert to number if needed
            if (isNumberType || isCurrencyType) {
                if (value === '' || value === null || value === undefined) {
                    value = null;
                } else {
                    const numValue = parseFloat(value);
                    value = isNaN(numValue) ? null : numValue;
                }
            }
            
            // Create event detail object safely
            const eventDetail = {
                apiName: apiName,
                value: value
            };
            
            // Dispatch event with proper error handling
            const customEvent = new CustomEvent('fieldchange', {
                detail: eventDetail,
                bubbles: true,
                composed: true
            });
            
            this.dispatchEvent(customEvent);
        } catch (error) {
            // Silently catch and log - don't break the form
            console.warn('Error in handleChange (non-critical):', error.message || error);
            // Don't rethrow - prevent error from breaking the form
        }
    }
    
    handleMultipicklistChange(event) {
        try {
            // Convert array to semicolon-separated string - compatible syntax
            let selectedValues = [];
            if (event && event.detail && event.detail.value) {
                selectedValues = event.detail.value;
            }
            
            const value = Array.isArray(selectedValues) && selectedValues.length > 0 
                ? selectedValues.join(';') 
                : null;
            
            const apiName = this.fieldApiName;
            if (!apiName || apiName === '') {
                console.error('Field API Name is missing for multipicklist:', this.field);
                return;
            }
            
            this.dispatchEvent(
                new CustomEvent('fieldchange', {
                    detail: {
                        apiName: apiName,
                        value: value
                    },
                    bubbles: true,
                    composed: true
                })
            );
        } catch (error) {
            console.error('Error in handleMultipicklistChange:', error);
            console.error('Event:', event);
            console.error('Field:', this.field);
            // Don't rethrow - prevent error from breaking the form
        }
    }
}

