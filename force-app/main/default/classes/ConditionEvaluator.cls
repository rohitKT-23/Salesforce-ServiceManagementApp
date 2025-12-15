public with sharing class ConditionEvaluator {
    
    public static Boolean evaluateConditionGroup(Id conditionGroupId, Map<String, Object> fieldValues, List<Condition__c> conditions) {
        if (conditionGroupId == null || conditions == null || conditions.isEmpty()) {
            return true; // No conditions means always visible
        }
        
        Condition_Group__c conditionGroup = [
            SELECT Id, Conditional_Logic__c
            FROM Condition_Group__c
            WHERE Id = :conditionGroupId
            LIMIT 1
        ];
        
        List<Boolean> conditionResults = new List<Boolean>();
        
        for (Condition__c condition : conditions) {
            Boolean result = evaluateCondition(condition, fieldValues);
            conditionResults.add(result);
        }
        
        // If no conditional logic specified, default to AND
        String logic = conditionGroup.Conditional_Logic__c != null 
            ? conditionGroup.Conditional_Logic__c.toUpperCase() 
            : 'AND';
        
        if (logic.contains('AND')) {
            // All conditions must be true
            for (Boolean result : conditionResults) {
                if (!result) return false;
            }
            return true;
        } else if (logic.contains('OR')) {
            // At least one condition must be true
            for (Boolean result : conditionResults) {
                if (result) return true;
            }
            return false;
        }
        
        return true; // Default to visible
    }
    
    private static Boolean evaluateCondition(Condition__c condition, Map<String, Object> fieldValues) {
        String fieldApiName = condition.Field_API_Name__c;
        String operator = condition.Operator__c;
        String expectedValue = condition.Value__c;
        
        Object fieldValue = fieldValues.get(fieldApiName);
        if (fieldValue == null) {
            fieldValue = '';
        }
        
        String fieldValueStr = String.valueOf(fieldValue);
        
        switch on operator {
            when '=' {
                return fieldValueStr.equals(expectedValue);
            }
            when '!=' {
                return !fieldValueStr.equals(expectedValue);
            }
            when '>' {
                return compareValues(fieldValueStr, expectedValue) > 0;
            }
            when '<' {
                return compareValues(fieldValueStr, expectedValue) < 0;
            }
            when '>=' {
                return compareValues(fieldValueStr, expectedValue) >= 0;
            }
            when '<=' {
                return compareValues(fieldValueStr, expectedValue) <= 0;
            }
            when 'Contains' {
                return fieldValueStr.contains(expectedValue);
            }
            when 'DoesNotContain' {
                return !fieldValueStr.contains(expectedValue);
            }
            when 'StartsWith' {
                return fieldValueStr.startsWith(expectedValue);
            }
            when 'EndsWith' {
                return fieldValueStr.endsWith(expectedValue);
            }
            when 'IN' {
                List<String> values = expectedValue.split(',');
                for (String val : values) {
                    if (fieldValueStr.equals(val.trim())) {
                        return true;
                    }
                }
                return false;
            }
            when 'NOT IN' {
                List<String> values = expectedValue.split(',');
                for (String val : values) {
                    if (fieldValueStr.equals(val.trim())) {
                        return false;
                    }
                }
                return true;
            }
            when else {
                return true;
            }
        }
    }
    
    private static Integer compareValues(String val1, String val2) {
        try {
            Decimal d1 = Decimal.valueOf(val1);
            Decimal d2 = Decimal.valueOf(val2);
            if (d1 > d2) return 1;
            if (d1 < d2) return -1;
            return 0;
        } catch (Exception e) {
            // If not numeric, compare as strings
            return val1.compareTo(val2);
        }
    }
}