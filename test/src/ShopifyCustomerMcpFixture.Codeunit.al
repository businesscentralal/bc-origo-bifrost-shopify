namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #16: self-seeded fixture for MCP checks of Shopify.Customer.Sync. A1SeedFixture commits shop MCP16ON (enabled, no import,
/// no update), shop MCP16OFF (disabled) and shop MCP16BAD (enabled, imports all customers, no Shopify connection).
/// A2RemoveFixture removes everything again.
/// </summary>
codeunit 97451 "Shpfy Customer MCP Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds the three shops.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        RemoveAll();
        SeedShop('MCP16ON', true, "Shpfy Customer Import Range"::None);
        SeedShop('MCP16OFF', false, "Shpfy Customer Import Range"::None);
        SeedShop('MCP16BAD', true, "Shpfy Customer Import Range"::AllCustomers);
        Commit();
        Assert.IsTrue(true, 'Fixture seeded.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get('MCP16ON') or Shop.Get('MCP16OFF') or Shop.Get('MCP16BAD'), 'Fixture removed.');
    end;

    local procedure SeedShop(ShopCode: Code[20]; Enabled: Boolean; ImportRange: Enum "Shpfy Customer Import Range")
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Insert();
        Shop.Enabled := Enabled;
        Shop."Customer Import From Shopify" := ImportRange;
        Shop.Modify();
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.SetFilter(Code, 'MCP16ON|MCP16OFF|MCP16BAD');
        if Shop.FindSet() then
            repeat
                Shop.Enabled := false;
                Shop.Modify();
            until Shop.Next() = 0;
        Shop.DeleteAll(true);
        Commit();
    end;
}
