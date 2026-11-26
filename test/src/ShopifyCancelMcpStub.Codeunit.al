namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Mock-only MCP seam restricted to the self-seeded XMCPCANCEL27 fixture and its two API-call IDs.</summary>
codeunit 97502 "Shopify Cancel MCP Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Order Cancel Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure Cancel(ForOrderId: BigInteger; ForShopCode: Code[20]; ForNotifyCustomer: Boolean; ForCancelReason: Enum "Shpfy Cancel Reason"; ForRefund: Boolean; ForRestock: Boolean; var Succeeded: Boolean; var IsHandled: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
    begin
        if ForShopCode <> 'XMCPCANCEL27' then
            exit;
        if not (ForOrderId in [975030027, 975030028]) then
            exit;
        OrderHeader.SetLoadFields("Shop Code");
        if not OrderHeader.Get(ForOrderId) then
            exit;
        if OrderHeader."Shop Code" <> 'XMCPCANCEL27' then
            exit;
        IsHandled := true;
        Succeeded := ForOrderId = 975030027;
    end;
}
