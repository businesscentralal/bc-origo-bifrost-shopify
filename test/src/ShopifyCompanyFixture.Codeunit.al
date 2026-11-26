namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Seeds and removes demo-only, token-free MCP company synchronization data.</summary>
codeunit 97516 "Shopify Company Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds enabled, disabled, failure and inactive-direction shops.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        ShopCode: Code[20];
        Codes: List of [Code[20]];
    begin
        RemoveAll();
        Codes.Add('XMCPC18');
        Codes.Add('XMCPC18FAIL');
        Codes.Add('XMCPC18OFF');
        Codes.Add('XMCPC18DISABLED');
        foreach ShopCode in Codes do begin
            Shop.Init();
            Shop.Code := ShopCode;
            Shop.Insert();
            Shop.Enabled := ShopCode <> 'XMCPC18DISABLED';
            Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
            Shop."Company Import From Shopify" := Shop."Company Import From Shopify"::None;
            if ShopCode <> 'XMCPC18OFF' then
                Shop."Company Import From Shopify" := Shop."Company Import From Shopify"::AllCompanies;
            Shop.Modify();
        end;
        Commit();
    end;

    /// <summary>Checks rollback and removes every fixture row.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Company: Record "Shpfy Company";
        Shop: Record "Shpfy Shop";
        Assert: Codeunit "Library Assert";
    begin
        Assert.IsFalse(Company.Get(975160019), 'Failed connector insert rolled back.');
        RemoveAll();
        Company.SetRange(Id, 975160018, 975160019);
        Assert.IsTrue(Company.IsEmpty(), 'All company fixture rows removed.');
        Shop.SetFilter(Code, 'XMCPC18|XMCPC18FAIL|XMCPC18OFF|XMCPC18DISABLED');
        Assert.IsTrue(Shop.IsEmpty(), 'All fixture shops removed.');
    end;

    local procedure RemoveAll()
    var
        Company: Record "Shpfy Company";
        Shop: Record "Shpfy Shop";
    begin
        Company.SetRange(Id, 975160018, 975160019);
        Company.DeleteAll();
        Shop.SetFilter(Code, 'XMCPC18|XMCPC18FAIL|XMCPC18OFF|XMCPC18DISABLED');
        Shop.DeleteAll();
        Commit();
    end;
}
