namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Mock connector and self-contained demo fixtures for issue 22; never uses HTTP or credentials.</summary>
codeunit 97521 "Shpfy Catalog Prices Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        FailRun: Boolean;
        SeenParameters: Text;
        SeenCount: Integer;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Catalog SyncPrices Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure HandleConnector(ForShopCode: Code[20]; ForCatalogView: Text; ReportParameters: Text; var Handled: Boolean)
    begin
        SeenParameters := ReportParameters;
        SeenCount := RunMock(ForShopCode, ForCatalogView, ReportParameters, FailRun);
        Handled := true;
    end;

    /// <summary>Configures a connector failure after a log write to verify rollback.</summary>
    /// <param name="Fail">Whether the mock fails.</param>
    procedure SetFailure(Fail: Boolean)
    begin
        FailRun := Fail;
    end;

    /// <summary>Returns the XML passed to the connector.</summary>
    /// <returns>Report request XML.</returns>
    procedure GetParameters(): Text
    begin
        exit(SeenParameters);
    end;

    /// <summary>Returns the rows seen by the mock.</summary>
    /// <returns>Number of matching rows.</returns>
    procedure GetSeenCount(): Integer
    begin
        exit(SeenCount);
    end;

    /// <summary>Imitates selected catalog processing and currency skip logging.</summary>
    /// <param name="ShopCode">Fixture shop only.</param>
    /// <param name="CatalogView">Actual wrapper selection.</param>
    /// <param name="ReportParameters">Actual report XML.</param>
    /// <param name="Fail">Raise an error after writing a skipped row.</param>
    /// <returns>Selected catalog row count.</returns>
    procedure RunMock(ShopCode: Code[20]; CatalogView: Text; ReportParameters: Text; Fail: Boolean) Seen: Integer
    var
        Catalog: Record "Shpfy Catalog";
        Assert: Codeunit "Library Assert";
        Document: XmlDocument;
    begin
        Assert.IsTrue(ShopCode in ['XSC22-TEST', 'XSC22-MCP', 'XSC22&TEST'], 'Only self-seeded fixture shops.');
        Assert.IsTrue(XmlDocument.ReadFrom(ReportParameters, Document), 'Valid report XML, including escaped filters.');
        Assert.IsTrue(ReportParameters.Contains('id="30116"'), 'Expected connector report.');
        Catalog.SetView(CatalogView);
        Catalog.SetLoadFields(Id, "Company SystemId", "Shop Code", "Sync Prices", "Currency Code");
        if Catalog.FindSet() then
            repeat
                Assert.AreEqual(ShopCode, Catalog."Shop Code", 'The view must not widen the shop.');
                Assert.IsTrue(Catalog."Sync Prices", 'Only enabled price catalogs.');
                Seen += 1;
                if (Catalog."Currency Code" = 'XBAD') or Fail then
                    AddSkipped(Catalog);
                if Fail then
                    Error('XSC22 mock connector failure after log write');
            until Catalog.Next() = 0;
    end;

    /// <summary>Creates fixture shops, company, matching and excluded catalogs and a historical skipped row.</summary>
    /// <param name="ShopCode">Reserved fixture shop.</param>
    procedure Seed(ShopCode: Code[20])
    var
        Shop: Record "Shpfy Shop";
        CompanyRecord: Record "Shpfy Company";
        Catalog: Record "Shpfy Catalog";
        EmptyGuid: Guid;
    begin
        Cleanup();
        Shop.Init();
        Shop.Code := ShopCode;
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop.Insert();
        Shop.Code := 'XSC22-OTHER';
        Shop.Insert();
        CompanyRecord.Init();
        CompanyRecord.Id := 97520001;
        CompanyRecord."Shop Code" := ShopCode;
        CompanyRecord.Name := 'XSC22 demo company';
        CompanyRecord.Insert();
        SeedCatalog(ShopCode, 97520001, CompanyRecord.SystemId, Enum::"Shpfy Catalog Type"::Company, true, '');
        SeedCatalog(ShopCode, 97520002, EmptyGuid, Enum::"Shpfy Catalog Type"::Market, true, '');
        SeedCatalog(ShopCode, 97520003, EmptyGuid, Enum::"Shpfy Catalog Type"::Market, false, '');
        SeedCatalog(ShopCode, 97520004, CompanyRecord.SystemId, Enum::"Shpfy Catalog Type"::Company, true, 'XBAD');
        SeedCatalog('XSC22-OTHER', 97520005, EmptyGuid, Enum::"Shpfy Catalog Type"::Market, true, 'XBAD');
        Catalog.Get(97520001, CompanyRecord.SystemId);
        AddSkipped(Catalog);
        Commit();
    end;

    /// <summary>Removes only the self-seeded fixture and its skipped rows.</summary>
    procedure Cleanup()
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        CompanyRecord: Record "Shpfy Company";
        Skipped: RecordRef;
    begin
        Skipped.Open(30159);
        Skipped.Field(2).SetRange(97520001, 97520005);
        Skipped.Field(3).SetRange(Database::"Shpfy Catalog");
        Skipped.DeleteAll();
        Catalog.SetRange(Id, 97520001, 97520005);
        Catalog.DeleteAll();
        CompanyRecord.SetRange(Id, 97520001);
        CompanyRecord.DeleteAll();
        Shop.SetFilter(Code, '%1|%2|%3|%4', 'XSC22-TEST', 'XSC22-MCP', 'XSC22-OTHER', 'XSC22&TEST');
        Shop.DeleteAll();
        Commit();
    end;

    local procedure SeedCatalog(ShopCode: Code[20]; Id: BigInteger; CompanySystemId: Guid; CatalogType: Enum "Shpfy Catalog Type"; SyncPrices: Boolean; CurrencyCode: Code[10])
    var
        Catalog: Record "Shpfy Catalog";
    begin
        Catalog.Init();
        Catalog.Id := Id;
        Catalog."Company SystemId" := CompanySystemId;
        Catalog."Shop Code" := ShopCode;
        Catalog.Name := 'XSC22 demo catalog';
        Catalog."Catalog Type" := CatalogType;
        Catalog."Sync Prices" := SyncPrices;
        Catalog."Currency Code" := CurrencyCode;
        Catalog.Insert();
    end;

    local procedure AddSkipped(Catalog: Record "Shpfy Catalog")
    var
        Skipped: RecordRef;
    begin
        Skipped.Open(30159);
        Skipped.Init();
        Skipped.Field(2).Value := Catalog.Id;
        Skipped.Field(3).Value := Database::"Shpfy Catalog";
        Skipped.Field(5).Value := Catalog.RecordId();
        Skipped.Field(7).Value := 'XSC22 mock currency mismatch';
        Skipped.Insert();
    end;
}
