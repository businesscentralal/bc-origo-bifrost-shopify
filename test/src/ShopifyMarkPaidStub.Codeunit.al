namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Replaces the connector only for issue 26 reserved CRONUS fixture rows.</summary>
codeunit 97531 "Shpfy MarkPaid Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Order MarkPaid Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure StandIn(OrderId: BigInteger; ShopCode: Code[20]; var IsHandled: Boolean; var FullyPaid: Boolean)
    var
        OrderHeader: Record "Shpfy Order Header";
    begin
        if not (ShopCode in ['X26ON', 'X26OFF', 'X26MISSING']) then
            exit;
        if (OrderId < 975300001) or (OrderId > 975300008) then
            Error('Unexpected fixture order; never contact Shopify.');
        if ShopCode <> 'X26ON' then
            Error('A refused fixture reached the connector.');
        IsHandled := true;
        FullyPaid := true;
        if OrderId in [975300002, 975300003] then begin
            OrderHeader.Get(OrderId);
            OrderHeader."Fully Paid" := true;
            OrderHeader.Modify();
            Commit(); // Must be ignored by the product runner: prove rollback across connector commits.
            FullyPaid := false;
            if OrderId = 975300003 then
                Error('Mock connector exception after a local write and explicit commit.');
        end;
    end;
}
