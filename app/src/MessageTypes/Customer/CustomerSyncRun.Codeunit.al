namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify connector codeunit Shpfy Sync Customers (30123), the code behind the report Shpfy Sync Customers (30100)
/// that the Sync action on Shopify Customers and on the Shopify Shop Card starts, for one shop. The Shopify codeunit is
/// internal, so it is started by its ID. The caller starts this codeunit with Run in an if statement, so a failure rolls
/// back what the Shopify code changed in this transaction.
/// </summary>
codeunit 73732001 "Customer Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];

    trigger OnRun()
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Get(ShopCode);
        // Shpfy Sync Customers (30123) has TableNo "Shpfy Shop" and imports and updates customers as the shop is set up.
        if not Codeunit.Run(30123, Shop) then
            Error(GetLastErrorText());
    end;

    /// <summary>Sets the shop the customers are synchronized for.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    procedure SetShopCode(NewShopCode: Code[20])
    begin
        ShopCode := NewShopCode;
    end;
}
