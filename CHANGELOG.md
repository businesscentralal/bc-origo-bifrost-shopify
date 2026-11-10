# Changelog

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Refund.CreateCreditMemo` (enum value 70013405, codeunit 70013404): creates the credit memo of an imported Shopify refund through the shop's refund process (Shpfy RetRefProc Cr.Memo, which runs Shpfy Create Sales Doc. Refund 30246); granted through `SHOPIFY Full ori` (#30). Tests in codeunit 97401.
