namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;

/// <summary>
/// Runs the Shopify connector report Shpfy Sync Shipm. to Shopify (30109), the code behind the task Sync Shipments To Shopify,
/// for one posted sales shipment. The caller starts this codeunit with Run in an if statement, so a failure rolls back
/// everything it changed, including the skip markers the Shopify report writes on the shipment.
/// </summary>
codeunit 70013431 "Fulfillment Sync Run ori"
{
    Access = Internal;

    var
        ShipmentNo: Code[20];
        NoFulfillmentErr: Label 'Shopify did not create a fulfillment for shipment %1. The Shopify skipped-record log holds the reason.', Comment = '%1 = Shipment No.||is-IS=Shopify bjó ekki til afgreiðslu fyrir vöruafhendingu %1. Ástæðan er í skráningu Shopify á sleppt færslum.';

    trigger OnRun()
    var
        SalesShipmentHeader: Record "Sales Shipment Header";
        SyncReport: Report "Shpfy Sync Shipm. to Shopify";
    begin
        SalesShipmentHeader.SetRange("No.", ShipmentNo);
        SyncReport.SetTableView(SalesShipmentHeader);
        SyncReport.UseRequestPage(false);
        SyncReport.RunModal();
        SalesShipmentHeader.Get(ShipmentNo);
        if SalesShipmentHeader."Shpfy Fulfillment Id" <= 0 then
            Error(NoFulfillmentErr, ShipmentNo);
    end;

    /// <summary>Sets the posted sales shipment that is synced.</summary>
    /// <param name="NewShipmentNo">The posted sales shipment No.</param>
    procedure SetShipmentNo(NewShipmentNo: Code[20])
    begin
        ShipmentNo := NewShipmentNo;
    end;
}
