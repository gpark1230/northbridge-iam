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