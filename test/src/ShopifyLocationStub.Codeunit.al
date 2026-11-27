namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Replaces Get Locations with deterministic, credential-free reconciliation for issue 15.</summary>
codeunit 97571 "Shopify Location Stub ori"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Location Sync Run ori", 'OnBeforeRunConnector', '', false, false)]
    local procedure ReplaceConnector(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Location: Record "Shpfy Shop Location";
        UnexpectedShopErr: Label 'Issue 15 tests refuse connector access outside their fixtures.', Locked = true;
        MockFailureErr: Label 'X15 mock connector failure after commit.', Locked = true;
    begin
        if not (CopyStr(Shop.Code, 1, 4) = 'X15-') then
            Error(UnexpectedShopErr);
        Handled := true;
        Location.SetRange("Shop Code", Shop.Code);
        if Shop.Code = 'X15-EMPTY' then begin
            Location.DeleteAll(true);
            exit;
        end;
        if Location.Get(Shop.Code, 975700003) then
            Location.Delete(true);
        if Location.Get(Shop.Code, 975700001) then begin
            Location.Name := 'X15 Refreshed warehouse';
            Location.Active := true;
            Location."Is Primary" := true;
            Location.Modify();
        end;
        Commit();
        SeedLocation(Shop.Code, 975700002, 'X15 New warehouse', false);
        if Shop.Code = 'X15-FAIL' then begin
            Commit();
            Error(MockFailureErr);
        end;
    end;

    /// <summary>Creates a location without credentials, validation side effects or provider access.</summary>
    /// <param name="ShopCode">Fixture shop code.</param>
    /// <param name="LocationId">Fixture location ID.</param>
    /// <param name="LocationName">Fixture name.</param>
    /// <param name="WithMapping">Whether to seed location mappings.</param>
    procedure SeedLocation(ShopCode: Code[20]; LocationId: BigInteger; LocationName: Text[50]; WithMapping: Boolean)
    var
        Location: Record "Shpfy Shop Location";
    begin
        if Location.Get(ShopCode, LocationId) then
            exit;
        Location.Init();
        Location."Shop Code" := ShopCode;
        Location.Id := LocationId;
        Location.Name := LocationName;
        if WithMapping then begin
            Location."Location Filter" := 'X15-WH|X15-SECOND';
            Location."Default Location Code" := 'X15-WH';
            Location."Stock Calculation" := "Shpfy Stock Calculation"::"Non-reserved Inventory";
        end;
        Location.Insert();
    end;
}
