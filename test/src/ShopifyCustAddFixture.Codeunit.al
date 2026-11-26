namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using System.TestLibraries.Utilities;

/// <summary>Self-seeded MCP fixture without credentials; only X-prefixed demo rows are used.</summary>
codeunit 97593 "Shopify CustAdd Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Seeds two enabled shops, one disabled shop and three selected customers.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        Index: Integer;
        Codes: List of [Code[20]];
        ShopCode: Code[20];
        ShopId: Integer;
    begin
        RemoveAll();
        Codes.Add('XMCA17');
        Codes.Add('XMCA17FAIL');
        Codes.Add('XMCA17DIS');
        Codes.Add('XMCA17NOID');
        ShopId := 975930;
        foreach ShopCode in Codes do begin
            ShopId += 1;
            Shop.Init();
            Shop.Code := ShopCode;
            Shop.Insert();
            Shop."Shop Id" := ShopId;
            if ShopCode = 'XMCA17NOID' then
                Shop."Shop Id" := 0;
            Shop.Enabled := ShopCode <> 'XMCA17DIS';
            Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
            Shop.Modify();
        end;
        for Index := 1 to 3 do begin
            Customer.Init();
            Customer."No." := CopyStr('XCA17-' + Format(Index, 0, 9), 1, 20);
            Customer.Name := 'XCustomer Add fixture';
            Customer.Insert();
        end;
        Commit();
    end;

    /// <summary>Removes all fixture rows and asserts cleanup.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Link: Record "Shpfy Customer";
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
        Assert: Codeunit "Library Assert";
        UnexpectedLink: Boolean;
        Index: Integer;
    begin
        if Shop.Get('XMCA17FAIL') then
            for Index := 2 to 3 do
                if Customer.Get('XCA17-' + Format(Index, 0, 9)) then begin
                    Link.SetRange("Shop Id", Shop."Shop Id");
                    Link.SetRange("Customer SystemId", Customer.SystemId);
                    UnexpectedLink := UnexpectedLink or not Link.IsEmpty();
                end;
        RemoveAll();
        Assert.IsFalse(UnexpectedLink, 'Failed connector links rolled back.');
        Link.Reset();
        Link.SetRange(Id, 975900001, 975900200);
        Assert.IsTrue(Link.IsEmpty(), 'No link residue.');
        Customer.SetFilter("No.", 'XCA17-*');
        Assert.IsTrue(Customer.IsEmpty(), 'No customer residue.');
    end;

    local procedure RemoveAll()
    var
        Link: Record "Shpfy Customer";
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
        Skipped: RecordRef;
    begin
        Link.SetRange(Id, 975900001, 975900200);
        Link.DeleteAll();
        Customer.SetFilter("No.", 'XCA17-*');
        Skipped.Open(30159);
        if Customer.FindSet() then
            repeat
                Skipped.Field(5).SetRange(Customer.RecordId());
                Skipped.DeleteAll();
            until Customer.Next() = 0;
        Customer.DeleteAll();
        Shop.SetFilter(Code, 'XMCA17|XMCA17FAIL|XMCA17DIS|XMCA17NOID|XCA17|XCA17OTHER');
        Shop.DeleteAll();
        Commit();
    end;
}
