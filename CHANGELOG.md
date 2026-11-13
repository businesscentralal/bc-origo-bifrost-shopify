# Changelog

## [28.0.0.0] - Unreleased

- Moved Shopify scaffold objects 70013400–70013402 to 73731950–73731952 and the app allocation to 73731950–73732149 (#54). Test objects remain in 97400–97599.

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Customer.Sync` (enum value 73732000, codeunits 73732000/73732001): imports Shopify customers and updates Shopify customers from Business Central for one shop, as the shop is set up, through the connector codeunit Shpfy Sync Customers (30123), the code behind the Sync action; granted through `SHOPIFY Full ori` (#16). Tests in codeunits 97450/97451.
