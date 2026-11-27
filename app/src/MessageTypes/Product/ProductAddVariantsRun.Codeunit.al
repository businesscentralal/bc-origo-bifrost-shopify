namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;

/// <summary>Runs report 30117 once for one item; Boolean Codeunit.Run supplies its rollback boundary.</summary>
codeunit 73732051 "Product AddVariants Run ori"
{
    Access = Internal;

    var
        ProductId: BigInteger;
        ItemNo: Code[20];
        VariantsAdded: Integer;
        AlreadyMappedErr: Label 'Item %1 is already a variant of product %2.', Comment = '%1 = item number, %2 = product ID||is-IS=Vara %1 er þegar afbrigði af vöru %2.';
        NoVariantErr: Label 'The connector did not add a variant for item %1 to product %2.', Comment = '%1 = item number, %2 = product ID||is-IS=Tengillinn bætti ekki afbrigði fyrir vöru %1 við vöru %2.';

    trigger OnRun()
    var
        Item: Record Item;
        Variant: Record "Shpfy Variant";
        MappedVariant: Record "Shpfy Variant";
        BeforeCount: Integer;
        Parameters: Text;
        Handled: Boolean;
    begin
        Item.SetLoadFields(SystemId);
        Item.Get(ItemNo);
        MappedVariant.SetRange("Product Id", ProductId);
        MappedVariant.SetRange("Item SystemId", Item.SystemId);
        if not MappedVariant.IsEmpty() then
            Error(AlreadyMappedErr, ItemNo, ProductId);
        Variant.SetRange("Product Id", ProductId);
        BeforeCount := Variant.Count();
        Item.SetRange("No.", ItemNo);
        Parameters := '<ReportParameters name="Shpfy Add Item As Variant" id="30117"><Options><Field name="Shop">' +
            '</Field><Field name="ParentItemNo">' + Format(ProductId, 0, 9) +
            '</Field></Options><DataItems><DataItem name="Item">' + EscapeXml(Item.GetView(false)) +
            '</DataItem></DataItems></ReportParameters>';
        OnBeforeRunConnector(ProductId, ItemNo, Parameters, Handled);
        if not Handled then
            Report.Execute(30117, Parameters);
        VariantsAdded := Variant.Count() - BeforeCount;
        // Report 30117 can return normally when an item cannot supply options. Do not claim success.
        if (VariantsAdded <= 0) or MappedVariant.IsEmpty() then
            Error(NoVariantErr, ItemNo, ProductId);
    end;

    /// <summary>Sets the product and exact item for the next report run.</summary>
    /// <param name="NewProductId">Existing Shopify product ID.</param>
    /// <param name="NewItemNo">One BC item number.</param>
    procedure SetItem(NewProductId: BigInteger; NewItemNo: Code[20])
    begin
        ProductId := NewProductId;
        ItemNo := NewItemNo;
    end;

    /// <summary>Returns the increase in product variant rows from the successful run.</summary>
    /// <returns>Number of variants added.</returns>
    procedure GetVariantsAdded(): Integer
    begin
        exit(VariantsAdded);
    end;

    /// <summary>Test seam before report execution; production always executes the connector.</summary>
    /// <param name="ParentProductId">Parent product ID sent to the report.</param>
    /// <param name="RequestedItemNo">Exact item sent to the report.</param>
    /// <param name="Parameters">Report request XML, including the exact item view.</param>
    /// <param name="Handled">Tests set this to true to stand in for the connector.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(ParentProductId: BigInteger; RequestedItemNo: Code[20]; Parameters: Text; var Handled: Boolean)
    begin
    end;

    local procedure EscapeXml(Value: Text): Text
    begin
        exit(Value.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;').Replace('''', '&apos;'));
    end;
}
