namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Replaces the Metafields API only for the reserved issue 35 fixture.</summary>
codeunit 97511 "Shpfy Metafield Stub ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Metafield Sync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandIn(ParentTableNo: Integer; OwnerId: BigInteger; ShopCode: Code[20]; Direction: Text; var Handled: Boolean)
    var
        Metafield: Record "Shpfy Metafield";
        Product: Record "Shpfy Product";
        Assert: Codeunit "Library Assert";
    begin
        if (ShopCode <> 'XMF35') or (OwnerId <> 8935000035L) then
            exit;
        Handled := true;
        Assert.IsTrue(ParentTableNo in [30127, 30129, 30105, 30150], 'Supported connector owner table.');
        Assert.IsTrue(Direction in ['GetDefinitions', 'SendValues'], 'Exact connector direction.');
        Metafield.SetRange("Parent Table No.", ParentTableNo);
        Metafield.SetRange("Owner Id", OwnerId);
        if Metafield.IsEmpty() then begin
            Metafield.Init();
            Metafield.Id := -8935000000L - ParentTableNo;
            Metafield."Parent Table No." := ParentTableNo;
            Metafield."Owner Id" := OwnerId;
            Metafield.Namespace := 'XMF35';
            Metafield.Name := 'definition';
            Metafield.Insert(false);
        end;
        Metafield.FindFirst();
        if Direction = 'SendValues' then begin
            Metafield.Value := 'XMOCK-SENT';
            Metafield.Modify(false);
        end;
        Product.Get(OwnerId);
        if Product.Title = 'XREFUSE' then
            Error('Mock connector refusal: Money currency does not match shop currency.');
    end;
}
