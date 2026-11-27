namespace Origo.Bifrost.Shopify;

using Microsoft.Sales.History;

/// <summary>Runs report 30119 for one invoice inside the caller's conditional Codeunit.Run transaction.</summary>
codeunit 73731956 "Invoice Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        InvoiceNo: Code[20];

    trigger OnRun()
    var
        Invoice: Record "Sales Invoice Header";
        Handled: Boolean;
    begin
        Invoice.Get(InvoiceNo);
        // Recheck immediately before the connector; never reset or retry a nonzero ID.
        if Invoice."Shpfy Order Id" <> 0 then
            exit;
        OnBeforeRunConnector(ShopCode, Invoice, Handled);
        if Handled then
            exit;
        Report.Execute(30119, BuildRequestXml());
    end;

    /// <summary>Selects the shop and posted invoice for the next run.</summary>
    /// <param name="NewShopCode">Shop code.</param>
    /// <param name="NewInvoiceNo">Posted invoice number.</param>
    procedure SetInvoice(NewShopCode: Code[20]; NewInvoiceNo: Code[20])
    begin
        ShopCode := NewShopCode;
        InvoiceNo := NewInvoiceNo;
    end;

    /// <summary>Builds report parameters without accepting caller-supplied filters.</summary>
    /// <returns>XML with the shop request field and one exact invoice filter.</returns>
    internal procedure BuildRequestXml(): Text
    var
        Invoice: Record "Sales Invoice Header";
    begin
        Invoice.SetRange("No.", InvoiceNo);
        exit('<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Invoices to Shpfy" id="30119"><Options><Field name="Shop">' +
            EscapeXml(ShopCode) + '</Field></Options><DataItems><DataItem name="SalesInvoiceHeader">' + EscapeXml(Invoice.GetView(false)) +
            '</DataItem></DataItems></ReportParameters>');
    end;

    local procedure EscapeXml(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace('''', '&apos;'));
    end;

    /// <summary>Allows the test app to replace all connector work without credentials or network calls.</summary>
    /// <param name="SelectedShopCode">Shop selected for the export.</param>
    /// <param name="Invoice">The selected invoice.</param>
    /// <param name="Handled">Set true to replace report execution.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(SelectedShopCode: Code[20]; Invoice: Record "Sales Invoice Header"; var Handled: Boolean)
    begin
    end;
}
