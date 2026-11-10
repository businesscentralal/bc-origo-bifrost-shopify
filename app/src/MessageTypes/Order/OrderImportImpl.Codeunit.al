namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Order.Import</c>. Fetches new and changed orders of one Shopify shop and imports and
/// maps them by running the Shopify report Sync Orders from Shopify (30104), which uses codeunit Shpfy Orders API (30165).
/// </summary>
codeunit 70013410 "Order Import Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        OrderHeader: Record "Shpfy Order Header";
        Shop: Record "Shpfy Shop";
    begin
        exit(OrderHeader.WritePermission() and Shop.WritePermission());
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
        DescriptionLbl: Label 'Fetches new and changed orders from a Shopify shop into Business Central and maps customers and items.', Comment = 'is-IS=Sækir nýjar og breyttar pantanir úr Shopify verslun í Business Central og varpar viðskiptavinum og vörum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify order import, sync orders from shopify, fetch shopify orders, import web shop orders, get new webshop orders', Comment = 'is-IS=shopify pantanainnflutningur, samstilla pantanir frá shopify, sækja shopify pantanir, flytja inn vefverslunarpantanir, sækja nýjar vefverslunarpantanir';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to pull new and changed orders of one shop from Shopify. It contacts Shopify. It does not create sales orders unless the shop has Auto Create Orders set, and it does not read orders already imported (use Data.Records.Get on table 30118).', Comment = 'is-IS=Notað til að sækja nýjar og breyttar pantanir einnar verslunar úr Shopify. Hefur samband við Shopify. Býr ekki til sölupantanir nema verslunin sé með Auto Create Orders og les ekki pantanir sem þegar eru innfluttar (notaðu Data.Records.Get á töflu 30118).';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of the Shopify shop whose orders are fetched (table 30102).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The Code of an enabled Shopify shop, e.g. from Data.Records.Get on table 30102.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop code.'));
        Fields.Add(ContractMgt.ResponseField('ordersBefore', 'integer', 'Number of imported Shopify orders of the shop before the run.'));
        Fields.Add(ContractMgt.ResponseField('ordersAfter', 'integer', 'Number of imported Shopify orders of the shop after the run.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shopCode" is required.', 'The request has no shopCode. Nothing was changed.', 'Send data.shopCode with the code of the Shopify shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shopCode" must be a text of 1 to 20 characters.', 'The value is empty or longer than a shop code. Nothing was changed.', 'Send the code of the Shopify shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop {code} was not found.', 'No shop has this code. Nothing was changed.', 'Read table 30102 with Data.Records.Get to find the shop code.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {code} is not enabled.', 'The shop is not enabled. Nothing was changed.', 'Enable the shop and connect it to Shopify on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not import orders for shop {code}.', 'Shopify or Business Central refused: for example the connection or access token is missing, or Shopify returned errors. The text names the cause.', 'Fix the cause named in the text, then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The shop exists, is enabled and is connected to Shopify (URL and access token).');
        Preconditions.Add('Business Central can reach Shopify.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs report Sync Orders from Shopify (30104) for the shop: queries Shopify for new and changed orders (codeunit Shpfy Orders API 30165), stores them in Shpfy Orders to Import, imports each into the Shopify order tables, maps customers and items, and, when the shop has Auto Create Orders, creates the sales documents of new orders and processes refunds. It also updates the shop''s last order sync time. The Shopify code commits (Commit()) many times on this path, so work done before a failure is kept.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to read the imported orders, e.g. table 30118 Shpfy Order Header, or the shops, table 30102.'));
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
        Examples.Add(ContractMgt.Example('Import the new orders of a shop',
            '{"type":"Shopify.Order.Import","data":{"shopCode":"WEBSHOP"}}',
            '{"status":"Success","shopCode":"WEBSHOP","ordersBefore":120,"ordersAfter":123}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Fetches new and changed orders of one Shopify shop and imports and maps them by running the Shopify report Sync Orders from Shopify (30104), which uses codeunit Shpfy Orders API (30165), so the Shopify connector''s own validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: a repeated call fetches only orders changed since the shop''s last order sync and re-imports nothing that is unchanged. It needs the shop to be enabled and connected to Shopify, so it contacts Shopify. The report runs with the shop filter only; the order filters of the report page are not exposed. The Shopify code commits many times; a refusal that occurs after some orders were imported keeps those orders. A failure is returned as a refusal with the Shopify or Business Central text. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for orders, customers and items.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and imports the shop's orders through the Shopify report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        OrderHeader: Record "Shpfy Order Header";
        OrderImportRun: Codeunit "Order Import Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        ErrorText: Text;
        OrdersBefore: Integer;
        NoPermissionErr: Label 'You do not have the permissions to import orders from Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að flytja inn pantanir úr Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the code of the Shopify shop.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunarinnar.';
        ShopCodeExpectedLbl: Label 'the code of a Shopify shop (1 to 20 characters)', Comment = 'is-IS=kóði Shopify verslunar (1 til 20 stafir)';
        InvalidErr: Label 'Parameter "shopCode" must be a text of 1 to 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera texti, 1 til 20 stafir.';
        InvalidNextLbl: Label 'Send the code of the Shopify shop.', Comment = 'is-IS=Sendu kóða Shopify verslunarinnar.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopExpectedLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði Shopify verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get to find the shop code.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get til að finna kóða verslunarinnar.';
        NotEnabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Verslun %1 er ekki virk.';
        EnabledExpectedLbl: Label 'an enabled shop connected to Shopify', Comment = 'is-IS=virk verslun tengd Shopify';
        EnableShopLbl: Label 'Enable the shop and connect it to Shopify on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina og tengdu hana við Shopify á Shopify Shop Card.';
        ImportedExpectedLbl: Label 'a shop that Shopify and Business Central can import orders for', Comment = 'is-IS=verslun sem Shopify og Business Central geta flutt inn pantanir fyrir';
        RefusedErr: Label 'Can not import orders for shop %1. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að flytja inn pantanir fyrir verslun %1. %2';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopCode', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopCode', '', ShopCodeExpectedLbl, MissingNextLbl);
            exit;
        end;
        ShopCodeText := Argument.TokenAsText(Token);
        if (ShopCodeText = '') or (StrLen(ShopCodeText) > MaxStrLen(Shop.Code)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopCode', ShopCodeText, ShopCodeExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopExpectedLbl, FindShopLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledExpectedLbl, EnableShopLbl);
            exit;
        end;

        OrderHeader.SetRange("Shop Code", Shop.Code);
        OrdersBefore := OrderHeader.Count();
        // The Shopify report fetches, imports and maps the orders and commits along the way.
        OrderImportRun.SetShopCode(Shop.Code);
        ClearLastError();
        if not OrderImportRun.Run() then begin
            ErrorText := GetLastErrorText();
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, ErrorText), 'shopCode', Shop.Code, ImportedExpectedLbl, FixCauseLbl);
            exit;
        end;
        OrderHeader.SetRange("Shop Code", Shop.Code);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('ordersBefore', OrdersBefore);
        ResponseJson.Add('ordersAfter', OrderHeader.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;
}
