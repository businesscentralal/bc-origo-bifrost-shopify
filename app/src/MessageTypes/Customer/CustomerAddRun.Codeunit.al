namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;

/// <summary>Runs report 30112 for exactly one customer; the outer Boolean Run isolates local failures.</summary>
codeunit 73732141 "Customer Add Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        CustomerNo: Code[20];

    trigger OnRun()
    begin
        RunConnector();
    end;

    /// <summary>Selects one customer and its destination shop.</summary>
    /// <param name="NewShopCode">Enabled shop.</param>
    /// <param name="NewCustomerNo">Existing customer number.</param>
    procedure SetParameters(NewShopCode: Code[20]; NewCustomerNo: Code[20])
    begin
        ShopCode := NewShopCode;
        CustomerNo := NewCustomerNo;
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunConnector()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        ShopifyCustomer: Record "Shpfy Customer";
        SkippedRecord: RecordRef;
        SkippedReason: Text;
        LastEntryNo: Integer;
        Handled: Boolean;
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Add Customer to Shopify" id="30112"><Options><Field name="Shop">%1</Field></Options><DataItems><DataItem name="Customer">%2</DataItem></DataItems></ReportParameters>', Locked = true;
        NoLinkErr: Label 'The Shopify connector did not create a customer link. Review Shopify Skipped Records and the shop logging settings before retrying.', Comment = 'is-IS=Shopify tengillinn stofnaði ekki tengingu viðskiptamanns. Skoðaðu Shopify færslur sem var sleppt og skráningarstillingar verslunarinnar áður en reynt er aftur.';
    begin
        Shop.SetLoadFields(Code, "Shop Id");
        Shop.Get(ShopCode);
        Customer.SetLoadFields("No.", SystemId);
        Customer.Get(CustomerNo);
        // Table 30159 is internal in Connector 28. Read diagnostics through the platform record API.
        SkippedRecord.Open(30159);
        SkippedRecord.SetLoadFields(1);
        if SkippedRecord.FindLast() then
            LastEntryNo := SkippedRecord.Field(1).Value;
        Customer.SetRange("No.", CustomerNo);
        OnBeforeRunConnector(Shop, Customer, Handled);
        if not Handled then
            Report.Execute(30112, StrSubstNo(ParametersTxt, XmlEscape(Shop.Code), XmlEscape(Customer.GetView(false))));
        ShopifyCustomer.SetLoadFields(Id);
        ShopifyCustomer.SetRange("Shop Id", Shop."Shop Id");
        ShopifyCustomer.SetRange("Customer SystemId", Customer.SystemId);
        if ShopifyCustomer.FindFirst() then
            if ShopifyCustomer.Id > 0 then
                exit;
        // The connector can log and return without throwing. Refuse inside the rollback boundary.
        SkippedRecord.Reset();
        SkippedRecord.SetLoadFields(7);
        SkippedRecord.Field(1).SetFilter('>%1', LastEntryNo);
        SkippedRecord.Field(5).SetRange(Customer.RecordId());
        if SkippedRecord.FindLast() then begin
            SkippedReason := SkippedRecord.Field(7).Value;
            if SkippedReason <> '' then
                Error(SkippedReason);
        end;
        if GetLastErrorText() <> '' then
            Error(GetLastErrorText());
        Error(NoLinkErr);
    end;

    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
    end;

    /// <summary>Lets the test app replace the report without a token or provider call.</summary>
    /// <param name="Shop">Destination shop, unchanged.</param>
    /// <param name="Customer">Customer with an exact-number filter for the report.</param>
    /// <param name="Handled">Set true to replace the report.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(Shop: Record "Shpfy Shop"; Customer: Record Customer; var Handled: Boolean)
    begin
    end;
}
