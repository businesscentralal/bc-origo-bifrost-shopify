# Bifröst Shopify

**App name:** Bifrost Shopify
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.0 minimum, runtime 17.0)
**App ID:** `61a67425-c1e2-45e1-85b5-9e01488f6c1d` — **Test app ID:** `435aa982-b3bd-4074-8b2a-f30781c17504`
**Object ID range:** 73731950–73732149 (tests 97400–97599) — **Namespace:** `Origo.Bifrost.Shopify`

Bifrost Shopify makes Microsoft's **Shopify Connector** app callable from outside Business Central through
Bifröst message types, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Shopify>

**Status:** Shopify Connector operations are registered as Bifröst message types. See the in-app message contracts for supported requests, permissions and effects. `Shopify.Transaction.SuggestPayments` writes cash receipt journal lines through the connector without posting; its runtime help explains eligibility, confirmation count and repeat-call behavior.

## Shopify.Payment.SyncDisputes

`Shopify.Payment.SyncDisputes` imports new disputes and refreshes open disputes for one enabled shop:

```json
{"type":"Shopify.Payment.SyncDisputes","data":{"shopCode":"WEBSHOP"}}
```

It returns `status`, `shopCode`, `disputesBefore` and `disputesAfter`. Repeated calls are idempotent.
Unchanged counts can also mean the shop has no Shopify Payments account. Connector errors roll back
dispute changes and Shopify log entries from the failed run. Callers need `SHOPIFY Full ori` and
Microsoft Shopify Connector permissions. Runtime help supplies the full contract, notes and examples.

---

## Shopify.Customer.Add

```json
{"type":"Shopify.Customer.Add","data":{"shopCode":"WEBSHOP","customerNos":["C00010"],"expectedCount":1}}
```

Creates and links selected Business Central customers through connector report 30112. Use `Help.MessageType.Get` for its runtime contract. Use an enabled shop with a configured positive Shop Id, 1–100 distinct customer numbers and a matching integer `expectedCount`. Callers need `SHOPIFY Full ori` and Microsoft Shopify customer permissions. Existing links in the selected shop return `alreadyLinked`; repeating a completed call creates no duplicate.

The response reports `requested`, `created`, `alreadyLinked`, `failed` and one result per customer with its Shopify ID. Failed customers include the connector error or fresh skipped-record reason and do not stop the others. Local writes roll back separately for each failed customer; completed Shopify requests cannot be rolled back. After a connection failure, check Shopify before retrying. Runtime help contains the complete English Overview, Notes, Examples and error contract; labels and refusals support English and Icelandic.

## Shopify.Metafield.Sync

```json
{"type":"Shopify.Metafield.Sync","data":{"shopCode":"WEBSHOP","direction":"SendValues","ownerType":"Product","ownerId":123,"expectedCount":2}}
```

Use `GetDefinitions` to load one owner's metafield definitions into Business Central, or `SendValues` to send changed values to Shopify. Required keys are `shopCode`, `direction`, `ownerType` (`Product`, `Variant`, `Customer` or `Company`) and a positive Shopify `ownerId`. `SendValues` also requires `expectedCount` to match all local metafield rows for that owner. Both directions are idempotent for unchanged data.

The shop must be enabled and the owner must belong to that shop. Callers need `SHOPIFY Full ori` and Microsoft Shopify permissions. Edit values separately with `Data.Records.Set`. The response includes `status`, the four target keys, `metafieldsBefore` and `metafieldsAfter`. Counts describe local rows, including unsent rows. Connector 28 excludes legacy `string`/`integer` types and empty values from bulk sending; Money values must use the shop currency. Local runner writes roll back on refusal; completed Shopify requests cannot be rolled back.

The public `Shpfy Metafields` API (30418) is wrapped by implementation/enum value 73732060 and runner 73732061. Mock dispatcher tests 97510, stand-in 97511 and fixture 97512 cover both directions, all owners, refusals and rollback. Unknown keys are rejected by Foundation as `UnknownParameter` before dispatch. Runtime help contains the full English Overview, Notes, Examples and error contract; captions and refusals support English and Icelandic.

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 73731950-73732149 |
| Test app (`test/`) | 97400-97599 |

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://docs.bifrost.origo.is>.

| What | Where |
| --- | --- |
| Product documentation | <https://docs.bifrost.origo.is/en-us/shopify/> |
| Bifröst documentation home | <https://docs.bifrost.origo.is> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

---

## Dependencies

| App | ID | Publisher | Version |
| --- | --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.15.807 |
| Shopify Connector | `ec255f57-31d0-4ca2-b751-f2fa7c745abb` | Microsoft | 28.0.0.0 |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Shopify`), registration and permission roles |
| `test/` | Test app (`Bifrost Shopify - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

`Shopify.Company.Sync` synchronizes one shop’s B2B companies and BC customer links according to its company settings. Call with `{"shopCode":"WEBSHOP"}`; the response echoes import/export settings and local company counts. Full permission is required. The runtime contract supplies Overview, Notes and Examples.
