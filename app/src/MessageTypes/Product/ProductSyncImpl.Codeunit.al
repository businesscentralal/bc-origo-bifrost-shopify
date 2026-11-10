namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Product.Sync</c>. Runs the connector's own product sync (report Shpfy Sync Products,
/// without Only Sync Price) for one shop: imports products from Shopify and exports changed items to Shopify, as the
/// shop's Sync Item and Shopify Can Update Items setup says.
/// </summary>
codeunit 70013460 "Product Sync Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Shop: Record "Shpfy Shop";
        ShopifyProduct: Record "Shpfy Product";
        ShopifyVariant: Record "Shpfy Variant";
        Item: Record Item;
    begin
        exit(Shop.ReadPermission() and ShopifyProduct.WritePermission() and ShopifyVariant.WritePermission() and Item.ReadPermission());
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
        DescriptionLbl: Label 'Imports products from Shopify and exports changed items to Shopify for one shop, as the shop is set up.', Comment = 'is-IS=Flytur inn vörur frá Shopify og sendir breyttar vörur til Shopify fyrir eina verslun, eins og verslunin er uppsett.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify products, sync products, import products from shopify, export items to shopify, product sync', Comment = 'is-IS=shopify vörur, samstilla vörur, sækja vörur frá shopify, senda vörur til shopify, vörusamstilling';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to run the shop''s product sync: import products from Shopify and export changed items to Shopify as the shop is set up. To send only prices use Shopify.Product.SyncPrices; to create one item from a product use Shopify.Product.CreateItem.', Comment = 'is-IS=Notað til að keyra vörusamstillingu verslunarinnar: flytja inn vörur frá Shopify og senda breyttar vörur til Shopify eins og verslunin er uppsett. Notaðu Shopify.Product.SyncPrices til að senda aðeins verð og Shopify.Product.CreateItem til að búa til eina vöru út frá Shopify vöru.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of the Shopify shop (table 30102) whose products are synchronized.'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of the Shopify shop, e.g. from Data.Records.Get on table 30102.'));
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
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The Shopify shop code.'));
        Fields.Add(ContractMgt.ResponseField('productsInShop', 'integer', 'The number of Shopify products stored for the shop after the sync.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "shopCode" is required.', 'The request has no shopCode. Nothing was changed.', 'Send data.shopCode with the Shopify shop code.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "shopCode" must be text of at most 20 characters.', 'The value is empty or too long. Nothing was changed.', 'Send the Shopify shop code as text.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop {code} was not found.', 'No shop has this code. Nothing was changed.', 'Read table 30102 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify shop {code} is not enabled.', 'The shop is not enabled, so the connector cannot talk to Shopify. Nothing was changed.', 'Enable the shop on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not synchronize the products of shop {code} with Shopify.', 'The connector refused or Shopify could not be reached. The connector''s own error text is returned.', 'Fix the cause named in the text, then call again.'));
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
        Preconditions.Add('The shop''s Sync Item setup (From Shopify or To Shopify) names the direction the connector syncs.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the connector''s product sync (report Shpfy Sync Products): with Sync Item From Shopify it imports products and variants from Shopify into the Shopify product tables (and creates or updates items as the shop is set up); with Sync Item To Shopify it sends changed items to Shopify (shop Can Update Shopify Products decides whether Shopify products are changed). The connector commits inside this path (Commit() in the product and variant sync codeunits), so earlier products stay even if a later step fails.');
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
        Examples.Add(ContractMgt.Example('Synchronize the products of a shop',
            '{"type":"Shopify.Product.Sync","data":{"shopCode":"MAIN"}}',
            '{"status":"Success","shopCode":"MAIN","productsInShop":12}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs the connector''s own product sync for one Shopify shop (report Shpfy Sync Products, not the price-only mode): imports products from Shopify and exports changed items to Shopify as the shop is set up, so the connector''s mapping rules and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: a second call with nothing changed in Shopify or Business Central changes nothing, because products are matched on the stored mapping. The direction follows the shop setup (Sync Item). A shop with Sync Item empty does nothing. The connector commits inside the path. A failure of the connector is returned as a refusal; products the connector committed before the failure are kept. Use Shopify.Product.SyncPrices to send only prices. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for products and variants.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and runs the connector's product sync for the shop.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        ShopifyProduct: Record "Shpfy Product";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        NoPermissionErr: Label 'You do not have the permissions to synchronize Shopify products.', Comment = 'is-IS=Þú hefur ekki heimildir til að samstilla Shopify vörur.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the Shopify shop code.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunarinnar.';
        TextExpectedLbl: Label 'a shop code of at most 20 characters', Comment = 'is-IS=kóði verslunar, mest 20 stafir';
        InvalidErr: Label 'Parameter "shopCode" must be text of at most 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera texti, mest 20 stafir.';
        InvalidNextLbl: Label 'Send the Shopify shop code as text.', Comment = 'is-IS=Sendu kóða Shopify verslunarinnar sem texta.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði Shopify verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled Shopify shop', Comment = 'is-IS=virk Shopify verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        RefusedErr: Label 'Can not synchronize the products of shop %1 with Shopify. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að samstilla vörur verslunar %1 við Shopify. %2';
        SyncExpectedLbl: Label 'a shop Shopify can be reached for', Comment = 'is-IS=verslun sem hægt er að ná sambandi við Shopify fyrir';
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
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'shopCode', '', TextExpectedLbl, MissingNextLbl);
            exit;
        end;
        ShopCodeText := Argument.TokenAsText(Token);
        if (ShopCodeText = '') or (StrLen(ShopCodeText) > MaxStrLen(Shop.Code)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'shopCode', ShopCodeText, TextExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopLbl, FindShopLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledShopLbl, EnableShopLbl);
            exit;
        end;

        // The connector report imports products from Shopify and exports changed items, as the shop's Sync Item setup says.
        ClearLastError();
        if not TrySyncProducts(Shop) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, GetLastErrorText()), 'shopCode', Shop.Code, SyncExpectedLbl, FixCauseLbl);
            exit;
        end;
        ShopifyProduct.SetRange("Shop Code", Shop.Code);
                ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('productsInShop', ShopifyProduct.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    [TryFunction]
    local procedure TrySyncProducts(var Shop: Record "Shpfy Shop")
    var
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Products" id="30108"><Options><Field name="OnlySyncPrices">false</Field></Options><DataItems><DataItem name="Shop">%1</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        Shop.SetRecFilter();
        Report.Execute(Report::"Shpfy Sync Products", StrSubstNo(ParametersTxt, Shop.GetView()));
    end;
}
