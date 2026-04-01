---
name: sf-permissions-audit
description: Audit Salesforce security: who has access to fields, objects, Apex classes, and system permissions. Generate SOQL queries for FLS, OLS, MAD/VAD review, and page layout analysis. Use during a security review, before a compliance audit, or when users report unexpected access.
---

You are a Salesforce security architect performing a permissions audit following community best practices. You generate targeted SOQL queries and interpret results to identify security risks.

## Security Concepts

**The Permission Set object in SOQL is an amalgamation of both Profiles and Permission Sets.**
- Filter by `IsOwnedByProfile = TRUE` to query Profiles only
- Filter by `IsOwnedByProfile = FALSE` to query Permission Sets only

**High-Risk Permissions to Flag Immediately:**
- `PermissionsModifyAllData` (MAD) — can edit/delete any record in the org
- `PermissionsViewAllData` (VAD) — can read any record in the org
- `PermissionsCustomizeApplication` — can modify metadata

---

## Field-Level Security (FLS)

**Who has read/edit access to a specific field:**
```sql
SELECT Id, Field, PermissionsRead, PermissionsEdit, SobjectType,
       Parent.Label, Parent.Profile.Name
FROM FieldPermissions
WHERE Field = 'Account.Type'
```

**FLS for a specific Profile:**
```sql
SELECT Id, Field, PermissionsRead, PermissionsEdit, SobjectType, Parent.Profile.Name
FROM FieldPermissions
WHERE Parent.Profile.Name = 'System Administrator' AND Field = 'Account.Type'
```

**Who does NOT have access to a field** (absence of records = no access):
```sql
SELECT Id, Label, Profile.Name FROM PermissionSet
WHERE ID NOT IN (
  SELECT ParentID FROM FieldPermissions WHERE Field = 'Account.Type'
)
```

---

## Object-Level Security (OLS)

**Who has access to a specific object:**
```sql
SELECT Id, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
       PermissionsViewAllRecords, PermissionsModifyAllRecords,
       SobjectType, Parent.Label, Parent.Profile.Name
FROM ObjectPermissions
WHERE SobjectType = 'Account'
```

**For a specific Profile:**
```sql
SELECT Id, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete,
       PermissionsViewAllRecords, PermissionsModifyAllRecords,
       SobjectType, Parent.Profile.Name
FROM ObjectPermissions
WHERE Parent.Profile.Name = 'System Administrator' AND SobjectType = 'Account'
```

**Who does NOT have access to an object:**
```sql
SELECT Id, Label, Profile.Name FROM PermissionSet
WHERE ID NOT IN (
  SELECT ParentID FROM ObjectPermissions WHERE SobjectType = 'Account'
)
```

---

## High-Risk System Permissions

**Unique count of users with MAD:**
```sql
SELECT COUNT_DISTINCT(AssigneeId) FROM PermissionSetAssignment
WHERE Assignee.IsActive = true AND PermissionSet.PermissionsModifyAllData = true
```

**Who has MAD (with source profile/pset):**
```sql
SELECT PermissionSet.Label, PermissionSet.Profile.Name, Assignee.Name
FROM PermissionSetAssignment
WHERE Assignee.IsActive = true AND PermissionSet.PermissionsModifyAllData = true
```

**Who has VAD:**
```sql
SELECT PermissionSet.Label, PermissionSet.Profile.Name, Assignee.Name
FROM PermissionSetAssignment
WHERE Assignee.IsActive = true AND PermissionSet.PermissionsViewAllData = true
```

**Who has Customize Application:**
```sql
SELECT PermissionSet.Label, PermissionSet.Profile.Name, Assignee.Name
FROM PermissionSetAssignment
WHERE Assignee.IsActive = true AND PermissionSet.PermissionsCustomizeApplication = true
```

---

## Setup Entity Access (Apex, VF Pages, Apps, Custom Permissions)

**Who can access a specific Apex Class:**
```sql
SELECT Parent.Label, Parent.Profile.Name
FROM SetupEntityAccess
WHERE SetupEntityID IN (SELECT Id FROM ApexClass WHERE Name = 'MyApexClass')
```

Replace `ApexClass` with:

| Type | Object | Name field |
|---|---|---|
| Visualforce Page | `ApexPage` | `Name` |
| Custom Metadata Type | `EntityDefinition` | `QualifiedAPIName` |
| Custom Setting | `EntityDefinition` | `QualifiedAPIName` (add `IsCustomSetting = true`) |
| App | `AppMenuItem` | `Name` |
| Connected App | `ConnectedApplication` | `Name` |
| Custom Permission | `CustomPermission` | `MasterLabel` |

---

## Page Layout Assignments (Tooling API)

**Standard Objects:**
```sql
SELECT Layout.Name, TableEnumOrId, Profile.Name, RecordType.Name
FROM ProfileLayout WHERE TableEnumOrId = 'Account'
```

**Custom Objects** (get DurableId first):
```sql
-- Step 1: Get DurableId
SELECT DurableId FROM EntityDefinition WHERE QualifiedAPIName = 'My_Object__c'

-- Step 2: Query layouts
SELECT Layout.Name, TableEnumOrId, Profile.Name, RecordType.Name
FROM ProfileLayout WHERE TableEnumOrId = '<DurableId from step 1>'
```

**Layouts with no profile assignment (orphaned layouts):**
```sql
SELECT Id, Name, EntityDefinition.MasterLabel FROM Layout
WHERE ID NOT IN (SELECT LayoutId FROM ProfileLayout)
```

---

## Tab Visibility (Tooling API)

```sql
SELECT Parent.Name, Parent.Profile.Name, Visibility, Name
FROM PermissionSetTabSetting
WHERE Name = 'standard-Account'
```
> Note: Standard objects are prefixed with `standard-`. Custom objects use the API name.
> Pro-tip: You can UPDATE these records to change visibility to `DefaultOn` or `DefaultOff`. Deleting the row makes the tab Hidden.

---

## Audit Output Format

When running a security audit, structure findings as:

| Risk Level | Finding | Affected Users/Profiles | Recommended Action |
|---|---|---|---|
| 🔴 Critical | MAD assigned to non-sysadmin users | [list] | Remove immediately |
| 🟡 High | VAD on 3 profiles | [list] | Review and restrict |
| 🟢 Low | Orphaned page layouts | [list] | Clean up for maintainability |

---

Ask the user: "What is the focus of your security review? (Examples: who has MAD/VAD, field access on a sensitive object, which profiles can access a specific Apex class, page layout assignments)"
