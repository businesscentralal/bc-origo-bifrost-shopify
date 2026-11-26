namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Seeds and removes only issue 26 fixture records for dispatcher and MCP checks.</summary>
codeunit 97532 "Shpfy MarkPaid Fixture ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    /// <summary>Seeds unpaid, refused, paid, disabled-shop and orphan orders without credentials.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        Index: Integer;
    begin
        A2RemoveFixture();
        Shop.Init();
        Shop.Code := 'X26ON';
        Shop.Enabled := true;
        Shop.Insert();
        Shop.Init();
        Shop.Code := 'X26OFF';
        Shop.Enabled := false;
        Shop.Insert();
        for Index := 1 to 8 do begin
            OrderHeader.Init();
            OrderHeader."Shopify Order Id" := 975300000 + Index;
            OrderHeader."Shop Code" := 'X26ON';
            OrderHeader."Fully Paid" := Index = 4;
            if Index = 5 then
                OrderHeader."Shop Code" := 'X26OFF';
            if Index = 6 then
                OrderHeader."Shop Code" := 'X26MISSING';
            OrderHeader.Insert();
        end;
        Commit();
    end;

    /// <summary>Removes all reserved records and verifies cleanup.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        PaidMarker: Record "Order Paid Marker ori";
        Assert: Codeunit "Library Assert";
    begin
        PaidMarker.SetFilter("Shop Code", 'X26ON|X26OFF|X26MISSING');
        PaidMarker.SetRange("Order Id", 975300001, 975300008);
        PaidMarker.DeleteAll();
        OrderHeader.SetRange("Shopify Order Id", 975300001, 975300008);
        OrderHeader.SetFilter("Shop Code", 'X26ON|X26OFF|X26MISSING');
        OrderHeader.DeleteAll();
        Shop.SetFilter(Code, 'X26ON|X26OFF');
        Shop.DeleteAll();
        Commit();
        Assert.IsTrue(PaidMarker.IsEmpty() and OrderHeader.IsEmpty() and Shop.IsEmpty(), 'All issue 26 fixture data removed.');
    end;
}
