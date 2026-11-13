namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>
/// Runs the Shopify connector codeunit Shpfy Create Item (30171), the code behind the action Create Item on Shopify Products,
/// for every variant of one Shopify product that is not mapped to an item variant yet. The Shopify codeunit is internal, so it
/// is started by its ID, as the connector's own product import starts it. The caller starts this codeunit with Run in an if
/// statement, so a failure rolls back everything it created.
/// </summary>
codeunit 70013421 "Product CreateItem Run ori"
{
    Access = Internal;

    var
        ProductId: BigInteger;

    trigger OnRun()
    var
        Variant: Record "Shpfy Variant";
        NullGuid: Guid;
    begin
        Variant.SetRange("Product Id", ProductId);
        Variant.SetRange("Item Variant SystemId", NullGuid);
        if Variant.FindSet() then
            repeat
                // Shpfy Create Item (30171) has TableNo "Shpfy Variant" and takes the shop from the product.
                if not Codeunit.Run(30171, Variant) then
                    Error(GetLastErrorText());
            until Variant.Next() = 0;
    end;

    /// <summary>Sets the Shopify product the items are created for.</summary>
    /// <param name="NewProductId">The Shopify product ID.</param>
    procedure SetProductId(NewProductId: BigInteger)
    begin
        ProductId := NewProductId;
    end;
}
