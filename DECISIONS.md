# Decisions

Running log of design and implementation decisions for the Northbridge
Provisions identity environment, with the reasoning behind each one.

---

## Baseline — Entra ID tenant, before any changes

Captured before building anything, so improvements can be measured against it.

- 1 user, 0 groups, 0 devices, 0 applications
- Entra Connect: disabled (nothing to sync yet)
- Identity Secure Score: 68.42%
- High-privileged role assignments: 1
- Licence tier: Entra ID Free

**Note:** that single high-privileged assignment is my own account holding
permanent Global Administrator. In a production tenant that is exactly what
an access review flags — standing privilege on a daily-use account. Fixing
it with a separate admin account and PIM activation is on the build plan.

---

## Licensing — Entra ID Free, with a timed P2 trial

**Chose:** Entra ID Free as the baseline, with the 30-day P2 trial activated
only when the governance phase begins.

**Why:** P2 is what gates PIM, Identity Protection, and access reviews. It is
published around $9–10 per user per month on an annual commitment, so there
is no casual month-to-month option once the trial lapses. Sequencing the build
so all P2-dependent work happens inside one concentrated window means the
features get built, exercised, and documented before the trial ends.

**Rejected:** the Microsoft 365 Developer Program E5 sandbox, which would have
included P2 indefinitely. Microsoft has restricted eligibility to Visual Studio
Professional/Enterprise subscribers and certain partners; neither a personal
nor a university account qualified.

**Trade-off:** the environment loses governance features when the trial
expires. AD, hybrid sync, the automation scripts, and all documentation
continue to work. Screenshots and written findings are what persist.

---

## Hosting — local hypervisor rather than Azure VMs

**Chose:** run the domain controller locally in VirtualBox.

**Why:** Azure VMs are the only meaningful recurring cost in this build.
Resource groups, virtual networks, network security groups, and tagging are
free; compute is not. Running the DC locally keeps the project at zero cost.

**Rejected:** Hyper-V, which is unavailable on Windows 10 Home. VirtualBox is
free and supports the same workload.

**Constraint:** 16 GB host RAM. 4 GB to the domain controller and 4 GB to a
client VM leaves adequate headroom.

---

## AD domain name — corp.northbridge.local

**Chose:** `corp.northbridge.local`

**Why:** `corp` as a subdomain is common enterprise practice and leaves room
for other internal namespaces. `.local` signals an internal-only namespace
and avoids collision with a real registered domain.

**Trade-off:** `.local` conflicts with mDNS/Bonjour on some networks and
Microsoft now recommends a registered subdomain such as `ad.northbridge.com`
for greenfield builds. Accepted here because this environment is isolated and
never needs a publicly trusted certificate.

---

## VM configuration — NB-DC01

4 GB RAM, 2 vCPU, 60 GB dynamic disk, Windows Server 2022 Standard Evaluation
with Desktop Experience.

**Networking: bridged, not NAT.** Bridged gives the VM its own address on the
physical network, so the host can reach the domain controller directly and the
VM can reach the internet for Entra Connect. NAT would isolate the VM behind
the host and complicate both.

**Chose Desktop Experience over Server Core** for the GUI, since the goal is
learning the administrative surface rather than minimising footprint.

**Rejected VirtualBox unattended installation** so the setup steps are
performed manually and can be described accurately.

---

## Static IP addressing — 192.168.1.10

**Chose:** static IPv4 at `192.168.1.10/24`, gateway `192.168.1.1`, DNS
pointing at `127.0.0.1`.

**Why static:** a domain controller also hosts DNS for the domain, and clients
locate the domain by querying it at a fixed address. Under DHCP the address
would eventually change and domain resolution would break.

**Why DNS points at itself:** the DC is the authoritative DNS server for
`corp.northbridge.local` and has to resolve its own domain records. Pointing
DNS at the router instead is a common mistake that causes domain join failures
with no obvious cause.

**Address choice:** `.10` sits below the typical consumer DHCP pool start of
`.100`, avoiding collision. *Open item: confirm the router's actual pool range.*

**Later addition:** `::1` added alongside `127.0.0.1` so IPv6 resolution
targets the local DNS server too, which silenced a class of dcdiag warnings.

---

