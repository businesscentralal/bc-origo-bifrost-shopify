# Changelog

## [28.0.0.0] - Unreleased

- Moved Shopify scaffold objects 70013400–70013402 to 73731950–73731952 and the app allocation to 73731950–73732149 (#54). Test objects remain in 97400–97599.
- Moved `Shopify.Order.CreateSalesDocument` enum extension, enum value and codeunit from 70013470 to 73732020 (the #54 mapping); restores the main build after #55 (AL0297) (#56).
- MCP fixture codeunit 97471 now sets the fixture shop's "Order Attributes To Shopify" to false, so `Shopify.Order.CreateSalesDocument` can create the document without asking Shopify for an access token (#56).

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Order.Import` (enum value 73732030, codeunits 73732030/73732031): fetches new and changed orders of one Shopify shop and imports and maps them by running report Sync Orders from Shopify (30104); granted through `SHOPIFY Full ori` (#23). Tests in codeunit 97403.
- Added message type `Shopify.Order.CreateSalesDocument` (enum value 73732020, codeunit 73732020): creates the sales order or invoice of an imported Shopify order by running Shopify's report Shpfy Create Sales Orders (30103) for that one order; granted through `SHOPIFY Full ori` (#24). Tests in codeunits 97470 and 97471.
