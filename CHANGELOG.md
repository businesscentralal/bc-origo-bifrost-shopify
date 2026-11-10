# Changelog

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Inventory.Sync` (enum value 70013480, codeunits 70013480/70013481): sends the stock levels per location of one enabled shop to Shopify by running the connector report Shpfy Sync Stock to Shopify (30102); options `skipImport` and `variantIdFilter`; granted through `SHOPIFY Full ori` (#14). Tests in codeunit 97480.
