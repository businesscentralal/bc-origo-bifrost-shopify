namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Own-tenant mock fixtures; no access token or external Shopify call.</summary>
codeunit 97512 "Shpfy Metafield MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds isolated demo owners for MCP checks.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        Seed();
    end;

    /// <summary>Removes every reserved fixture row and verifies cleanup.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Assert: Codeunit "Library Assert";
        Metafield: Record "Shpfy Metafield";
    begin
        Cleanup();
        Metafield.SetRange("Owner Id", 8935000035L);
        Assert.IsTrue(Metafield.IsEmpty(), 'Fixture metafields removed.');
    end;

    /// <summary>Creates only reserved XMF35 demo records and commits before dispatch.</summary>
    procedure Seed()
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Customer: Record "Shpfy Customer";
        Company: Record "Shpfy Company";
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := 'XMF35';
        Shop.Enabled := true;
        Shop."Shop Id" := 893535;
        Shop.Insert(false);
        Product.Init();
        Product.Id := 8935000035L;
        Product."Shop Code" := Shop.Code;
        Product.Insert(false);
        Variant.Init();
        Variant.Id := Product.Id;
        Variant."Product Id" := Product.Id;
        Variant."Shop Code" := Shop.Code;
        Variant.Insert(false);
        Customer.Init();
        Customer.Id := Product.Id;
        Customer."Shop Id" := Shop."Shop Id";
        Customer.Insert(false);
        Company.Init();
        Company.Id := Product.Id;
        Company."Shop Id" := Shop."Shop Id";
        Company."Shop Code" := Shop.Code;
        Company.Insert(false);
        Commit();
    end;

    /// <summary>Removes only the reserved owner ID and XMF35 shop.</summary>
    procedure Cleanup()
    var
        Metafield: Record "Shpfy Metafield";
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Customer: Record "Shpfy Customer";
        Company: Record "Shpfy Company";
    begin
        Metafield.SetRange("Owner Id", 8935000035L);
        Metafield.DeleteAll(false);
        if Variant.Get(8935000035L) then
            Variant.Delete(false);
        if Product.Get(8935000035L) then
            Product.Delete(false);
        if Customer.Get(8935000035L) then
            Customer.Delete(false);
        if Company.Get(8935000035L) then
            Company.Delete(false);
        if Shop.Get('XMF35') then
            Shop.Delete(false);
        Commit();
    end;
}
