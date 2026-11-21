namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify connector codeunit Shpfy Sync Customers (30123), the code behind the report Shpfy Sync Customers (30100)
/// that the Sync action on Shopify Customers and on the Shopify Shop Card starts, for one shop. The Shopify codeunit is
/// internal, so it is started by its ID. The caller starts this codeunit with Run in an if statement, so a failure rolls
/// back what the Shopify code changed in this transaction.
/// The caller runs it in two passes: the import pass (Shopify to Business Central, the shop's Can Update Shopify Customer
/// switched off in memory) and then the update pass (Business Central to Shopify, the shop's Customer Import From Shopify set
/// to None in memory). The shop record in the database is not changed; the connector reads it again before it saves the
/// last sync time. Splitting the passes lets the caller check the result of the import on its own.
/// </summary>
codeunit 73732001 "Customer Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        ImportPass: Boolean;

    trigger OnRun()
    var
        Shop: Record "Shpfy Shop";
        Handled: Boolean;
    begin
        Shop.Get(ShopCode);
        if ImportPass then
            Shop."Can Update Shopify Customer" := false
        else
            Shop."Customer Import From Shopify" := Shop."Customer Import From Shopify"::None;
        OnBeforeRunConnector(Shop, ImportPass, Handled);
        if Handled then
            exit;
        // Shpfy Sync Customers (30123) has TableNo "Shpfy Shop" and imports and updates customers as the shop record says.
        if not Codeunit.Run(30123, Shop) then
            Error(GetLastErrorText());
    end;

    /// <summary>Sets the shop the customers are synchronized for and the pass to run.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    /// <param name="NewImportPass">True for the import pass (Shopify to Business Central), false for the update pass (Business Central to Shopify).</param>
    procedure SetShopCode(NewShopCode: Code[20]; NewImportPass: Boolean)
    begin
        ShopCode := NewShopCode;
        ImportPass := NewImportPass;
    end;

    /// <summary>
    /// Raised before the connector runs. Internal: only the test app subscribes, to stand in for the connector, which cannot
    /// reach Shopify from a test (its access token is kept in the connector's own isolated storage).
    /// </summary>
    /// <param name="Shop">The shop as the connector gets it for this pass.</param>
    /// <param name="IsImportPass">True for the import pass.</param>
    /// <param name="Handled">Set to true to skip the connector.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; IsImportPass: Boolean; var Handled: Boolean)
    begin
    end;
}
