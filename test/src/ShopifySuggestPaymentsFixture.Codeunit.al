namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Finance.GeneralLedger.Journal;
using Microsoft.Integration.Shopify;
using Microsoft.Sales.Receivables;
using System.TestLibraries.Utilities;

/// <summary>Own-tenant CRONUS fixture for issue #34 and bilingual MCP checks; no provider credentials.</summary>
codeunit 97512 "Shpfy Suggest Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds only the reserved BIFT34 records for mock connector checks.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        Seed();
    end;

    /// <summary>Removes all fixture data and asserts that nothing remains.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Lines: Record "Gen. Journal Line";
        Assert: Codeunit "Library Assert";
    begin
        Remove();
        Assert.IsFalse(Shop.Get('BIFT34'), 'Fixture shop removed.');
        Lines.SetRange("Journal Template Name", 'BIFT34');
        Assert.IsTrue(Lines.IsEmpty(), 'Fixture lines removed.');
    end;

    /// <summary>Seeds two default transactions, one alternate gateway, one used transaction, and invalid-status/type rows.</summary>
    procedure Seed()
    var
        JnlTemplate: Record "Gen. Journal Template";
        Batch: Record "Gen. Journal Batch";
        Shop: Record "Shpfy Shop";
        Ledger: Record "Cust. Ledger Entry";
        Line: Record "Gen. Journal Line";
    begin
        Remove();
        JnlTemplate.Init();
        JnlTemplate.Name := 'BIFT34';
        JnlTemplate.Type := JnlTemplate.Type::"Cash Receipts";
        JnlTemplate."Page ID" := 255;
        JnlTemplate.Insert();
        JnlTemplate.Name := 'BIFT34BAD';
        JnlTemplate.Type := JnlTemplate.Type::General;
        JnlTemplate.Insert();
        Batch.Init();
        Batch."Journal Template Name" := 'BIFT34';
        Batch.Name := 'DEFAULT';
        Batch.Insert();
        Shop.Init();
        Shop.Code := 'BIFT34';
        Shop.Enabled := true;
        Shop.Insert();
        Shop.Code := 'BIFT34OFF';
        Shop.Enabled := false;
        Shop.Insert();
        InsertTransaction(3400001, 'CARD', CreateDateTime(20261125D, 120000T));
        InsertTransaction(3400002, 'CARD', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400003, 'OTHER', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400004, 'CARD', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400005, 'FAIL', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400006, 'COMMIT', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400008, 'CARD', CreateDateTime(20261126D, 120000T));
        InsertTransaction(3400009, 'CARD', CreateDateTime(20261126D, 120000T));
        Ledger.Init();
        Ledger."Entry No." := 3400004;
        Ledger."Shpfy Transaction Id" := 3400004;
        Ledger.Insert();
        Line.Init();
        Line."Journal Template Name" := 'BIFT34';
        Line."Journal Batch Name" := 'DEFAULT';
        Line."Line No." := 10000;
        Line.Description := 'Existing line remains unchanged';
        Line.Amount := 17;
        Line.Insert();
        Commit();
    end;

    /// <summary>Removes only records carrying this fixture's reserved identity.</summary>
    procedure Remove()
    var
        JnlTemplate: Record "Gen. Journal Template";
        Batch: Record "Gen. Journal Batch";
        Shop: Record "Shpfy Shop";
        Transactions: Record "Shpfy Order Transaction";
        Ledger: Record "Cust. Ledger Entry";
        Lines: Record "Gen. Journal Line";
    begin
        Lines.SetRange("Journal Template Name", 'BIFT34');
        Lines.DeleteAll();
        Batch.SetRange("Journal Template Name", 'BIFT34');
        Batch.DeleteAll();
        if JnlTemplate.Get('BIFT34') then
            JnlTemplate.Delete();
        if JnlTemplate.Get('BIFT34BAD') then
            JnlTemplate.Delete();
        Transactions.SetRange(Shop, 'BIFT34');
        Transactions.SetRange("Shopify Transaction Id", 3400001, 3400099);
        Transactions.DeleteAll();
        if Ledger.Get(3400004) then
            if Ledger."Shpfy Transaction Id" = 3400004 then
                Ledger.Delete();
        if Shop.Get('BIFT34') then
            Shop.Delete();
        if Shop.Get('BIFT34OFF') then
            Shop.Delete();
        Commit();
    end;

    local procedure InsertTransaction(Id: BigInteger; Gateway: Text[30]; CreatedAt: DateTime)
    var
        Transaction: Record "Shpfy Order Transaction";
    begin
        Transaction.Init();
        Transaction."Shopify Transaction Id" := Id;
        Transaction.Shop := 'BIFT34';
        Transaction."Shopify Order Id" := 3400000;
        Transaction.Type := Transaction.Type::Capture;
        Transaction.Status := Transaction.Status::Success;
        Transaction.Gateway := Gateway;
        Transaction."Created At" := CreatedAt;
        case Id of
            3400002:
                Transaction.Type := Transaction.Type::Sale;
            3400003, 3400004:
                Transaction.Type := Transaction.Type::Refund;
            3400008:
                Transaction.Status := Transaction.Status::Failure;
            3400009:
                Transaction.Type := Transaction.Type::Authorization;
        end;
        Transaction.Amount := 25;
        Transaction.Insert();
    end;
}
