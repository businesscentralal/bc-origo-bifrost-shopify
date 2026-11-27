namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Creates and removes issue 32 demo data for AL and MCP tests.</summary>
codeunit 97552 "Shpfy Pay Sync MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds mock-only MCP shops and one open payout.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Stub: Codeunit "Shpfy Pay Sync Stub ori";
    begin
        // Story #32, AC06 | Time: none | Risk: None
        Cleanup();
        SeedShop('X32-OK', true);
        SeedShop('X32-NONE', true);
        SeedShop('X32-FAIL', true);
        SeedShop('X32-DISABLED', false);
        Stub.InsertPayout(975320001, 'X32-OK', 1);
        Stub.InsertTransaction(975320011, 'X32-OK', 975320001);
        Stub.InsertPayout(975320004, 'X32-FAIL', 1);
        Stub.InsertTransaction(975320014, 'X32-FAIL', 975320004);
        Commit();
    end;

    /// <summary>Removes all issue 32 rows and verifies their removal.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Assert: Codeunit "Library Assert";
    begin
        // Story #32, AC06 | Time: none | Risk: None
        Cleanup();
        Shop.SetFilter(Code, 'X32-*');
        Assert.IsTrue(Shop.IsEmpty(), 'Issue 32 fixture shops removed.');
    end;

    /// <summary>Seeds an enabled or disabled shop without credentials.</summary>
    /// <param name="ShopCode">An issue 32 fixture code.</param>
    /// <param name="IsEnabled">Whether the shop is enabled.</param>
    procedure SeedShop(ShopCode: Code[20]; IsEnabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        if Shop.Get(ShopCode) then
            Shop.Delete();
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Enabled := IsEnabled;
        Shop.Insert();
        Commit();
    end;

    /// <summary>Removes only issue 32 fixture records.</summary>
    procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Payout: Record "Shpfy Payout";
        PaymentTransaction: Record "Shpfy Payment Transaction";
        LogEntry: RecordRef;
        FieldValue: FieldRef;
    begin
        Shop.SetFilter(Code, 'X32-*');
        if Shop.FindSet() then
            repeat
                PaymentTransaction.SetRange("Shop Code", Shop.Code);
                PaymentTransaction.DeleteAll();
                Payout.SetRange("Shop Code", Shop.Code);
                Payout.DeleteAll();
            until Shop.Next() = 0;
        LogEntry.Open(30115);
        FieldValue := LogEntry.Field(9);
        FieldValue.SetRange('X32 rollback log');
        LogEntry.DeleteAll();
        LogEntry.Close();
        Shop.DeleteAll();
        Commit();
    end;
}
