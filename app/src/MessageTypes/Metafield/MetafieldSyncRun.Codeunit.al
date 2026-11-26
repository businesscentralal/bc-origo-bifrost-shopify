namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;

/// <summary>Runs the public Metafields API inside a Boolean Codeunit.Run transaction boundary.</summary>
codeunit 73732061 "Metafield Sync Run ori"
{
    Access = Internal;

    trigger OnRun()
    var
        Metafields: Codeunit "Shpfy Metafields";
        Handled: Boolean;
    begin
        OnBeforeRunConnector(ParentTableNo, OwnerId, ShopCode, Direction, Handled);
        if Handled then
            exit;
        case Direction of
            'GetDefinitions':
                Metafields.GetMetafieldDefinitions(ParentTableNo, OwnerId, ShopCode);
            'SendValues':
                Metafields.SyncMetafieldsToShopify(ParentTableNo, OwnerId, ShopCode);
        end;
    end;

    /// <summary>Sets the fully validated target for the next runner transaction.</summary>
    /// <param name="NewParentTableNo">Connector owner table number.</param>
    /// <param name="NewOwnerId">Shopify owner ID.</param>
    /// <param name="NewShopCode">Enabled shop code.</param>
    /// <param name="NewDirection">GetDefinitions or SendValues.</param>
    procedure SetRequest(NewParentTableNo: Integer; NewOwnerId: BigInteger; NewShopCode: Code[20]; NewDirection: Text)
    begin
        ParentTableNo := NewParentTableNo;
        OwnerId := NewOwnerId;
        ShopCode := NewShopCode;
        Direction := NewDirection;
    end;

    /// <summary>Allows mock tests to replace the external connector operation.</summary>
    /// <param name="ParentTableNo">Exact owner table number.</param>
    /// <param name="OwnerId">Exact Shopify owner ID.</param>
    /// <param name="ShopCode">Exact enabled shop code.</param>
    /// <param name="Direction">GetDefinitions or SendValues.</param>
    /// <param name="Handled">Tests set true to prevent all connector calls.</param>
    [IntegrationEvent(false, false)]
    internal procedure OnBeforeRunConnector(ParentTableNo: Integer; OwnerId: BigInteger; ShopCode: Code[20]; Direction: Text; var Handled: Boolean)
    begin
    end;

    var
        ParentTableNo: Integer;
        OwnerId: BigInteger;
        ShopCode: Code[20];
        Direction: Text;
}
