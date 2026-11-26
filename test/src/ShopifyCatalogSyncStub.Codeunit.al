namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost.Shopify;

/// <summary>Replaces the connector only for reserved fixture shops. No provider call or credential is used.</summary>
codeunit 97531 "Shpfy Catalog Sync Stub ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Catalog Sync Run ori", OnBeforeRunConnector, '', false, false)]
    local procedure StandIn(Shop: Record "Shpfy Shop"; var Handled: Boolean)
    var
        Company: Record "Shpfy Company";
        Catalog: Record "Shpfy Catalog";
        Relation: Record "Shpfy Market Catalog Relation";
        EmptyGuid: Guid;
        FailureLbl: Label 'Mock catalog connector failure after local writes.', Locked = true;
    begin
        if not Shop.FindFirst() then
            exit;
        if not (Shop.Code in ['BIFT21', 'BIFT21FAIL', 'BIFT21COMMIT', 'BIFT21&<|()', 'BIFT21-1234567890123']) then
            exit;
        Handled := true;
        if not Catalog.Get(2100001, EmptyGuid) then begin
            Catalog.Init();
            Catalog.Id := 2100001;
            Catalog."Shop Code" := Shop.Code;
            Catalog."Catalog Type" := Catalog."Catalog Type"::Market;
            Catalog.Insert();
        end;
        Catalog.Name := 'Mock market catalog';
        Catalog.Modify();
        Relation.SetRange("Shop Code", Shop.Code);
        Relation.SetRange("Catalog Id", Catalog.Id);
        Relation.DeleteAll();
        Relation.Init();
        Relation."Shop Code" := Shop.Code;
        Relation."Catalog Id" := Catalog.Id;
        Relation."Market Id" := 2100001;
        Relation.Insert();
        Company.SetLoadFields("Shop Id");
        Company.SetRange("Shop Id", Shop."Shop Id");
        if Company.FindSet() then
            repeat
                if not Catalog.Get(2100002, Company.SystemId) then begin
                    Catalog.Init();
                    Catalog.Id := 2100002;
                    Catalog."Company SystemId" := Company.SystemId;
                    Catalog."Shop Code" := Shop.Code;
                    Catalog."Catalog Type" := Catalog."Catalog Type"::Company;
                    Catalog.Insert();
                end;
            until Company.Next() = 0;
        if Shop.Code = 'BIFT21FAIL' then
            Error(FailureLbl);
        if Shop.Code = 'BIFT21COMMIT' then
            Commit();
    end;
}
