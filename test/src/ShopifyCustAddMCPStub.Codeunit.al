namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;

/// <summary>Automatic mock restricted to this story's token-free MCP fixture shops.</summary>
codeunit 97592 "Shopify CustAdd MCP Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Customer Add Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure RunConnector(Shop: Record "Shpfy Shop"; CustomerView: Text; var Handled: Boolean)
    var
        Customer: Record Customer;
        Stub: Codeunit "Shopify Customer Add Stub ori";
    begin
        if not (Shop.Code in ['XMCA17', 'XMCA17FAIL', 'XMCA17DIS', 'XMCA17NOID']) then
            exit;
        Customer.SetView(CustomerView);
        if not Customer.FindFirst() then
            Error('XFixture customer selection is empty');
        Handled := true;
        if Shop.Code = 'XMCA17FAIL' then
            Stub.ExportCustomer(Shop, Customer, 'XCA17-2', 'XCA17-3')
        else
            Stub.ExportCustomer(Shop, Customer, '', '');
    end;
}
