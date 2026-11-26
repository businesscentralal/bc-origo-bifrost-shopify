namespace Origo.Bifrost.Shopify;

/// <summary>Grants the adapter's action surface; callers must also hold Microsoft Shopify permissions.</summary>
permissionset 73731952 "SHOPIFY Full ori"
{
    Assignable = true;
    Caption = 'Bifrost Shopify Full', MaxLength = 30, Comment = 'is-IS=Bifröst Shopify allur aðgangur';
    IncludedPermissionSets = "SHOPIFY Read ori";
    Permissions = codeunit "Invoice Sync Impl ori" = X,
                  codeunit "Invoice Sync Run ori" = X,
                  codeunit "Product SyncPrices Impl ori" = X,
                  codeunit "Customer Sync Impl ori" = X,
                  codeunit "Customer Sync Run ori" = X,
                  codeunit "Customer Sync Monitor ori" = X,
                  tabledata "Customer Sync Marker ori" = RIMD,
                  codeunit "Fulfillment Sync Impl ori" = X,
                  codeunit "Fulfillment Sync Run ori" = X,
                  codeunit "Product CreateItem Impl ori" = X,
                  codeunit "Product CreateItem Run ori" = X,
                  codeunit "Order CreateSalesDoc Impl ori" = X,
                  codeunit "Product Sync Impl ori" = X,
                  codeunit "Refund CrMemo Impl ori" = X,
                  codeunit "Inventory Sync Impl ori" = X,
                  codeunit "Inventory Sync Run ori" = X,
                  codeunit "Order Import Impl ori" = X,
                  codeunit "Order Import Run ori" = X;
}
