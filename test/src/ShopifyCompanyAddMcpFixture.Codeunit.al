namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>
/// Issue #19: self-seeded fixture for MCP checks of Shopify.Company.Add. A1SeedFixture commits the enabled shop MCP19
/// and the customer MCP19-A. A2RemoveFixture deletes them and any company stored for them. MCP calls stay on the refusal
/// path so they do not reach Shopify.
/// </summary>
codeunit 97515 "Shpfy Company Add MCP ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        ShopCodeTok: Label 'MCP19', Locked = true;
        CustomerTok: Label 'MCP19-A', Locked = true;

    /// <summary>Seeds the enabled shop MCP19 and the customer MCP19-A.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := ShopCodeTok;
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop."Shop Id" := 19019;
        Shop.Modify();
        Customer.Init();
        Customer."No." := CustomerTok;
        Customer.Name := 'Bifrost MCP company customer';
        Customer."E-Mail" := 'mcp19@example.com';
        Customer.Insert();
        Commit();
        Assert.IsTrue(Shop.Get(ShopCodeTok), 'Fixture shop exists.');
        Assert.IsTrue(Customer.Get(CustomerTok), 'Fixture customer exists.');
    end;

    /// <summary>Removes everything A1SeedFixture created.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
    begin
        RemoveAll();
        Assert.IsFalse(Shop.Get(ShopCodeTok), 'Fixture shop is removed.');
        Assert.IsFalse(Customer.Get(CustomerTok), 'Fixture customer is removed.');
    end;

    local procedure RemoveAll()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        Company: Record "Shpfy Company";
        ShopifyCustomer: Record "Shpfy Customer";
        Skipped: RecordRef;
        RecordIdField: FieldRef;
    begin
        if Customer.Get(CustomerTok) then begin
            Skipped.Open(30159);
            RecordIdField := Skipped.Field(5);
            RecordIdField.SetRange(Customer.RecordId);
            Skipped.DeleteAll();
            Skipped.Close();
            Company.SetRange("Customer SystemId", Customer.SystemId);
            Company.DeleteAll(true);
            Customer.Delete(true);
        end;
        Company.SetRange("Shop Code", ShopCodeTok);
        Company.DeleteAll(true);
        ShopifyCustomer.SetRange("Shop Id", 19019);
        ShopifyCustomer.DeleteAll();
        if Shop.Get(ShopCodeTok) then
            Shop.Delete(true);
        Commit();
    end;
}
