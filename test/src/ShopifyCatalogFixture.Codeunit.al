namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Seeds and removes reserved CRONUS records for mock-only catalog tests and MCP checks.</summary>
codeunit 97532 "Shpfy Catalog Fixture ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    /// <summary>Seeds the fixture for MCP checks.</summary>
    [Test]
    procedure A1SeedFixture()
    begin
        Seed();
    end;

    /// <summary>Removes the fixture and checks that nothing remains.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        Assert: Codeunit "Library Assert";
    begin
        Remove();
        Assert.IsFalse(Shop.Get('BIFT21'), 'Shop removed.');
        Catalog.SetRange("Shop Code", 'BIFT21');
        Assert.IsTrue(Catalog.IsEmpty(), 'Catalogs removed.');
    end;

    /// <summary>Seeds four isolated shop scenarios, without any connector credentials.</summary>
    procedure Seed()
    var
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
    begin
        Remove();
        Shop.Init();
        Shop.Code := 'BIFT21';
        Shop."Shop Id" := 2100001;
        Shop.Enabled := true;
        Shop.Insert();
        Shop.Code := 'BIFT21OFF';
        Shop.Enabled := false;
        Shop.Insert();
        Shop.Code := 'BIFT21FAIL';
        Shop.Enabled := true;
        Shop.Insert();
        Shop.Code := 'BIFT21COMMIT';
        Shop.Insert();
        Shop.Code := 'BIFT21&<|()';
        Shop.Insert();
        Shop.Code := 'BIFT21-1234567890123';
        Shop.Insert();
        Shop.Code := 'BIFT21OTHER';
        Shop."Shop Id" := 2100002;
        Shop.Insert();
        Company.Init();
        Company.Id := 2100099;
        Company."Shop Id" := 2100002;
        Company."Shop Code" := 'BIFT21OTHER';
        Company.Insert();
        Commit();
    end;

    /// <summary>Seeds a company of the primary shop.</summary>
    procedure AddCompany()
    var
        Company: Record "Shpfy Company";
    begin
        Company.Init();
        Company.Id := 2100001;
        Company."Shop Id" := 2100001;
        Company."Shop Code" := 'BIFT21';
        Company.Insert();
        Commit();
    end;

    /// <summary>Removes only reserved fixture records.</summary>
    procedure Remove()
    var
        Shop: Record "Shpfy Shop";
        Catalog: Record "Shpfy Catalog";
        Relation: Record "Shpfy Market Catalog Relation";
        Company: Record "Shpfy Company";
    begin
        Relation.SetFilter("Shop Code", 'BIFT21*');
        Relation.DeleteAll();
        Catalog.SetFilter("Shop Code", 'BIFT21*');
        Catalog.DeleteAll();
        Company.SetRange(Id, 2100001, 2100099);
        Company.SetFilter("Shop Code", 'BIFT21*');
        Company.DeleteAll();
        Shop.SetFilter(Code, 'BIFT21*');
        Shop.DeleteAll();
        Commit();
    end;
}
