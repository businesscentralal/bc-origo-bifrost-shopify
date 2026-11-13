namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Product.SyncPrices</c>. Sends the Business Central sales prices of the shop's
/// mapped products to Shopify through the connector's own price sync (report Shpfy Sync Products with Only Sync Price,
/// which uses Shpfy Product Price Calc. and the bulk operation Shpfy Bulk UpdateProductPrice).
/// </summary>
codeunit 73731990 "Product SyncPrices Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit(Shop.ReadPermission() and ShopifyProduct.ReadPermission() and ShopifyVariant.WritePermission() and Item.ReadPermission());
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
        DescriptionLbl: Label 'Sends the Business Central sales prices of a Shopify shop''s products to Shopify.', Comment = 'is-IS=Sendir söluverð Business Central fyrir vörur Shopify verslunar til Shopify.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify prices, sync prices, send prices to shopify, update shopify prices, prices to shopify', Comment = 'is-IS=shopify verð, samstilla verð, senda verð til shopify, uppfæra shopify verð, verð til shopify';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to push current sales prices (and compare-at prices and unit costs) of already mapped products to Shopify for one shop. It does not create products or import anything.', Comment = 'is-IS=Notað til að senda núverandi söluverð (og samanburðarverð og einingarkostnað) þegar tengdra vara til Shopify fyrir eina verslun. Býr ekki til vörur og flytur ekkert inn.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of the Shopify shop (table 30102) whose products are priced.'));
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
        Fields.Add(ContractMgt.ResponseField('productsConsidered', 'integer', 'The number of the shop''s products mapped to an item that the price sync went through.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not send the prices of shop {code} to Shopify.', 'The connector refused or Shopify could not be reached. The connector''s own error text is returned.', 'Fix the cause named in the text, then call again.'));
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
        Preconditions.Add('The shop''s products are mapped to items (Shopify Products with an item).');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the connector''s price sync (report Shpfy Sync Products, Only Sync Price): updates the prices, compare-at prices and unit costs of the shop''s Shopify variants in Shopify and stores them (and the updated-at time) on the Shopify variants in Business Central, through a Shopify bulk operation or single requests. If the connector refuses or Shopify cannot be reached, the variants of the shop are restored to their values before the call, so nothing is recorded as sent that was not.');
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
        Examples.Add(ContractMgt.Example('Send the prices of a shop to Shopify',
            '{"type":"Shopify.Product.SyncPrices","data":{"shopCode":"MAIN"}}',
            '{"status":"Success","shopCode":"MAIN","productsConsidered":12}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Sends the Business Central sales prices of one Shopify shop to Shopify through the connector''s own price sync (report Shpfy Sync Products with Only Sync Price, using Shpfy Product Price Calc. and the bulk operation Shpfy Bulk UpdateProductPrice), so the standard price calculation and the connector''s checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: only variants whose calculated price, compare-at price or unit cost differ from what is stored are sent, so a second call with unchanged prices sends nothing. The price follows the shop''s price calculation settings. The connector commits inside the path. A failure of the connector is returned as a refusal and the variants of the shop are restored to what they were before the call, so a repeat call after the cause is fixed sends the prices again. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for products and variants.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and runs the connector's price sync for the shop.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        ShopifyProduct: Record "Shpfy Product";
        TempVariantSnapshot: Record "Shpfy Variant" temporary;
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        NoPermissionErr: Label 'You do not have the permissions to send prices to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að senda verð til Shopify.';
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
        RefusedErr: Label 'Can not send the prices of shop %1 to Shopify. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að senda verð verslunar %1 til Shopify. %2';
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

        // The connector report calculates the prices and sends the changed variants to Shopify.
        ClearLastError();
        SnapshotVariants(Shop.Code, TempVariantSnapshot);
        if not TrySyncPrices(Shop) then begin
            RestoreVariants(TempVariantSnapshot);
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, GetLastErrorText()), 'shopCode', Shop.Code, SyncExpectedLbl, FixCauseLbl);
            exit;
        end;
        ShopifyProduct.SetRange("Shop Code", Shop.Code);
        ShopifyProduct.SetFilter("Item SystemId", '<>%1', NullGuid());
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('productsConsidered', ShopifyProduct.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure NullGuid(): Guid
    var
        EmptyGuid: Guid;
    begin
        exit(EmptyGuid);
    end;

    local procedure SnapshotVariants(ShopCode: Code[20]; var TempSnapshot: Record "Shpfy Variant" temporary)
    var
        ShopifyVariant: Record "Shpfy Variant";
    begin
        TempSnapshot.Reset();
        TempSnapshot.DeleteAll();
        ShopifyVariant.SetRange("Shop Code", ShopCode);
        if ShopifyVariant.FindSet() then
            repeat
                TempSnapshot := ShopifyVariant;
                TempSnapshot.Insert();
            until ShopifyVariant.Next() = 0;
    end;

    /// A [TryFunction] does not roll back database writes. When the connector refuses, put the variants back as they were
    /// so Business Central does not record prices as sent that never reached Shopify.
    local procedure RestoreVariants(var TempSnapshot: Record "Shpfy Variant" temporary)
    var
        ShopifyVariant: Record "Shpfy Variant";
    begin
        if TempSnapshot.FindSet() then
            repeat
                if ShopifyVariant.Get(TempSnapshot.Id) then begin
                    ShopifyVariant.TransferFields(TempSnapshot, false);
                    ShopifyVariant.Modify();
                end;
            until TempSnapshot.Next() = 0;
    end;

    [TryFunction]
    local procedure TrySyncPrices(var Shop: Record "Shpfy Shop")
    var
        ParametersTxt: Label '<?xml version="1.0" standalone="yes"?><ReportParameters name="Shpfy Sync Products" id="30108"><Options><Field name="OnlySyncPrices">true</Field></Options><DataItems><DataItem name="Shop">%1</DataItem></DataItems></ReportParameters>', Locked = true;
    begin
        Shop.SetRecFilter();
        Report.Execute(Report::"Shpfy Sync Products", StrSubstNo(ParametersTxt, Shop.GetView()));
    end;
}
