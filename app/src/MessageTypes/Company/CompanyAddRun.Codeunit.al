namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;

/// <summary>
/// Runs the Shopify connector report Shpfy Add Company to Shopify (30113), the code behind Add Company to Shopify,
/// for one shop and one customer, without its request page. The caller starts this codeunit with Run in an if statement,
/// so a failure rolls back what the report wrote after its last commit and the other customers can still be processed.
/// </summary>
codeunit 73732071 "Company Add Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        CustomerNo: Code[20];

    trigger OnRun()
    var
        Customer: Record Customer;
        Handled: Boolean;
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Add Company to Shopify" id="30113"><Options><Field name="ShopCode">%1</Field></Options><DataItems><DataItem name="Customer">%2</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        OnBeforeRunAddCompanyReport(ShopCode, CustomerNo, Handled);
        if Handled then
            exit;
        Customer.SetRange("No.", CustomerNo);
        Report.Execute(Report::"Shpfy Add Company to Shopify", StrSubstNo(ParametersTxt, XmlEscape(ShopCode), XmlEscape(Customer.GetView())));
    end;

    /// <summary>Sets the shop and the customer the report runs for.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    /// <param name="NewCustomerNo">The Business Central customer number.</param>
    procedure SetParameters(NewShopCode: Code[20]; NewCustomerNo: Code[20])
    begin
        ShopCode := NewShopCode;
        CustomerNo := NewCustomerNo;
    end;

    /// <summary>Escapes a value for an XML text node.</summary>
    /// <param name="Value">The text to escape.</param>
    /// <returns>The escaped text.</returns>
    local procedure XmlEscape(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;'));
    end;

    /// <summary>
    /// Raised before the connector report runs. Internal: only the test app subscribes, to stand in for the connector,
    /// which cannot reach Shopify from a test.
    /// </summary>
    /// <param name="ForShopCode">The Shopify shop code.</param>
    /// <param name="ForCustomerNo">The Business Central customer number.</param>
    /// <param name="Handled">Set to true to skip the report.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunAddCompanyReport(ForShopCode: Code[20]; ForCustomerNo: Code[20]; var Handled: Boolean)
    begin
    end;
}
