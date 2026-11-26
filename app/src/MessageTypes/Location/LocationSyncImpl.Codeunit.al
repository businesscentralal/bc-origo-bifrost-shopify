namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>Reconciles locations for one shop through Get Locations (codeunit 30198).</summary>
codeunit 73732120 "Location Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;
    TableNo = "Message Argument ori";

    trigger OnRun()
    begin
        ExecuteBifrostTask(Rec);
    end;

    /// <summary>Checks the connector table permissions required by this write.</summary>
    /// <returns>True when the caller can read shops and read and write locations.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        Location: Record "Shpfy Shop Location";
    begin
        exit(Shop.ReadPermission() and Location.ReadPermission() and Location.WritePermission());
    end;

    /// <summary>Identifies the request target table.</summary>
    /// <returns>The Shopify shop table number.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Shop");
    end;

    /// <summary>Describes the operation in the caller's language.</summary>
    /// <returns>A short description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Imports Shopify locations and removes stale locations and their BC location mappings.', Comment = 'is-IS=Flytur inn Shopify staðsetningar og fjarlægir úreltar staðsetningar og vörpun þeirra í BC.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies localized discovery keywords.</summary>
    /// <returns>Comma-separated search terms.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify locations, import locations, location mappings, get locations', Comment = 'is-IS=shopify staðsetningar, flytja inn staðsetningar, vörpun staðsetninga, sækja staðsetningar';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Explains when to select this operation.</summary>
    /// <returns>A localized selection description.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to get locations for one enabled Shopify shop. Removes stale locations and their BC mappings; may update the fulfillment service callback URL in Shopify.', Comment = 'is-IS=Notað til að sækja staðsetningar fyrir eina virka Shopify verslun. Fjarlægir úreltar staðsetningar og BC vörpun þeirra; getur uppfært endurkallsslóð afgreiðsluþjónustu í Shopify.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Supplies the envelope contract chapter.</summary>
    /// <param name="Envelope">Receives the chapter.</param>
    /// <returns>False; the standard behavior applies.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the target contract chapter.</summary>
    /// <param name="Target">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The enabled Shopify shop whose locations are imported.'));
        exit(true);
    end;

    /// <summary>Supplies the parameters contract chapter.</summary>
    /// <param name="Parameters">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of one enabled Shopify shop, 1 to 20 characters.'));
        exit(true);
    end;

    /// <summary>Supplies the response contract chapter.</summary>
    /// <param name="Response">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The selected shop code.'));
        Fields.Add(ContractMgt.ResponseField('locationsBefore', 'integer', 'Number of locations for this shop before the connector ran.'));
        Fields.Add(ContractMgt.ResponseField('locationsAfter', 'integer', 'Number of locations for this shop after the connector ran. Includes insertions and removals.'));
        Fields.Add(ContractMgt.ResponseField('netChange', 'integer', 'locationsAfter minus locationsBefore; may be negative.'));
        Fields.Add(ContractMgt.ResponseField('inserted', 'integer', 'Location IDs present after the call but absent before it.'));
        Fields.Add(ContractMgt.ResponseField('removed', 'integer', 'Location IDs present before the call but absent after it, including removed mappings.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the errors contract chapter.</summary>
    /// <param name="Errors">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'shopCode is required.', 'The key is missing. Nothing changed.', 'Send data.shopCode.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'shopCode must be text of 1 to 20 characters.', 'The key is malformed. Nothing changed.', 'Send a nonblank shop code as text.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Unknown parameter.', 'The request contains an undeclared key. Nothing changed.', 'Send only shopCode.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop was not found.', 'The shop does not exist. Nothing changed.', 'Read table 30102 to find a shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify shop is not enabled.', 'The shop is disabled. Nothing changed.', 'Enable the shop on its Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'You do not have permission to import locations.', 'The caller lacks required permissions. Nothing changed.', 'Ask an administrator for SHOPIFY Full ori and Shopify Connector permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The connector refused the location import: {error}', 'The connector failed. Local location changes are rolled back. A completed Shopify callback update cannot be rolled back.', 'Correct the reported cause and retry.'));
        exit(true);
    end;

    /// <summary>Supplies the effect contract chapter.</summary>
    /// <param name="Effect">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Inserts and updates Shopify Shop Location rows (table 30113). Deletes stale Shopify locations and their BC location mappings, mirroring Get Locations in Business Central. Retained location mappings are preserved. May update the fulfillment service callback URL in Shopify. Local changes roll back on connector failure; completed remote changes cannot be rolled back.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Preconditions.Add('The shop exists and is enabled. The caller holds Shopify Connector permissions.');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Supplies the metering contract chapter.</summary>
    /// <param name="Metering">Receives the chapter.</param>
    /// <returns>False; the standard behavior applies.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related contract chapter.</summary>
    /// <param name="Related">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'Read shops in table 30102 and Shopify locations in table 30113. Map locations separately with Data.Records.Set.'));
        exit(true);
    end;

    /// <summary>Supplies the workflow contract chapter.</summary>
    /// <param name="Workflow">Receives the chapter.</param>
    /// <returns>False; the standard behavior applies.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the examples contract chapter.</summary>
    /// <param name="Examples">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Import and refresh locations',
            '{"type":"Shopify.Location.Sync","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","locationsBefore":2,"locationsAfter":2,"netChange":0,"inserted":1,"removed":1}'));
        exit(true);
    end;

    /// <summary>Supplies the overview contract chapter.</summary>
    /// <param name="Overview">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Imports Shopify locations for one enabled shop through Microsoft codeunit 30198 Shpfy Sync Shop Locations, the Get Locations action. Inserts and updates table 30113, removes stale locations together with their BC location mappings, and may update the fulfillment service callback URL in Shopify.';
        exit(true);
    end;

    /// <summary>Supplies the notes contract chapter.</summary>
    /// <param name="Notes">Receives the chapter.</param>
    /// <returns>True when the chapter is supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: repeating the call without Shopify changes leaves the same locations and mappings. Mapping fields on retained rows are preserved; mappings on deleted locations are lost. netChange is locationsAfter minus locationsBefore; inserted and removed compare shop-scoped location IDs before and after. These are local row counts, not remote change counts. A connector failure returns BusinessCentralError with its text and rolls back local changes, including explicit connector commits. Completed Shopify callback updates cannot be rolled back. Permissions: SHOPIFY Full ori and Microsoft Shopify Connector permissions.';
        exit(true);
    end;

    /// <summary>Classifies the operation as an inbound write.</summary>
    /// <returns>The inbound direction.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and imports locations in a rollback boundary.</summary>
    /// <param name="Argument">The request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        BeforeIds: List of [BigInteger];
        AfterIds: List of [BigInteger];
        LocationId: BigInteger;
        InsertedCount: Integer;
        RemovedCount: Integer;
        NoPermissionErr: Label 'You do not have permission to import Shopify locations.', Comment = 'is-IS=Þú hefur ekki heimild til að flytja inn Shopify staðsetningar.';
        PermissionExpectedLbl: Label 'SHOPIFY Full ori and Shopify Connector permissions', Comment = 'is-IS=SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the required permissions.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta nauðsynlegum heimildum.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the code of a Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunar.';
        TextExpectedLbl: Label 'text of 1 to 20 characters', Comment = 'is-IS=texti með 1 til 20 stöfum';
        InvalidErr: Label 'Parameter "shopCode" must be text of 1 to 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera texti með 1 til 20 stöfum.';
        InvalidNextLbl: Label 'Send a nonblank shop code as text.', Comment = 'is-IS=Sendu verslunarkóða sem texta og hafðu hann ekki auðan.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'an existing Shopify shop', Comment = 'is-IS=Shopify verslun sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get to find the shop code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna verslunarkóðann.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled Shopify shop', Comment = 'is-IS=virk Shopify verslun';
        EnableShopLbl: Label 'Enable the shop on its Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        RefusedErr: Label 'The connector refused the location import: %1', Comment = '%1 = connector error||is-IS=Tengillinn hafnaði innflutningi staðsetninga: %1';
        SyncedExpectedLbl: Label 'a completed location import', Comment = 'is-IS=lokinn innflutningur staðsetninga';
        FixCauseLbl: Label 'Correct the reported cause and retry.', Comment = 'is-IS=Leiðréttu tilgreinda orsök og reyndu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopCode', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopCode', '', TextExpectedLbl, MissingNextLbl);
            exit;
        end;
        if not IsShopCodeText(Token, ShopCodeText) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopCode', '', TextExpectedLbl, InvalidNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Code, Enabled);
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopLbl, FindShopLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledShopLbl, EnableShopLbl);
            exit;
        end;
        ReadLocationIds(Shop.Code, BeforeIds);
        // End pipeline bookkeeping before the conditional Run starts its isolated transaction.
        Commit();
        ClearLastError();
        if not Codeunit.Run(Codeunit::"Location Sync Run ori", Shop) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, GetLastErrorText()), 'shopCode', Shop.Code, SyncedExpectedLbl, FixCauseLbl);
            exit;
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ReadLocationIds(Shop.Code, AfterIds);
        foreach LocationId in AfterIds do
            if not BeforeIds.Contains(LocationId) then
                InsertedCount += 1;
        foreach LocationId in BeforeIds do
            if not AfterIds.Contains(LocationId) then
                RemovedCount += 1;
        ResponseJson.Add('locationsBefore', BeforeIds.Count());
        ResponseJson.Add('locationsAfter', AfterIds.Count());
        ResponseJson.Add('netChange', AfterIds.Count() - BeforeIds.Count());
        ResponseJson.Add('inserted', InsertedCount);
        ResponseJson.Add('removed', RemovedCount);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsShopCodeText(Token: JsonToken; var ShopCodeText: Text): Boolean
    var
        Serialized: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Serialized);
        if not Serialized.StartsWith('"') then
            exit(false);
        ShopCodeText := Token.AsValue().AsText();
        exit((StrLen(ShopCodeText) <= 20) and (DelChr(ShopCodeText, '=', ' ') <> ''));
    end;

    local procedure ReadLocationIds(ShopCode: Code[20]; var LocationIds: List of [BigInteger])
    var
        Location: Record "Shpfy Shop Location";
    begin
        Clear(LocationIds);
        Location.SetLoadFields("Shop Code", Id);
        Location.SetRange("Shop Code", ShopCode);
        if Location.FindSet() then
            repeat
                LocationIds.Add(Location.Id);
            until Location.Next() = 0;
    end;
}
