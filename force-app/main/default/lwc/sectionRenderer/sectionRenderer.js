import { LightningElement, api, track } from 'lwc';

export default class SectionRenderer extends LightningElement {
    @api section;
    @api fieldValues = {};
    @api conditionGroups = [];
    @track isExpanded = true;
    
    get sectionLabel() {
        return this.section?.Name || '';
    }
    
    get sectionDescription() {
        return this.section?.Description__c || '';
    }
    
    get isCollapsible() {
        return this.section?.Collapsible__c === true;
    }
    
    get fields() {
        if (!this.section?.Service_Section_Fields__r) {
            return [];
        }
        
        // Sort fields by sequence
        return [...this.section.Service_Section_Fields__r].sort((a, b) => {
            return (a.Sequence__c || 0) - (b.Sequence__c || 0);
        });
    }
    
    get visibleFields() {
        return this.fields.filter(field => this.isFieldVisible(field)).map(field => {
            return {
                ...field,
                fieldValue: this.fieldValues[field.API_Name__c]
            };
        });
    }
    
    get hasFields() {
        return this.visibleFields.length > 0;
    }
    
    get expandIcon() {
        return this.isExpanded ? 'utility:chevronup' : 'utility:chevrondown';
    }
    
    connectedCallback() {
        // Expand by default if not collapsible
        if (!this.isCollapsible) {
            this.isExpanded = true;
        }
    }
    
    toggleSection() {
        if (this.isCollapsible) {
            this.isExpanded = !this.isExpanded;
        }
    }
    
    isFieldVisible(field) {
        if (!field.Condition_Group__c) {
            return true; // No condition means always visible
        }
        
        // Find condition group
        const conditionGroup = this.conditionGroups.find(
            cg => cg.Id === field.Condition_Group__c
        );
        
        if (!conditionGroup || !conditionGroup.Conditions__r) {
            return true;
        }
        
        // Evaluate conditions
        return this.evaluateConditions(conditionGroup, field);
    }
    
    evaluateConditions(conditionGroup, field) {
        const conditions = conditionGroup.Conditions__r || [];
        if (conditions.length === 0) {
            return true;
        }
        
        const results = conditions.map(condition => {
            return this.evaluateCondition(condition);
        });
        
        // Default to AND logic
        const logic = (conditionGroup.Conditional_Logic__c || 'AND').toUpperCase();
        
        if (logic.includes('AND')) {
            return results.every(r => r === true);
        } else if (logic.includes('OR')) {
            return results.some(r => r === true);
        }
        
        return true;
    }
    
    evaluateCondition(condition) {
        const fieldApiName = condition.Field_API_Name__c;
        const operator = condition.Operator__c;
        const expectedValue = condition.Value__c || '';
        
        const fieldValue = this.fieldValues[fieldApiName];
        const fieldValueStr = fieldValue != null ? String(fieldValue) : '';
        
        switch (operator) {
            case '=':
                return fieldValueStr === expectedValue;
            case '!=':
                return fieldValueStr !== expectedValue;
            case '>':
                return this.compareValues(fieldValueStr, expectedValue) > 0;
            case '<':
                return this.compareValues(fieldValueStr, expectedValue) < 0;
            case '>=':
                return this.compareValues(fieldValueStr, expectedValue) >= 0;
            case '<=':
                return this.compareValues(fieldValueStr, expectedValue) <= 0;
            case 'Contains':
                return fieldValueStr.includes(expectedValue);
            case 'DoesNotContain':
                return !fieldValueStr.includes(expectedValue);
            case 'StartsWith':
                return fieldValueStr.startsWith(expectedValue);
            case 'EndsWith':
                return fieldValueStr.endsWith(expectedValue);
            case 'IN':
                const inValues = expectedValue.split(',').map(v => v.trim());
                return inValues.includes(fieldValueStr);
            case 'NOT IN':
                const notInValues = expectedValue.split(',').map(v => v.trim());
                return !notInValues.includes(fieldValueStr);
            default:
                return true;
        }
    }
    
    compareValues(val1, val2) {
        try {
            const num1 = parseFloat(val1);
            const num2 = parseFloat(val2);
            if (!isNaN(num1) && !isNaN(num2)) {
                return num1 - num2;
            }
        } catch (e) {
            // Not numeric, compare as strings
        }
        return val1.localeCompare(val2);
    }
    
    handleFieldChange(event) {
        const { apiName, value } = event.detail;
        this.fieldValues[apiName] = value;
        
        // Dispatch event to parent
        this.dispatchEvent(
            new CustomEvent('fieldchange', {
                detail: {
                    apiName,
                    value,
                    sectionId: this.section.Id
                },
                bubbles: true,
                composed: true
            })
        );
    }
}

