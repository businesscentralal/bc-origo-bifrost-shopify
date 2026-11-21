# Changelog

## [28.0.0.0] - Unreleased

- `Shopify.Order.CreateSalesDocument` (enum value 73732020, codeunit 73732020) refuses with `PreconditionFailed` before any change when the order's shop has Return and Refund Process = Auto Create Credit Memo, and the success response adds `documentStatus` (Open, Released, Pending Approval, Pending Prepayment), the same name in every language. Existing request and response fields are unchanged (#59). Tests in codeunit 97470. No new objects.
- Moved Shopify scaffold objects 70013400–70013402 to 73731950–73731952 and the app allocation to 73731950–73732149 (#54). Test objects remain in 97400–97599.
- Moved `Shopify.Order.CreateSalesDocument` enum extension, enum value and codeunit from 70013470 to 73732020 (the #54 mapping); restores the main build after #55 (AL0297) (#56).
- Numbered `Shopify.Fulfillment.Sync` enum extension, enum value and codeunits 73731980/73731981 (the #54 mapping of 70013430/70013431) when merging main into #46 (#29).
- MCP fixture codeunit 97471 now sets the fixture shop's "Order Attributes To Shopify" to false, so `Shopify.Order.CreateSalesDocument` can create the document without asking Shopify for an access token (#56).

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Order.Import` (enum value 73731960, codeunits 73731960/73731961): fetches new and changed orders of one Shopify shop and imports and maps them by running report Sync Orders from Shopify (30104); granted through `SHOPIFY Full ori` (#23). Tests in codeunit 97472.
- Added message type `Shopify.Product.CreateItem` (enum value 73731970, codeunits 73731970/73731971): creates and maps Business Central items for the variants of one imported Shopify product through the connector codeunit Shpfy Create Item (30171); granted through `SHOPIFY Full ori` (#8). Tests in codeunit 97420.
- Added message type `Shopify.Refund.CreateCreditMemo` (enum value 73731955, codeunit 73731954): creates the credit memo of an imported Shopify refund through the shop's refund process (Shpfy RetRefProc Cr.Memo, which runs Shpfy Create Sales Doc. Refund 30246); granted through `SHOPIFY Full ori` (#30). Tests in codeunit 97401.
- Added message type `Shopify.Fulfillment.Sync` (enum value 73731980, codeunits 73731980/73731981): sends one posted sales shipment of a Shopify order to Shopify as a fulfillment by running the connector report Sync Shipments To Shopify (30109); granted through `SHOPIFY Full ori` (#29). Tests in codeunit 97430; the live Shopify success path is not covered by container tests.
- Added message type `Shopify.Order.CreateSalesDocument` (enum value 73732020, codeunit 73732020): creates the sales order or invoice of an imported Shopify order by running Shopify's report Shpfy Create Sales Orders (30103) for that one order; granted through `SHOPIFY Full ori` (#24). Tests in codeunits 97470 and 97471.
- Added message type `Shopify.Product.Sync` (enum value 73732010, codeunit 73732010): runs the connector's own product sync for one shop (report Shpfy Sync Products, not the price-only mode) to import products from Shopify and export changed items as the shop is set up; granted through `SHOPIFY Full ori` (#6). Tests in codeunit 97460.
- Added message type `Shopify.Inventory.Sync` (enum value 73732030, codeunits 73732030/73732031): sends the stock levels per location of one enabled shop to Shopify by running the connector report Shpfy Sync Stock to Shopify (30102); options `skipImport` and `variantIdFilter`; granted through `SHOPIFY Full ori` (#14). Tests in codeunit 97480.
