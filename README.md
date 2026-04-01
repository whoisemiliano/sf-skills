# Salesforce Best Practice Skills

Battle-tested Salesforce knowledge — naming conventions, Flow review, org audits, SOQL, permissions, packages, and more — packaged as AI skills for Claude Code, Cursor, and Codex.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/whoisemiliano/sf-skills/refs/heads/master/install.sh | bash
```

That's it. The installer will open an interactive prompt to select your tool(s) and scope.

Or clone and run manually if you prefer:

```bash
git clone https://github.com/whoisemiliano/sf-skills.git
cd sf-skills
./install.sh
```

Pass flags to skip the prompt entirely:

```bash
# Claude Code
./install.sh --target claude

# Cursor (project-level, into .cursor/rules/)
./install.sh --target cursor --scope project

# Cursor (global)
./install.sh --target cursor --scope global

# Codex (adds/updates AGENTS.md in current directory)
./install.sh --target codex --scope project

# All tools at once
./install.sh --target all
```

### What gets installed where

| Tool | Location | Format |
|---|---|---|
| **Claude Code** | `~/.claude/skills/sf-skills/` | Individual `.md` skill files, invoked with `/skill-name` |
| **Cursor** | `.cursor/rules/` (project) or `~/.cursor/rules/` (global) | `.mdc` rule files, available in Cursor's rule picker |
| **Codex** | `AGENTS.md` (project) or `~/.codex/AGENTS.md` (global) | Single combined markdown file loaded at agent startup |

---

## Skills

| Skill | Invoke with | What it does |
|---|---|---|
| **sf-naming-conventions** | `/sf-naming-conventions` | Audit or generate Salesforce field API names following community conventions (PascalCase, type suffixes, service prefixes, TECH_ prefix) |
| **sf-org-audit** | `/sf-org-audit` | Run a full org health audit: security, data model, automation quality, Apex, limits — with SOQL queries included |
| **sf-integration-scoping** | `/sf-integration-scoping` | Integration discovery session: sync direction, API compatibility, volumes, conflict resolution, partner/technology selection |
| **sf-flow-review** | `/sf-flow-review` | Review a Flow against community best practices: governor limit risks, naming, DML-in-loop, ISCHANGED patterns, email gotchas |
| **sf-quirks-advisor** | `/sf-quirks-advisor` | Get honest advice on known Salesforce platform quirks: multipicklists, PersonAccounts, Case Assignment Rules, PSG namespaces |
| **sf-permissions-audit** | `/sf-permissions-audit` | Security audit: FLS, OLS, MAD/VAD review, Apex class access, page layout assignments — all via targeted SOQL |
| **sf-data-architecture** | `/sf-data-architecture` | Architecture guidance: MDM design, LDV strategy, B2C modeling, Multipicklist vs Junction Object, Batch vs Bulk API |
| **sf-validation-rules** | `/sf-validation-rules` | Write, review, or audit Salesforce Validation Rules: naming, error codes, bypass patterns, formula conventions, anti-patterns |
| **sf-packages** | `/sf-packages` | Guide building Managed or Unlocked Packages: Dev Hub setup, namespace, versioning, promotion, and deployment |

---

## Usage Examples

```
# Review field names in a metadata file
/sf-naming-conventions
> I have these fields: IsActive__c, lookup_account__c, Revenue_Formula__c — are they compliant?

# Audit an org you just inherited
/sf-org-audit
> I need to audit a Sales Cloud org with ~50k records, 3 admins, and lots of legacy Process Builders

# Scope a new integration
/sf-integration-scoping
> We need to sync Accounts and Contacts bidirectionally between Salesforce and our ERP (SAP)

# Check if a Flow design is safe
/sf-flow-review
> I have a Record-Triggered Flow that updates related Contacts in a loop — is that a problem?

# Decide on data model
/sf-data-architecture
> Client wants to use PersonAccounts for their B2C e-commerce platform with 2M customers

# Find who has dangerous permissions
/sf-permissions-audit
> I need to find all users who have Modify All Data in our production org
```

---

## About

Skills authored by [@whoisemiliano](https://github.com/whoisemiliano).
