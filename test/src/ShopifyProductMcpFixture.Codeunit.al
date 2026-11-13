namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #8: self-seeded fixture for MCP checks of Shopify.Product.CreateItem. A1SeedFixture commits item template MCP8,
/// enabled shop MCP8ON with it, shop MCP8NT without a template, disabled shop MCP8OFF and one product each
/// (ids 8810000001, 8810000011, 8810000021; variants SKU MCP8-ITEM, MCP8-NT, MCP8-OFF). A2RemoveFixture removes
/// everything again, including the item MCP8-ITEM that a successful call creates.
/// </summary>
codeunit 97421 "Shpfy Product MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TemplateTok: Label 'MCP8', Locked = true;

    /// <summary>Seeds the template, three shops and their products with one variant each.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Source: Record "Item Templ.";
        Template: Record "Item Templ.";
    begin
        RemoveAll();
        Source.SetRange(Type, Source.Type::Inventory);
        Source.FindFirst();
        Template := Source;
        Template.Code := CopyStr(TemplateTok, 1, MaxStrLen(Template.Code));
        Template."No. Series" := '';
        Template.Insert();
        SeedProduct('MCP8ON', true, TemplateTok, 8810000001L, 'MCP8-ITEM');
        SeedProduct('MCP8NT', true, '', 8810000011L, 'MCP8-NT');
        SeedProduct('MCP8OFF', false, TemplateTok, 8810000021L, 'MCP8-OFF');
        Commit();
        Assert.IsTrue(true, 'Fixture seeded.');
    end;

    /// <summary>Removes everything A1SeedFixture created and the items the MCP calls created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP8ON') or Shop.Get('MCP8NT') or Shop.Get('MCP8OFF'), 'Fixture removed.');
    end;

    local procedure SeedProduct(ShopCode: Code[20]; Enabled: Boolean; TemplateCode: Code[20]; ProductId: BigInteger; Sku: Text[50])
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop."SKU Mapping" := Shop."SKU Mapping"::"Item No.";
        Shop."Item Templ. Code" := TemplateCode;
        Shop.Modify();
        Product.Init();
        Product.Id := ProductId;
        Product."Shop Code" := ShopCode;
        Product.Title := 'MCP8 product ' + ShopCode;
        Product.Insert();
        Variant.Init();
        Variant.Id := ProductId + 1;
        Variant."Product Id" := ProductId;
        Variant.SKU := Sku;
        Variant.Price := 10;
        Variant.Insert();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Item: Record Item;
        Template: Record "Item Templ.";
    begin
        Variant.SetFilter("Product Id", '8810000001|8810000011|8810000021');
        Variant.DeleteAll();
        Product.SetFilter(Id, '8810000001|8810000011|8810000021');
        Product.DeleteAll();
        Item.SetFilter("No.", 'MCP8-*');
        Item.DeleteAll(true);
        Shop.SetFilter(Code, 'MCP8ON|MCP8NT|MCP8OFF');
        if Shop.FindSet() then
            repeat
                Shop.Enabled := false;
                Shop.Modify();
            until Shop.Next() = 0;
        Shop.DeleteAll(true);
        if Template.Get(TemplateTok) then
            Template.Delete();
        Commit();
    end;
}
