# Service Management App - Usage Guide

## ✅ Deployment Status
**All components successfully deployed!**

## 📋 Components Deployed

### Apex Classes
1. **ServiceRequestController** - Main controller for form data and CRUD operations
2. **ConditionEvaluator** - Evaluates conditional logic for field/section visibility
3. **ApprovalStepsController** - Manages approval step data

### Lightning Web Components
1. **serviceRequestForm** - Main form component (exposed)
2. **sectionRenderer** - Renders sections dynamically (internal)
3. **dynamicField** - Renders individual fields (internal)
4. **documentUploader** - Handles document uploads (internal)
5. **approvalStepsTimeline** - Visual timeline for approval steps (exposed)

---

## 🚀 How to Use

### Step 1: Add Required Fields to Service_Request__c

Before using the components, you need to add these fields to `Service_Request__c`:

1. **Service__c** (Lookup to Service__c)
   - Go to: Setup → Object Manager → Service Request → Fields & Relationships
   - Create a new Lookup field to Service__c
   - Field Label: "Service"
   - Field Name: "Service__c"

2. **Status__c** (Lookup to Status__c) - Optional but recommended
   - Create a new Lookup field to Status__c
   - Field Label: "Status"
   - Field Name: "Status__c"

### Step 2: Add Components to Record Pages

#### Option A: Add to Service__c Record Page (Create New Request)

1. Go to: Setup → Object Manager → Service → Lightning Record Pages
2. Edit or create a record page
3. Click the **Components** tab (left sidebar)
4. Search for **"serviceRequestForm"**
5. Drag it onto the page
6. **IMPORTANT - Set Component Properties:**
   - Click on the **serviceRequestForm** component you just added (it will be highlighted/selected)
   - Look at the **right sidebar** - you should see a panel titled **"Component Properties"** or **"Properties"**
   - Find the **"Service ID"** field in the properties panel
   - Click in the Service ID field and enter: `{!recordId}`
     - This merge field expression works on Record Pages only
     - It automatically gets the current Service record ID
   - This tells the component which Service to load configuration from
   - **Note:** If you see an error about incorrect formatting, make sure you're on a Record Page, not an App Page
7. Click **Save** and **Activate**

#### Option B: Add to Service_Request__c Record Page (View/Edit Request)

1. Go to: Setup → Object Manager → Service Request → Lightning Record Pages
2. Edit or create a record page
3. Add **serviceRequestForm** component:
   - For editing: Set **Record ID** to `{!recordId}` and **Service ID** property
   - The component will detect edit mode automatically
4. Add **approvalStepsTimeline** component:
   - Set **Record ID** to `{!recordId}`
   - This shows the approval timeline
5. Click **Save** and **Activate**

### Step 3: Add to Lightning App Page (Standalone Form)

1. Go to: Setup → Lightning App Builder
2. Create a new **App Page** (or edit existing one)
3. In the left sidebar, click **Components** tab
4. Search for **"serviceRequestForm"** in the search box
5. Drag **serviceRequestForm** onto the page canvas (left side)
6. **IMPORTANT - Set Component Properties:**
   - **Click on the serviceRequestForm component** you just added (it should be highlighted/selected)
   - Look at the **right sidebar** - you'll see a panel with component properties
   - Scroll down if needed to find **"Service ID"** field
   - **For App Pages:** You need to manually enter a Service ID
     - Option 1: Enter a specific Service ID (e.g., `a0X5g000000ABC123`)
     - Option 2: Leave it empty if you want to pass it via URL parameter
   - **Note:** For App Pages, you may need to get the Service ID from URL parameters or set it programmatically
7. Click **Save** (top right)
8. Click **Activate** and assign to your Lightning App

---

## 📝 Configuration Steps

### 1. Set Up Your Service Configuration

Before using the form, configure your service:

1. **Create a Service Record**
   - Go to Service tab → New
   - Fill in Service details

2. **Create Display Configuration**
   - Go to Display Configuration tab → New
   - Link it to your Service (Service__c field)
   - This connects sections to your service

3. **Create Service Sections**
   - Go to Service Section tab → New
   - Link to Display Configuration
   - Set Sequence__c (order)
   - Set Collapsible__c (true/false)
   - Add Description__c (optional)

