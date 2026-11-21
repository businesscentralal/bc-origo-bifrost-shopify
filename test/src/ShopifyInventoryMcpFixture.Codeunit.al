namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #14: self-seeded fixture for MCP checks of Shopify.Inventory.Sync. A1SeedFixture commits an enabled shop MCP14
/// and a disabled shop MCP14-OFF, both without variants; A2RemoveFixture deletes them again.
/// </summary>
codeunit 97481 "Shpfy Invent MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the enabled shop MCP14 and the disabled shop MCP14-OFF.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := 'MCP14';
        Shop.Enabled := true;
        Shop.Insert();
        Shop.Init();
        Shop.Code := 'MCP14-OFF';
        Shop.Enabled := false;
        Shop.Insert();
        Commit();
        Assert.IsTrue(Shop.Get('MCP14'), 'Fixture shop exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP14'), 'Fixture shop is removed.');
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.SetFilter(Code, 'MCP14*');
        Shop.DeleteAll(true);
        Commit();
    end;
}
