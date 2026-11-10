namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using System.Reflection;

/// <summary>
/// Runs the Shopify connector report Shpfy Sync Stock to Shopify (30102), the code behind the action Sync Inventory,
/// for one shop. The connector commits as it goes, so the caller calls Execute directly (a Codeunit.Run is not possible
/// while the message pipeline holds an open write transaction); a failure is an error that the message pipeline turns into a refusal.
/// </summary>
codeunit 70013481 "Inventory Sync Run ori"
{
    Access = Internal;

    var
        ShopCode: Code[20];
        SkipImport: Boolean;
        VariantIdFilter: Text;

    /// <summary>Runs the report for the shop and options set with SetOptions.</summary>
    procedure Execute()
    begin
        Report.Execute(Report::"Shpfy Sync Stock to Shopify", BuildRequestXml());
    end;

    /// <summary>Sets the shop and the report options.</summary>
    /// <param name="NewShopCode">The Shopify shop code.</param>
    /// <param name="NewSkipImport">True to skip importing the stock from Shopify first.</param>
    /// <param name="NewVariantIdFilter">A Shopify variant Id filter, or empty for all variants.</param>
    procedure SetOptions(NewShopCode: Code[20]; NewSkipImport: Boolean; NewVariantIdFilter: Text)
    begin
        ShopCode := NewShopCode;
        SkipImport := NewSkipImport;
        VariantIdFilter := NewVariantIdFilter;
    end;

    local procedure BuildRequestXml(): Text
    var
        TypeHelper: Codeunit "Type Helper";
        Xml: TextBuilder;
        SkipText: Text;
        ShopCodeText: Text;
        FilterText: Text;
    begin
        FilterText := VariantIdFilter;
        ShopCodeText := ShopCode;
        if SkipImport then
            SkipText := 'true'
        else
            SkipText := 'false';
        Xml.Append('<?xml version="1.0" standalone="yes"?><ReportParameters name="Sync Stock To Shopify" id="30102"><Options>');
        Xml.Append('<Field name="SkipImport">' + SkipText + '</Field>');
        Xml.Append('<Field name="VariantIdFilter">' + TypeHelper.HtmlEncode(FilterText) + '</Field>');
        Xml.Append('</Options><DataItems><DataItem name="Shop">VERSION(1) SORTING(Field1) WHERE(Field1=1(' + TypeHelper.HtmlEncode(ShopCodeText) + '))</DataItem></DataItems></ReportParameters>');
        exit(Xml.ToText());
    end;
}
