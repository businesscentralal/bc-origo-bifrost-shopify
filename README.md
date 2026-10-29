# Bifröst Shopify

**App name:** Bifrost Shopify
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28.5, runtime 17.0)
**App ID:** `61a67425-c1e2-45e1-85b5-9e01488f6c1d` — **Test app ID:** `435aa982-b3bd-4074-8b2a-f30781c17504`
**Object ID range:** 70013400–70013599 (tests 97400–97599) — **Namespace:** `Origo.Bifrost.Shopify`

Bifrost Shopify will make Microsoft's **Shopify Connector** app callable from outside Business Central through
Bifröst message types, so an agent can operate it end to end. It is built on the same basis as
[Bifrost Subscription Billing](https://github.com/businesscentralal/bc-origo-bifrost-subscription-billing).

**Microsoft source:** <https://github.com/microsoft/BCApps/tree/main/src/Apps/W1/Shopify>

**Status:** planning, no message types yet.

---

## Object ranges

| Object | Range |
| --- | --- |
| App (`app/`) | 70013400-70013599 |
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
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo | 28.0.5.590 |
| Shopify Connector | `ec255f57-31d0-4ca2-b751-f2fa7c745abb` | Microsoft | 28.5.0.0 |

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Shopify`), no AL code yet |
| `test/` | Test app (`Bifrost Shopify - Tests`) |
| `tools/` | Pipeline guard scripts |
| `.AL-Go/`, `.github/`, `.alpaca/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |
