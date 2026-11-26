namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.History;
using System.TestLibraries.Utilities;

/// <summary>Issue #31: self-seeded, already-exported invoice for safe MCP idempotency checks; no external calls.</summary>
codeunit 97505 "Shpfy Invoice MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    /// <summary>Seeds an enabled shop, primary payment mapping and an already-exported invoice.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        Invoice: Record "Sales Invoice Header";
        Terms: RecordRef;
        Field: FieldRef;
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := 'MCP31';
        Shop.Enabled := true;
        Shop."Posted Invoice Sync" := true;
        Shop.Insert();
        Invoice.Init();
        Invoice."No." := 'MCP31-EXPORTED';
        Invoice."Shpfy Order Id" := 31001;
        Invoice.Insert();
        Terms.Open(30158);
        Terms.Init();
        Field := Terms.Field(1);
        Field.Value := 'MCP31';
        Field := Terms.Field(2);
        Field.Value := 31001;
        Field := Terms.Field(60);
        Field.Value := true;
        Terms.Insert();
        Terms.Close();
        Commit();
        Assert.IsTrue(Invoice.Get('MCP31-EXPORTED'), 'MCP invoice seeded.');
    end;

    /// <summary>Removes and verifies removal of every fixture record.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Invoice: Record "Sales Invoice Header";
        Shop: Record "Shpfy Shop";
    begin
        RemoveAll();
        Assert.IsFalse(Invoice.Get('MCP31-EXPORTED'), 'MCP invoice removed.');
        Assert.IsFalse(Shop.Get('MCP31'), 'MCP shop removed.');
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        Invoice: Record "Sales Invoice Header";
        Terms: RecordRef;
        Field: FieldRef;
    begin
        Terms.Open(30158);
        Field := Terms.Field(1);
        Field.SetRange('MCP31');
        Terms.DeleteAll();
        Terms.Close();
        Invoice.SetRange("No.", 'MCP31-EXPORTED');
        Invoice.DeleteAll();
        Shop.SetRange(Code, 'MCP31');
        Shop.DeleteAll();
        Commit();
    end;
}
