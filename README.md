# Northbridge Provisions — Hybrid Identity Environment

A hands-on IAM lab: an enterprise hybrid identity environment built from
scratch, with automated lifecycle management and a full access review.

## The scenario

Northbridge Provisions is a fictional 300-person regional food distributor.
Corporate staff run on Microsoft 365; warehouse and ERP systems are
on-premises and AD-joined, so identity has to work across both. Seasonal
hiring and contractor turnover mean lifecycle management has to be automated
rather than manual, and PCI-DSS obligations require documented access control
and periodic reviews.

This lab builds that identity environment from scratch and runs the
governance process against it.

## Workforce

| Group | Count | Identity characteristics |
|---|---|---|
| Corporate | 90 | Cloud-first, M365, remote-capable |
| Warehouse | 140 | Shared workstations, on-prem apps, high turnover |
| Drivers | 40 | Mobile, minimal system access |
| Seasonal | ~30 at peak | Short tenure, bulk on/offboarding |
| Contractors | ~15 | External, time-bound access |

## Architecture

HR feed (CSV) → PowerShell provisioning → Active Directory → Entra Connect
→ Entra ID → SaaS applications

One authoritative source. Identity data flows one direction. No account is
created by hand at any point in that chain.

## Stack

Windows Server 2022 · Active Directory Domain Services · Microsoft Entra ID ·
Entra Connect · Group Policy · Azure (resource groups, VNet, NSGs) ·
PowerShell (ActiveDirectory, Microsoft.Graph)

## What's here

- [`DECISIONS.md`](DECISIONS.md) — design decisions and the reasoning behind them
- [`docs/`](docs/) — architecture, identity framework, JML workflows
- [`scripts/`](scripts/) — provisioning, offboarding, role change, reporting
- [`findings/`](findings/) — access review report and remediation

## Status

In progress. Built and documented as I go.
