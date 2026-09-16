# Identity Framework

How identity is structured at Northbridge Provisions, and why.

---

## Authoritative source chain

    HR feed (CSV) → PowerShell provisioning → Active Directory
    → Entra Connect → Entra ID → SaaS applications

One source of truth. Identity data flows in one direction. No account is
created by hand at any point in that chain.

The consequence of that rule: if an account exists in AD that didn't come from
the HR feed, it is by definition an exception and should be findable as one.
That is what makes the access review meaningful rather than decorative.

---

## OU structure

Organized by **function, not geography**, because Northbridge's access model
follows job role rather than location. Warehouse staff at the distribution
centre and warehouse staff anywhere else need the same systems.

    Northbridge
    ├── Corporate        Finance, HR, IT, Sales, Marketing
    ├── Operations       Warehouse, Drivers, Dispatch
    ├── External         Contractors, Seasonal
    ├── ServiceAccounts
    ├── AdminAccounts    Tier0, Tier1, Tier2
    ├── Groups           Roles, Resources
    └── Computers        Workstations, Servers

**Why a single top-level OU rather than hanging everything off the domain
root:** Group Policy linked at `Northbridge` applies to the whole
organization without touching the Domain Controllers OU, which policy linked
at the domain root would also hit. It also gives one clean delegation point
if administration is ever handed to a junior admin.

**Why users and computers are separated:** user policy and computer policy are
different settings. Mixing them in one OU means every GPO needs filtering.

**Trade-off accepted:** a function-based structure handles a second site badly
— if Northbridge opened another distribution centre with different policy
requirements, the structure would need restructuring. Geography-first would
have handled that and made departmental grouping harder. The access model
follows function, so the structure follows function.

**Seasonal workers sit under External rather than Operations.** They are
employees, not contractors, so there is a real argument for Operations. They
are placed under External because their *lifecycle* resembles a contractor's:
short tenure, bulk onboarding and offboarding, time-bound access. The OU
structure follows lifecycle here because lifecycle is what drives the
automation.

---

## Group model — AGDLP

**Accounts** go into **Global** groups, Global groups nest into **Domain
Local** groups, and **Permissions** are applied to the Domain Local groups.

Two kinds of group, doing two different jobs:

| Type | Scope | Answers | Naming |
|---|---|---|---|
| Role group | Global | *Who is this person?* | `ROLE_Warehouse_Supervisor` |
| Resource group | Domain Local | *What does this grant?* | `RES_ERP_Write` |

**The rule the model rests on: a user never receives a permission directly.**
Users are members of role groups. Role groups are members of resource groups.
Permissions exist only on resource groups.

**Why this matters, concretely — the mover case.** When someone transfers from
Warehouse to Dispatch, they are removed from one role group and added to
another. Their entire entitlement set swaps in a single operation.

With direct permissions you would have to find every share, application and
system they touched and unpick each one. Nobody ever finds them all, and the
leftovers are privilege creep. The group model makes that failure structurally
impossible rather than a matter of diligence.

**On group scope:** Global groups can only contain accounts from their own
domain but can be granted permissions anywhere in the forest. Domain Local
groups can contain accounts from any trusted domain but only grant permissions
within their own. In a single-domain forest the distinction is largely
academic — it is built correctly anyway so the model still holds if Northbridge
acquires another company and adds a domain.

**Why read and write are separate resource groups:** a resource group grants
one level of access to one thing. A combined `RES_ERP_Access` could not give
warehouse supervisors read-only without inventing a second group anyway.
Splitting them up front keeps the groups composable.

**Why every group carries a description:** the access review generates a report
of who holds what. A report of bare group names is unreadable. This is the
difference between a directory that can be audited and one that cannot.

---

## Access model

| Resource | Granted to |
|---|---|
| `RES_ERP_Write` | Finance Staff, Finance Manager |
| `RES_ERP_Read` | Warehouse Supervisor, Dispatch Staff, Sales Staff |
| `RES_WMS_Write` | Warehouse Staff, Warehouse Supervisor, Seasonal Warehouse |
| `RES_WMS_Read` | Dispatch Staff, Finance Staff |
| `RES_DispatchApp_Access` | Dispatch Staff, Driver, Warehouse Supervisor |
| `RES_FinanceShare_Write` | Finance Staff, Finance Manager |
| `RES_FinanceShare_Read` | HR Staff |
| `RES_HRShare_Read` | HR Staff |
| `RES_SalesShare_Write` | Sales Staff, Marketing Staff |
| `RES_VPN_Access` | Finance, HR, IT, Sales, Marketing |

### Decisions behind the matrix

**Seasonal warehouse workers get WMS write, but no VPN and no ERP.** They do
the same floor work as permanent staff, so restricting the warehouse system
would stop them working. Short-tenure workers do not get remote access or
financial data. Least privilege applied to a real population rather than as a
slogan.

**Drivers get dispatch access only.** Forty people with the narrowest access in
the company, because that is genuinely all the role requires. The largest
headcount groups often need the least access.

**Contractors get nothing by default.** `ROLE_Contractor` exists but appears
nowhere in the access model. Contractor access is granted per engagement and
time-bound, not inherited from a job title. A contractor role that carried
standing entitlements would be a standing risk.

**VPN is corporate roles only.** Warehouse staff and drivers work on site.
Obvious written down; almost never enforced in practice.

---

## Compliance driver

Northbridge processes card payments from member grocers, so PCI-DSS applies.
The relevant requirements shape the model directly:

- **Unique ID per user** — no shared accounts, which is why service accounts
  get their own OU and documented ownership
- **Access control by business need to know** — the role and resource group
  split exists to make this demonstrable
- **Periodic access review** — the group model is what makes a review
  readable; reviewing direct permissions at this scale would not be feasible

---

## Open decisions

- Contractor identity: internal accounts or Entra B2B guests
- Whether seasonal workers get account expiry dates set at provisioning
- SCIM provisioning to downstream SaaS applications
- SAML or OIDC federation to a real application