## Forest creation — corp.northbridge.local / NORTHBRIDGE

    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Install-ADDSForest -DomainName "corp.northbridge.local" `
                       -DomainNetbiosName "NORTHBRIDGE" -InstallDns

**Result:** new forest, domain functional level `Windows2016Domain`, all five
FSMO roles held by NB-DC01, DNS zones created for `corp.northbridge.local`,
`_msdcs`, `ForestDnsZones` and `DomainDnsZones`.

**NetBIOS name set explicitly.** The default would have been `CORP`, derived
from the first domain label. `NORTHBRIDGE` was chosen so the legacy login
format reads `NORTHBRIDGE\username` rather than something generic.

**On the functional level:** `Windows2016Domain` is the highest available —
Microsoft stopped raising domain functional levels after 2016, so Server 2019
and 2022 both top out there. Not a limitation of this build.

---

## Issue — SRV records failed to register after rename

**Symptom:** `dcdiag /test:dns` failed the RReg (record registration) subtest.
Dozens of missing SRV records reported — `_ldap._tcp`, `_kerberos._tcp`,
`_gc._tcp` and others — against both `192.168.1.10` and `::1`. Every other DNS
subtest passed: Auth, Basc, Forw, Del, Dyn.

**Cause:** the server was promoted to domain controller while still carrying
its default install hostname (`WIN-F2MRU4V827L`), and renamed to `NB-DC01`
afterwards. Netlogon had registered the domain's SRV records against the
original hostname, so no records existed pointing at the new name.

**Fix:**

    Restart-Service Netlogon
    ipconfig /registerdns

Re-tested with `dcdiag /test:dns` — RReg passed.

**Lesson:** rename the server *before* promoting it to a domain controller.
Renaming afterwards is supported and does update service principal names, but
it leaves stale DNS registrations that must be forced to re-register. Doing it
before promotion avoids the problem entirely.

---

## Verification — post-promotion health checks

Run to confirm the forest was healthy before proceeding:

| Check | Result |
|---|---|
| `Get-ADDomain` | Forest details returned correctly |
| `Get-Service adws, kdc, netlogon, dns` | All Running |
| `Get-SmbShare` for SYSVOL / NETLOGON | Both shared |
| `dcdiag /test:dns` | All subtests pass |
| `Test-NetConnection 8.8.8.8` | True |

SYSVOL and NETLOGON existing as shares is the signal that promotion completed properly rather than partially.

---

## Hybrid sync method — password hash sync

**Chose:** password hash sync (PHS), with password writeback enabled.

**Why:** Northbridge has one small IT function supporting a corporate office,
a distribution centre, and 460 delivery points. Corporate staff need Microsoft
365 from home and on the road. PTA and federation both make cloud
authentication depend on the on-prem environment being reachable — a power cut
at the distribution centre or a dead line means nobody can reach email from
anywhere. PHS puts authentication entirely in Microsoft's cloud, so the on-prem
estate can be down and cloud sign-in still works.

It is also the least infrastructure: one sync server, no federation farm, no
certificate lifecycle, no agents to keep alive. For an organization with
Northbridge's realistic IT headcount that matters more than the flexibility
the alternatives offer.

**Secondary benefit:** PHS is what enables Entra ID Protection's leaked
credential detection — Microsoft compares synced hashes against credentials
found in breach dumps. That signal does not exist under PTA or federation.
Given the PCI-driven governance story, that is a real argument.

**Rejected — PTA:** legitimate for organizations whose policy forbids password
material, even hashed, from leaving the premises. Northbridge has no such
requirement, so it trades cloud resilience for a constraint that does not exist
here.

**Rejected — AD FS:** maximum control, at the cost of a server farm,
certificate management, and a high-value attack target. Microsoft is steering
customers away from it. Heavy over-engineering at this scale.

**Note:** what syncs is a hash *of* the password hash — re-hashed, not the
original credential — so a compromised tenant does not hand an attacker
something directly reusable against the on-prem domain.

---

## OU structure — nested under a single top-level OU

**Chose:** one `Northbridge` OU at the top, with everything beneath it, and
users separated from computers.

**Why a single parent rather than hanging OUs off the domain root:** Group
Policy linked at `Northbridge` applies to the whole organization without
touching the Domain Controllers OU, which domain-root policy would also hit.
It also gives one clean delegation point if administration is ever handed to a
junior admin.

**Why users and computers are separated:** user policy and computer policy are
different settings. Mixing them means every GPO needs filtering.

**Organized by function, not geography**, because the access model follows job
role rather than location. Warehouse staff need the same systems wherever they
are.

**Trade-off accepted:** a function-first structure handles a second site badly.
If Northbridge opened another distribution centre with different policy
requirements, this would need restructuring. Geography-first would have handled
that and made departmental grouping harder. The structure follows the access
model.

**Seasonal workers placed under External, not Operations.** They are employees
rather than contractors, so Operations is defensible. External was chosen
because their *lifecycle* resembles a contractor's — short tenure, bulk on and
off, time-bound access — and lifecycle is what drives the automation.

**Groups OU added mid-build.** The original structure had no home for groups,
which would have left them in the default `CN=Users` container — not linkable
for GPO and awkward to delegate. Split into `Roles` and `Resources` to mirror
the group model.

---

## Group model — AGDLP

**Chose:** accounts into Global role groups, role groups nested into Domain
Local resource groups, permissions applied only to the resource groups.

**The rule:** a user never receives a permission directly. Ever.

**Why, concretely — the mover case.** When someone transfers from Warehouse to
Dispatch, they are removed from one role group and added to another, and their
entire entitlement set swaps in a single operation. With direct permissions you
would have to find every share, application and system they touched. Nobody
ever finds them all, and the leftovers are privilege creep. This makes that
failure structurally impossible rather than a matter of diligence.

**Naming convention `ROLE_` and `RES_`:** anyone reading a membership list can
immediately tell whether they are looking at a job function or an entitlement.

**Read and write split into separate resource groups:** a resource group grants
one level of access to one thing. A combined `RES_ERP_Access` could not give
warehouse supervisors read-only without inventing a second group anyway.

**Every group carries a description**, because the access review generates a
report of who holds what, and a report of bare group names is unreadable. This
is the difference between a directory that can be audited and one that cannot.

**On scope:** Global groups hold accounts from their own domain but can be
granted permissions forest-wide; Domain Local can hold accounts from any
trusted domain but grant only within their own. Largely academic in a
single-domain forest — built correctly anyway so the model survives if
Northbridge acquires a company and adds a domain.

---

## Access model decisions

**Seasonal warehouse workers: WMS write, no VPN, no ERP.** They do the same
floor work as permanent staff, so restricting the warehouse system would stop
them working. Short-tenure workers do not get remote access or financial data.

**Drivers: dispatch application only.** Forty people with the narrowest access
in the company, because that is all the role requires. The largest headcount
groups often need the least.

**Contractors: nothing by default.** `ROLE_Contractor` exists but appears
nowhere in the access model. Contractor access is granted per engagement and
time-bound. A contractor role carrying standing entitlements would be standing
risk.

**VPN: corporate roles only.** Warehouse staff and drivers work on site.
Obvious written down, almost never enforced in practice.

---

## Tiered administration — Tier 0/1/2

**Chose:** three admin tiers with separate accounts per tier, distinct from
daily-use accounts, enforced by Group Policy deny rights.

| Tier | Controls | Logs into |
|---|---|---|
| Tier 0 | Domain controllers, AD | DCs only |
| Tier 1 | Member servers, applications | Servers only |
| Tier 2 | Workstations, end users | Workstations only |

**What this prevents:** an attacker compromises a warehouse PC, finds cached
domain admin credentials left from an IT visit, and owns the domain. That is
credential theft via lateral movement, and it is how most real breaches
escalate. If a Tier 0 account never logs into a workstation, there are no Tier 0
credentials on workstations to steal.

**Groups alone are only a naming convention.** The enforcement is Group Policy
`Deny log on locally` and `Deny log on through Remote Desktop Services`, linked
to the *computer* OUs rather than the user OUs — it is a property of the
machine, not the account. Deny always overrides allow in Windows, so the
boundary is absolute.

**Lab shortcut noted:** all three tier accounts were created with the same
password prompt for convenience. In any real environment each tier would have
distinct credentials, and ideally Tier 0 would not have a standing password at
all.

---

## Password policy — no forced expiry

**Chose:** minimum length 14, history 24, complexity on, **maximum password age
0 (never expires)**, minimum age 1 day.

**Why no expiry:** NIST SP 800-63B and current Microsoft guidance both
recommend against forced periodic rotation. It drives predictable increments —
`Spring2026!` becoming `Summer2026!` — which is weaker than a long password
retained until there is evidence of compromise. The compensating controls are
length, breach detection via PHS leaked-credential monitoring, and MFA.

**Trade-off:** most environments still run 90-day expiry out of habit, and some
auditors expect to see it. The position is defensible on published guidance,
but it is a position, not a default.

---

## Account lockout — threshold of 10, not 3

**Chose:** lockout after 10 invalid attempts, 15-minute duration, 15-minute
counter reset.

**Why not 3:** a tight threshold is a denial-of-service lever. An attacker can
lock out every account in the domain by deliberately failing three logins
against each one. Ten attempts with a short automatic reset window blocks brute
force without handing anyone that capability.

---

## Security baseline

**NTLM hardening:** LM hash storage disabled, LAN Manager authentication level
set to send NTLMv2 only and refuse LM and NTLM. NTLMv1 and LM hashes are
trivially crackable and exist only for compatibility with systems Northbridge
does not run.

**Screen lock:** 900-second machine inactivity limit. Shared warehouse
workstations are the reason this matters — an unlocked session on a shared
terminal defeats per-user attribution entirely.

**Audit policy:** configured through Advanced Audit Policy Configuration rather
than the legacy node, for subcategory granularity. Enabled: Logon, Account
Lockout, User Account Management, Security Group Management, Directory Service
Changes, Credential Validation.

**Security Group Management is the one that matters most for this project** —
it logs additions to privileged groups, which is the evidence the access review
will depend on. Enabled now so the logs exist by the time they are needed.

**Two GPOs rather than one**, because domain password and lockout policy only
takes effect when linked at the domain root. An OU-linked account policy is
silently ignored — a Windows behaviour worth knowing before debugging why a
policy "did not apply."