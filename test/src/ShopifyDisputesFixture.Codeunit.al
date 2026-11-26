namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Creates and removes issue 33 demo data for AL and MCP tests.</summary>
codeunit 97519 "Shopify Disputes Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds mock-only MCP shops and an open dispute.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Stub: Codeunit "Shopify Disputes Stub ori";
    begin
        // Story #33, AC06 | Time: none | Risk: None
        Cleanup();
        SeedShop('X33-OK', true);
        SeedShop('X33-NONE', true);
        SeedShop('X33-FAIL', true);
        SeedShop('X33-DISABLED', false);
        Stub.InsertDispute(975170001, 'X33-OK', 1);
        Stub.InsertDispute(975170004, 'X33-FAIL', 1);
        Commit();
    end;

    /// <summary>Removes all issue 33 rows and verifies their removal.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Assert: Codeunit "Library Assert";
    begin
        // Story #33, AC06 | Time: none | Risk: None
        Cleanup();
        Shop.SetFilter(Code, 'X33-*');
        Assert.IsTrue(Shop.IsEmpty(), 'Issue 33 fixture shops removed.');
    end;

    /// <summary>Seeds an enabled or disabled shop without credentials.</summary>
    /// <param name="ShopCode">An issue 33 fixture code.</param>
    /// <param name="IsEnabled">Whether the shop is enabled.</param>
    procedure SeedShop(ShopCode: Code[20]; IsEnabled: Boolean)
    var
        Shop: Record "Shpfy Shop";
    begin
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Enabled := IsEnabled;
        Shop.Insert();
        Commit();
    end;

    /// <summary>Removes only issue 33 fixture records.</summary>
    procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Dispute: RecordRef;
        LogEntry: RecordRef;
        FieldValue: FieldRef;
    begin
        Dispute.Open(30155);
        FieldValue := Dispute.Field(101);
        FieldValue.SetFilter('X33-*');
        Dispute.DeleteAll();
        Dispute.Close();
        LogEntry.Open(30115);
        FieldValue := LogEntry.Field(9);
        FieldValue.SetRange('X33 rollback log');
        LogEntry.DeleteAll();
        LogEntry.Close();
        Shop.SetFilter(Code, 'X33-*');
        Shop.DeleteAll();
        Commit();
    end;
}
