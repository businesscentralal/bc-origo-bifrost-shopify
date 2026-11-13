# Changelog

## [28.0.0.0] - Unreleased

- Repository scaffolded from Bifrost Subscription Billing setup.
- Added Foundation app registration, adapter permission roles and registration smoke tests (#1).
- Set application and Shopify Connector minimum versions to 28.0.0.0; validated deployment on bc28-kappi without upgrading the container.

- Bound permission-set captions to 30 characters (70013400–70013402), shortened the Icelandic Full caption, and removed API role extension 70013400 to keep the scaffold aligned with the Subscription Billing roles.
- Added restricted Read/Full registration checks to test codeunit 97400; assertions run after restoring runner permissions.
- Added message type `Shopify.Order.CreateSalesDocument` (enum value 70013470, codeunit 70013470): creates the sales order or invoice of one imported Shopify order through report 30103 Shpfy Create Sales Orders (codeunits 30167/30166); granted through `SHOPIFY Full ori` (#24). Tests in codeunit 97470, MCP fixture 97471.
- `Shopify.Order.CreateSalesDocument` refuses with `PreconditionFailed` before any change when the order's shop has Return and Refund Process = Auto Create Credit Memo and unprocessed refunds exist, so the unscoped refund phase of codeunit 30167 never touches other orders or shops and cannot fail after the order commit; `documentType` and `documentStatus` are returned as invariant enum names in every language (#24, Worker review 6856926644).
