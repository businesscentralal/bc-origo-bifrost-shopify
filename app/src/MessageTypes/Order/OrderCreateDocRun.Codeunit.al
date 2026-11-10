namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the standard report 30103 Shpfy Create Sales Orders for one imported Shopify order. The caller starts this
/// codeunit with Run in an if statement, so an error that the Shopify code raises outside its own error handling is
/// returned to the caller instead of ending the message unhandled.
/// </summary>
codeunit 70013471 "Order CreateDoc Run ori"
{
    Access = Internal;
    TableNo = "Shpfy Order Header";

    trigger OnRun()
    var
        Shop: Record "Shpfy Shop";
        OrderFilter: Record "Shpfy Order Header";
        CreateSalesOrders: Report "Shpfy Create Sales Orders";
    begin
        Shop.SetRange(Code, Rec."Shop Code");
        OrderFilter.SetRange("Shopify Order Id", Rec."Shopify Order Id");
        CreateSalesOrders.SetTableView(Shop);
        CreateSalesOrders.SetTableView(OrderFilter);
        CreateSalesOrders.UseRequestPage(false);
        CreateSalesOrders.RunModal();
    end;
}
