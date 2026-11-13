namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Inventory.Sync</c>. Sends the Business Central stock levels per location of a shop's
/// products to Shopify by running the connector report Shpfy Sync Stock to Shopify (30102), the code behind the
/// action Sync Inventory on the Shopify Shop Card and Products.
/// </summary>
codeunit 70013480 "Inventory Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        Item: Record Item;
    begin
        exit(Shop.ReadPermission() and Item.ReadPermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Shop");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Sends the Business Central stock levels per location of a shop''s products to Shopify.', Comment = 'is-IS=Sendir birgðastöðu úr Business Central eftir staðsetningum fyrir vörur verslunar til Shopify.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify inventory, sync stock, send stock to shopify, update shopify stock levels, sync inventory', Comment = 'is-IS=shopify birgðir, samstilla birgðastöðu, senda birgðir til shopify, uppfæra birgðastöðu í shopify, samstilla birgðir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to push stock levels of the items already mapped to Shopify products to one enabled shop. It does not create products and does not send prices; use Shopify.Product.Sync and Shopify.Product.SyncPrices for those.', Comment = 'is-IS=Notað til að senda birgðastöðu vara sem þegar eru tengdar Shopify vörum í eina virka verslun. Býr ekki til vörur og sendir ekki verð; notaðu Shopify.Product.Sync og Shopify.Product.SyncPrices fyrir það.';
    begin
        exit(SelectionLbl);
    end;

    /// <summary>Supplies the envelope chapter; the standard envelope applies.</summary>
    /// <param name="Envelope">Unchanged.</param>
    /// <returns>False; this chapter is not supplied.</returns>
    procedure GetEnvelope(var Envelope: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the target chapter for this message type.</summary>
    /// <param name="Target">Out: the record the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of an enabled Shopify shop (table 30102).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of the Shopify shop whose stock is sent, e.g. from Data.Records.Get on table 30102.'));
        Parameters.Add(ContractMgt.Parameter('skipImport', 'boolean', false, 'True to skip importing the stock from Shopify before the stock is sent. Default false.'));
        Parameters.Add(ContractMgt.Parameter('variantIdFilter', 'string', false, 'A Shopify variant Id filter (for example 123|456) that limits which variants are synchronized. Default all variants.'));
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the response fields.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop whose stock was synchronized.'));
        Fields.Add(ContractMgt.ResponseField('skipImport', 'boolean', 'Whether the import of stock from Shopify was skipped.'));
        Fields.Add(ContractMgt.ResponseField('variantIdFilter', 'string', 'The variant filter that was used, empty for all variants.'));
        Response.Add('contentType', 'text/json');
        Response.Add('fields', Fields);
        exit(true);
    end;

    /// <summary>Supplies the errors chapter for this message type.</summary>
    /// <param name="Errors">Receives the declared errors.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetErrors(var Errors: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shopCode" is required.', 'The request has no shopCode. Nothing was changed.', 'Send data.shopCode with the code of a Shopify shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shopCode" must be a text of 1 to 20 characters.', 'The shop code is empty, too long or not text. Nothing was changed.', 'Send the shop code as text.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "skipImport" must be true or false.', 'The value is not a boolean. Nothing was changed.', 'Send true or false.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "variantIdFilter" is not a valid filter: {filter}', 'The variant filter cannot be interpreted. Nothing was changed.', 'Send a valid filter such as 123|456 or leave it out.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop {code} was not found.', 'No shop has this code. Nothing was changed.', 'Read table 30102 with Data.Records.Get to find the code.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify shop {code} is not enabled.', 'The shop is disabled. Nothing was changed.', 'Enable the shop on the Shopify Shop Card.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shop exists and is enabled.');
        Preconditions.Add('Shopify is reachable and the shop allows outgoing requests, otherwise the connector refuses.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the connector report Shpfy Sync Stock to Shopify for the shop: unless skipImport is true it first imports the stock from Shopify into the shop inventory, then sets the stock level per location in Shopify and updates the shop inventory records. The connector commits as it goes, so a failure part way can leave Shopify updated for the variants already sent.');
        Effect.Add('idempotent', true);
        Effect.Add('permissionSet', 'SHOPIFY Full ori');
        Effect.Add('preconditions', Preconditions);
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no metering chapter.</summary>
    /// <param name="Metering">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetMetering(var Metering: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Supplies the related chapter for this message type.</summary>
    /// <param name="Related">Out: related message types.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetRelated(var Related: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Related.Add(ContractMgt.RelatedEntry('Shopify.Product.Sync', 'You want to send the products themselves, not the stock.'));
        Related.Add(ContractMgt.RelatedEntry('Shopify.Product.SyncPrices', 'You want to send prices.'));
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the shop, e.g. table 30102 Shpfy Shop.'));
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the English examples for this message type.</summary>
    /// <param name="Examples">Out: request and answer pairs.</param>
    /// <returns>True; examples are supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Send the stock levels of a shop to Shopify',
            '{"type":"Shopify.Inventory.Sync","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","skipImport":false,"variantIdFilter":""}'));
        Examples.Add(ContractMgt.Example('Send the stock of one variant without importing first',
            '{"type":"Shopify.Inventory.Sync","data":{"shopCode":"WEBSHOP","skipImport":true,"variantIdFilter":"4455667788"}}',
            '{"status":"Success","shopCode":"WEBSHOP","skipImport":true,"variantIdFilter":"4455667788"}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Sends the Business Central stock levels per location to Shopify for one shop by running the connector report Shpfy Sync Stock to Shopify (30102), so the connector''s own checks and inventory logic run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: sending the same stock twice leaves Shopify with the same levels. The connector commits as it goes, so a failure part way can leave some variants updated in Shopify. A refusal from the connector (for example outgoing requests not allowed for the shop) is returned as a refusal. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and sends the stock through the connector report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        SyncRun: Codeunit "Inventory Sync Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        VariantFilter: Text;
        SkipText: Text;
        SkipImport: Boolean;
        NoPermissionErr: Label 'You do not have the permissions to send stock to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að senda birgðastöðu til Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the code of a Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunar.';
        TextExpectedLbl: Label 'a text of 1 to 20 characters', Comment = 'is-IS=texti með 1 til 20 stöfum';
        InvalidErr: Label 'Parameter "shopCode" must be a text of 1 to 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera texti með 1 til 20 stöfum.';
        InvalidNextLbl: Label 'Send the shop code as text.', Comment = 'is-IS=Sendu kóða verslunarinnar sem texta.';
        BooleanExpectedLbl: Label 'true or false', Comment = 'is-IS=true eða false';
        InvalidSkipErr: Label 'Parameter "skipImport" must be true or false.', Comment = 'is-IS=Færibreytan "skipImport" verður að vera true eða false.';
        InvalidSkipNextLbl: Label 'Send true or false.', Comment = 'is-IS=Sendu true eða false.';
        InvalidFilterErr: Label 'Parameter "variantIdFilter" is not a valid filter: %1', Comment = '%1 = the filter text||is-IS=Færibreytan "variantIdFilter" er ekki gild sía: %1';
        FilterExpectedLbl: Label 'a Business Central number filter such as 123|456', Comment = 'is-IS=talnasía úr Business Central, til dæmis 123|456';
        InvalidFilterNextLbl: Label 'Send a valid filter or leave the parameter out.', Comment = 'is-IS=Sendu gilda síu eða slepptu færibreytunni.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'the code of an existing shop', Comment = 'is-IS=kóði verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get to find the code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna kóðann.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled shop', Comment = 'is-IS=virk verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
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
        ShopCodeText := Argument.TokenAsText(Token);
        if (ShopCodeText = '') or (StrLen(ShopCodeText) > MaxStrLen(Shop.Code)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopCode', ShopCodeText, TextExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if RequestJson.Get('skipImport', Token) then begin
            SkipText := LowerCase(Argument.TokenAsText(Token));
            if not (SkipText in ['true', 'false']) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidSkipErr, 'skipImport', SkipText, BooleanExpectedLbl, InvalidSkipNextLbl);
                exit;
            end;
            SkipImport := SkipText = 'true';
        end;
        if RequestJson.Get('variantIdFilter', Token) then begin
            VariantFilter := Argument.TokenAsText(Token);
            if not IsValidNumberFilter(VariantFilter) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidFilterErr, VariantFilter), 'variantIdFilter', VariantFilter, FilterExpectedLbl, InvalidFilterNextLbl);
                exit;
            end;
        end;
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopLbl, FindShopLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledShopLbl, EnableShopLbl);
            exit;
        end;

        // The connector report imports the stock from Shopify (unless skipped) and sets the stock level per location.
        SyncRun.SetOptions(Shop.Code, SkipImport, VariantFilter);
        SyncRun.Execute();
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('skipImport', SkipImport);
        ResponseJson.Add('variantIdFilter', VariantFilter);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsValidNumberFilter(FilterText: Text): Boolean
    var
        Probe: Record "Shpfy Order Header";
    begin
        if FilterText = '' then
            exit(true);
        exit(TryApplyFilter(Probe, FilterText));
    end;

    [TryFunction]
    local procedure TryApplyFilter(var Probe: Record "Shpfy Order Header"; FilterText: Text)
    begin
        Probe.SetFilter("Shopify Order Id", FilterText);
    end;
}
