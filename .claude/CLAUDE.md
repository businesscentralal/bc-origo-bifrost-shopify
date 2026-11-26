# Extension: Bifrost Shopify

## Customer
Origo / AppSource

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Shopify` namespace; same as Bifrost Subscription Billing)

## Namespace
Origo.Bifrost.Shopify (tests: Origo.Bifrost.Shopify.Test)

## Object ID Range
App:   73731950-73732149
Tests: 97400-97599

| Type | ID | Object |
| --- | --- | --- |
| Codeunit | 73731950 | Shopify Registration ori |
| PermissionSet | 73731950 | SHOPIFY Base ori |
| PermissionSet | 73731951 | SHOPIFY Read ori |
| PermissionSet | 73731952 | SHOPIFY Full ori |
| PermissionSetExtension | 73731951 | Shopify Read ori |
| PermissionSetExtension | 73731952 | Shopify Full ori |
| Codeunit | 73731970 | Product CreateItem Impl ori |
| Codeunit | 73731971 | Product CreateItem Run ori |
| EnumExtension | 73731970 | Product CreateItem MsgType ori (value Shopify.Product.CreateItem) |
| Codeunit | 73731980 | Fulfillment Sync Impl ori |
| EnumExtension | 73731980 | Fulfillment Sync MsgType ori (value Shopify.Fulfillment.Sync) |
| Codeunit | 73731981 | Fulfillment Sync Run ori |
| Codeunit | 73732010 | Product Sync Impl ori |
| EnumExtension | 73732010 | Product Sync MsgType ori (value Shopify.Product.Sync) |
| Codeunit | 73732000 | Customer Sync Impl ori |
| EnumExtension | 73732000 | Customer Sync MsgType ori |
| Codeunit | 73732001 | Customer Sync Run ori |
| Codeunit | 73732002 | Customer Sync Monitor ori |
| Table | 73732000 | Customer Sync Marker ori |
| Codeunit | 73732020 | Order CreateSalesDoc Impl ori |
| EnumExtension | 73732020 | Order SalesDoc MsgType ori (value Shopify.Order.CreateSalesDocument) |
| Codeunit | 73731960 | Order Import Impl ori |
| Codeunit | 73731961 | Order Import Run ori |
| EnumExtension | 73731960 | Order Import MsgType ori (value Shopify.Order.Import) |
| Test Codeunit | 97472 | Shopify Order Import Tests ori |
| Test Codeunit | 97473 | Shopify OrdImport Fixture ori |
| Test Codeunit | 97400 | Shopify Issue 1 Tests ori |
| Test Codeunit | 97430 | Shpfy Fulfill Sync Tests ori |
| Test Codeunit | 97431 | Shpfy Fulfill MCP Fixture ori |
| Test Codeunit | 97460 | Shpfy Prod Sync Test ori |
| Test Codeunit | 97461 | Shpfy Prod Sync MCP ori |
| Test Codeunit | 97450 | Shpfy Cust Sync Test ori |
| Test Codeunit | 97451 | Shpfy Customer MCP Fixture ori |
| Test Codeunit | 97452 | Shpfy Cust Sync Stub ori |
| Test Codeunit | 97453 | Shpfy Cust Fail Step ori |
| Test Codeunit | 97470 | Shopify Order Create Tests ori |
| Test Codeunit | 97471 | Shopify Order MCP Fixture ori |

New issue #34 objects (checked against open PRs #66 and #67 on 26.11.2026): enum extension/value and implementation 73732060 `Suggest Payments MsgType ori` / `Suggest Payments Impl ori`; runner 73732061 `Suggest Payments Run ori`; manual journal-navigation subscriber 73732062 `Suggest Payments UI Guard ori`; tests 97510 `Shpfy Suggest Tests ori`, mock subscriber 97511 `Shpfy Suggest Stub ori`, MCP fixture 97512 `Shpfy Suggest Fixture ori`.

Integration note for PR #43: the temporary import app IDs 73732030/73732031 in commit 79654f2 are reconciled to 73731960/73731961, following the published #54 mapping (70013400+n → 73731950+n). Import test codeunits remain 97472/97473 from that branch update; the 97400–97599 test range is unchanged.

## Microsoft source
Wrapped Microsoft app: Shopify Connector (`ec255f57-31d0-4ca2-b751-f2fa7c745abb`, minimum 28.0.0.0). Source: https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Shopify
Read it there before designing message types.

## Setup Notifications
Setup notifications live **only** on Bifröst Foundation's `Setup ori` page. This app never raises a `Notification` of its own.
It makes itself known to Foundation by subscribing to `App Registry ori.OnRegisterApps` and calling `AddApp` with this
app's module id, its display name and its setup page id (`0` while the app has no setup page). Follow
`app/src/Common/SubRegistration.Codeunit.al` in Bifrost Subscription Billing.

## Target BC Version
28.0 minimum (application 28.0.0.0, platform 28.0.0.0, runtime 17.0).
Deploy and test through the bc28-kappi MCP server; leave its container version unchanged.

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-shopify
Default branch: main

## Dependencies
- Bifrost Foundation (`7505e808-6e52-4b96-a328-82573391297a`, 28.0.15.807, current Foundation release 28.0.15)
- Shopify Connector (Microsoft, 28.0.0.0; application floor 28.0.0.0)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix), max 30 characters.
- The brand name "Bifrost" lives in the namespace, the app name ("Bifrost Shopify"), the permission sets and
  user-facing captions - never as an object-name prefix.
- Message type names have three parts: `Domain.Entity.Action`.
- Icelandic captions use "Bifröst".

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills: `origo-bc-al-coding-standards`, `origo-bc-test-writer`, `origo-bc-documentation-writer`.

Key rules always in effect:
- Namespace `Origo.Bifrost.Shopify` at the top of every app file (`Origo.Bifrost.Shopify.Test` in tests)
- XML documentation on every object and non-local procedure
- Bilingual captions (en-US + is-IS) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- Implementation = code + tests + documentation (the contract chapters of `Msg Contract ori`)

## Development Environment
- COSMO Alpaca containers are defined in `app/.vscode/launch.json` (git-ignored, the authority for instance ids).
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop; AL-Go CI is the gate for AppSource affix rules (AS0011).
- `app/AppSourceCop.json` sets `mandatoryAffixes`/`mandatorySuffix` to `ori` and the supported countries.
- Reference implementation: Bifrost Subscription Billing (businesscentralal/bc-origo-bifrost-subscription-billing).

## Message Type Conventions
- One enum extension of Foundation's `Message Type ori` with one value per type, named `Domain.Entity.Action`. These
  keys are the published external API contract and must never be renamed or removed.
- Each type has an Impl codeunit implementing `Msg Interface ori`, `Msg Discovery ori` and `Msg Contract ori`, with
  `TableNo = "Message Argument ori"` and an `OnRun` that runs its own write, as in Bifrost Subscription Billing.
- Errors are returned as `status = Error` with a helpful message; never let an unhandled exception reach the API.

## Test App Rules
- The test app uses Bifröst Foundation's public API only. Run message types through the public `Dispatcher ori`.

## Testing Through the MCP Server
- Keep MCP calls serial - parallel bursts crash the server.
