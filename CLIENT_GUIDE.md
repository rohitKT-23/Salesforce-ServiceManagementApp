# Service Management App - Client Guide

## What We Built

A **Dynamic Service Request System** for Salesforce that allows users to create and manage service requests through customizable forms.

---

## Key Features

### 1. **Dynamic Form Builder**
- Create service request forms without coding
- Configure sections, fields, and documents for each service
- Forms automatically adapt based on your configuration

### 2. **Service Selection**
- Users can search and select from available services
- No need to manually enter Service IDs
- Simple dropdown with search functionality

### 3. **Smart Form Fields**
- Different field types: Text, Number, Date, Picklist, etc.
- Fields can show/hide based on conditions
- Example: Show "Budget" field only if "Request Type" = "Purchase"

### 4. **Document Upload & Tracking**
- Upload required documents for each service
- Set which documents are mandatory
- Control allowed file types (PDF, JPG, etc.)
- Every upload creates a `Request_Document__c` record with sequence/type metadata
- Files are automatically linked to both the Service Request and Request Document (Notes & Attachments)

### 5. **Approval Workflow**
- Visual timeline showing approval steps
- Track progress: Pending → In Progress → Completed
- See current status at a glance

### 6. **Status Management**
- Define custom statuses for each service
- Track request progress through different stages
- Example: New → In Progress → Approved → Completed

### 7. **Service Pricing Catalog**
- Configure tiered pricing (e.g., Standard / Priority / Executive) per service
- Show Amount, Discount, and Total inside the form
- Selected pricing auto-populates on the Service Request record

### 8. **Request Timeline Insights**
- Approval timeline now mirrors live `Service_Request__c.Status__c`
- Clear icons, colors, and alignment for completed/current/pending steps
- Timeline view available directly within the Approval Timeline section

---

## How It Works

### For End Users:
1. **Select a Service** - Choose from available services
2. **Choose Pricing (if available)** - Pick the package that fits the request
3. **Fill the Form** - Complete fields based on selected service
4. **Upload Documents** - Attach required files (auto-saved to Request Documents & Files)
5. **Submit Request** - Form saves automatically
6. **Track Progress** - View approval timeline inside the same experience

### For Administrators:
1. **Create Services** - Define what services are available
2. **Configure Forms** - Set up sections, fields, and documents
3. **Set Conditions** - Define when fields should appear
4. **Define Statuses** - Create workflow stages
5. **Set Approval Steps** - Configure approval process
6. **Maintain Pricing** - Add/update `Service_Pricing__c` tiers per service (use TestDataGenerator helpers for sample data)

---

## Components Built

### 1. **Service Request Form**
- Main form where users create requests
- Dynamic service selector
- Auto-loads form configuration
- Built-in pricing selector with summary card
- Invokes document uploader to persist Request Document records + ContentDocumentLinks

### 2. **Section Renderer**
- Displays form sections
- Handles field visibility based on conditions
- Collapsible sections support

### 3. **Document Uploader**
- File upload interface
- Validates file types
- Shows mandatory vs optional documents
- Creates/updates `Request_Document__c` rows and links files to Notes & Attachments automatically

### 4. **Approval Timeline**
- Visual progress tracker
- Shows completed and pending steps
- Color-coded status indicators
- Falls back to service request status when request-specific steps are missing

### 5. **Test Data Generator**
- Seeds services, sections, statuses, documents, approval steps, and pricing tiers
- Utility method `createPricingForExistingServices()` populates packages for already-configured services

---

## Benefits

✅ **No Coding Required** - Configure everything through Salesforce UI  
✅ **Flexible** - Different forms for different services  
✅ **User-Friendly** - Simple interface for end users  
✅ **Scalable** - Add new services and forms easily  
✅ **Conditional Logic** - Smart forms that adapt to user input  
✅ **Document Management** - Built-in file upload and tracking  

---

## Current Status

✅ **Completed:**
- Dynamic form rendering
- Service selection with search
- Field visibility conditions
- Document upload + Request Document syncing + Notes & Attachments links
- Approval timeline display with live status sync
- Status management
- Service pricing catalog and UI picker
- Test data generation (including pricing tiers)

✅ **Ready to Use:**
- All components deployed to Salesforce
- Test data available for demonstration
- Can be configured on Lightning Pages

---

## Next Steps (Optional Enhancements)

- Email notifications
- Advanced reporting
- Mobile app optimization
- Integration with external systems
- Custom validation rules

---

## Support

For technical details or customization requests, please contact your development team.

---

**Version:** 1.0  
**Last Updated:** November 2025

