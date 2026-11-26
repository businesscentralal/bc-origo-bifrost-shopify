namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Isolates the public Orders API and its success marker in one local transaction.</summary>
codeunit 73732091 "Order MarkPaid Run ori"
{
    Access = Internal;
    TableNo = "Shpfy Order Header";

    trigger OnRun()
    begin
        RunConnector(Rec);
    end;

    // The connector commits its request log before returning fullyPaid. Ignore that explicit
    // commit so a false return or exception rolls back all local writes of this runner.
    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector(var OrderHeader: Record "Shpfy Order Header")
    var
        Shop: Record "Shpfy Shop";
        PaidMarker: Record "Order Paid Marker ori";
        Orders: Codeunit "Shpfy Orders";
        IsHandled: Boolean;
        FullyPaid: Boolean;
        RefusedErr: Label 'Shopify did not confirm the order as paid. Check Shopify log entries (table 30115) for details.', Comment = 'is-IS=Shopify staðfesti ekki að pöntunin væri greidd. Skoðaðu Shopify annálsfærslur (töflu 30115) fyrir nánari upplýsingar.';
        ChangedErr: Label 'The order or shop changed. Refresh the order before trying again.', Comment = 'is-IS=Pöntunin eða verslunin breyttist. Uppfærðu pöntunina áður en þú reynir aftur.';
    begin
        // Serialize requests for the same imported row, including the duplicate-marker check.
        OrderHeader.LockTable();
        OrderHeader.Get(OrderHeader."Shopify Order Id");
        Shop.SetLoadFields(Enabled);
        if not Shop.Get(OrderHeader."Shop Code") then
            Error(ChangedErr);
        if not Shop.Enabled or OrderHeader."Fully Paid" then
            Error(ChangedErr);
        if PaidMarker.Get(OrderHeader."Shop Code", OrderHeader."Shopify Order Id") then
            Error(ChangedErr);
        OnBeforeRunConnector(OrderHeader."Shopify Order Id", OrderHeader."Shop Code", IsHandled, FullyPaid);
        if not IsHandled then
            FullyPaid := Orders.MarkAsPaid(OrderHeader."Shopify Order Id", OrderHeader."Shop Code");
        if not FullyPaid then
            Error(RefusedErr);
        PaidMarker.Init();
        PaidMarker."Shop Code" := OrderHeader."Shop Code";
        PaidMarker."Order Id" := OrderHeader."Shopify Order Id";
        PaidMarker.Insert();
    end;

    /// <summary>Allows tests to replace the outbound connector call without credentials.</summary>
    /// <param name="OrderId">Imported Shopify order identifier.</param>
    /// <param name="ShopCode">Shop derived from that order.</param>
    /// <param name="IsHandled">Set to true to replace the public API.</param>
    /// <param name="FullyPaid">The replacement API result.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(OrderId: BigInteger; ShopCode: Code[20]; var IsHandled: Boolean; var FullyPaid: Boolean)
    begin
    end;
}
