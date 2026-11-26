namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Self-seeded demo-only fixture for mock MCP cancellation calls; cleanup removes every fixture row.</summary>
codeunit 97503 "Shopify Cancel Fixture ori"
{
    Subtype = Test;
    RequiredTestIsolation = Disabled;
    TestPermissions = Disabled;

    /// <summary>Creates token-free enabled and disabled shops and cancellation test orders.</summary>
    [Test]
    procedure A1SeedFixture()
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderId: BigInteger;
    begin
        RemoveAll();
        Shop.Init();
        Shop.Code := 'XMCPCANCEL27';
        Shop.Insert();
        Shop.Enabled := true;
        Shop."Logging Mode" := Shop."Logging Mode"::Disabled;
        Shop.Modify();
        Shop.Init();
        Shop.Code := 'XMCPCANCEL27OFF';
        Shop.Insert();
        for OrderId := 975030027 to 975030031 do begin
            OrderHeader.Init();
            OrderHeader."Shopify Order Id" := OrderId;
            OrderHeader."Shop Code" := 'XMCPCANCEL27';
            case OrderId of
                975030029:
                    OrderHeader."Cancelled At" := CurrentDateTime();
                975030030:
                    OrderHeader."Shop Code" := 'XMCPCANCEL27NONE';
                975030031:
                    OrderHeader."Shop Code" := 'XMCPCANCEL27OFF';
            end;
            OrderHeader.Insert();
        end;
        Commit();
    end;

    /// <summary>Removes fixture orders and shops and asserts no fixture order remains.</summary>
    [Test]
    procedure A2RemoveFixture()
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
        Assert: Codeunit "Library Assert";
    begin
        RemoveAll();
        OrderHeader.SetRange("Shopify Order Id", 975030027, 975030031);
        Assert.IsTrue(OrderHeader.IsEmpty(), 'All fixture orders removed.');
        Assert.IsFalse(Shop.Get('XMCPCANCEL27'), 'Enabled fixture shop removed.');
        Assert.IsFalse(Shop.Get('XMCPCANCEL27OFF'), 'Disabled fixture shop removed.');
    end;

    local procedure RemoveAll()
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
    begin
        OrderHeader.SetRange("Shopify Order Id", 975030027, 975030031);
        OrderHeader.DeleteAll();
        if Shop.Get('XMCPCANCEL27') then
            Shop.Delete();
        if Shop.Get('XMCPCANCEL27OFF') then
            Shop.Delete();
        Commit();
    end;
}