4. **Create Service Section Fields**
   - Go to Service Section Field tab → New
   - Link to Service Section
   - Set:
     - **API_Name__c**: The API name of the field on Service_Request__c (e.g., "FirstName__c")
     - **Display_Label__c**: Label shown to users
     - **Type__c**: Field type (Text, Number, Date, Picklist, etc.)
     - **Sequence__c**: Display order
   - Add Condition_Group__c if field should be conditional

5. **Create Statuses**
   - Go to Status tab → New
   - Link to Service
   - Set Name and Request_Status__c

6. **Create Service Documents** (Optional)
   - Go to Service Document tab → New
   - Link to Service
   - Set Document_Name__c, Mandatory__c, Allowed_Types__c

### 2. Set Up Conditional Logic (Optional)

1. **Create Condition Group**
   - Go to Condition Group tab → New
   - Set Conditional_Logic__c: "AND" or "OR"

2. **Create Conditions**
   - Go to Condition tab → New
   - Link to Condition Group
   - Set:
     - **Field_API_Name__c**: Field to check (e.g., "Status__c")
     - **Operator__c**: =, !=, >, <, Contains, etc.
     - **Value__c**: Value to compare against
     - **Sequence__c**: Order in group

3. **Link Condition Group**
   - Attach Condition_Group__c to Service Section or Service Section Field
   - Fields/sections will show/hide based on conditions

---

## 🎯 Usage Examples

### Example 1: Simple Form with Two Sections

**Service Section 1: Personal Information**
- Field 1: FirstName__c (Text)
- Field 2: LastName__c (Text)
- Field 3: Email__c (Text)

**Service Section 2: Request Details**
- Field 1: RequestType__c (Picklist)
- Field 2: Description__c (Text)
- Field 3: Amount__c (Currency)

**Steps:**
1. Create Service Section records for each section
2. Create Service Section Field records for each field
3. Set Sequence__c to control order
4. The form will render automatically!

### Example 2: Conditional Field Display

**Scenario:** Show "Company Name" only if "RequestType" = "Business"

**Steps:**
1. Create Condition Group with Conditional_Logic__c = "AND"
2. Create Condition:
   - Field_API_Name__c = "RequestType__c"
   - Operator__c = "="
   - Value__c = "Business"
3. Link Condition_Group__c to the "Company Name" field
4. Field will only show when RequestType = "Business"

---

## 🔧 Troubleshooting

### Issue: Form not loading
- **Check:** Display Configuration exists and is linked to Service
- **Check:** At least one Service Section exists
- **Check:** Service Section Fields are properly configured

### Issue: Fields not saving
- **Check:** API_Name__c matches actual field API name on Service_Request__c
- **Check:** Field exists on Service_Request__c object
- **Check:** User has create/edit permissions

### Issue: Conditions not working
- **Check:** Condition Group is properly linked
- **Check:** Field_API_Name__c matches the field being evaluated
- **Check:** Value__c matches the actual value (case-sensitive)

### Issue: Documents not uploading
- **Check:** Service_Request__c has a lookup to Request_Document__c (if needed)
- **Check:** File types match Allowed_Types__c
- **Check:** User has file upload permissions

---

## 📚 Component Properties

### serviceRequestForm
- **recordId** (String): Service Request ID (for edit mode)
- **serviceId** (String): Service ID (for create mode)

### approvalStepsTimeline
- **recordId** (String): Service Request ID (required)

---

## 🎨 Customization Tips

1. **Field Types Supported:**
   - Text
   - Number
   - Decimal
   - Currency
   - Date
   - Picklist (needs options configuration)
   - Multipicklist (needs options configuration)

2. **Styling:**
   - Components use Lightning Design System
   - Customize via CSS in component folders if needed

3. **Validation:**
   - Add Required__c field to Service_Section_Field__c for required fields
   - Update dynamicField component to check Required__c

---

## ✅ Next Steps

1. ✅ Add Service__c lookup field to Service_Request__c
2. ✅ Create your first Service with Display Configuration
3. ✅ Add Service Sections and Fields
4. ✅ Add components to Record Pages
5. ✅ Test the form with sample data
6. ✅ Configure conditional logic as needed
7. ✅ Set up approval steps (if using approval workflow)

---

## 📞 Support

If you encounter issues:
1. Check Salesforce Debug Logs for Apex errors
2. Check Browser Console for JavaScript errors
3. Verify all required fields exist on objects
4. Ensure proper field-level security and object permissions

---

**Happy Building! 🚀**

