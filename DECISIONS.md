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

SYSVOL and NETLOGON existing as shares is the signal that promotion completed
properly rather than partially.