namespace Origo.Bifrost.Shopify.Test;

using Origo.Bifrost.Shopify;

/// <summary>Enables the mock connector only for the dedicated, self-seeded MCP shop while this test app is installed.</summary>
codeunit 97523 "Shpfy Catalog MCP Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Catalog SyncPrices Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure HandleConnector(ForShopCode: Code[20]; ForCatalogView: Text; ReportParameters: Text; var Handled: Boolean)
    var
        Stub: Codeunit "Shpfy Catalog Prices Stub ori";
    begin
        if ForShopCode <> 'XSC22-MCP' then
            exit;
        Stub.RunMock(ForShopCode, ForCatalogView, ReportParameters, false);
        Handled := true;
    end;
}
