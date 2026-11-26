namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Product.SyncImages</c>. Runs the connector's own product image sync (report Shpfy Sync Images,
/// codeunit Shpfy Sync Product Image) for one shop: item pictures are exported to Shopify or product images are imported,
/// as the shop setting Sync Item Images says.
/// </summary>
codeunit 73732100 "Product SyncImages Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
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
        exit(Shop.ReadPermission() and ShopifyProduct.ReadPermission() and ShopifyProduct.WritePermission() and ShopifyVariant.ReadPermission() and Item.ReadPermission());
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
        DescriptionLbl: Label 'Syncs the product images of a Shopify shop in the direction its Sync Item Images setting names.', Comment = 'is-IS=Samstillir vörumyndir Shopify verslunar í þá átt sem stillingin Sync Item Images tilgreinir.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify images, sync images, product images, import images from shopify, send item pictures to shopify', Comment = 'is-IS=shopify myndir, samstilla myndir, vörumyndir, sækja myndir frá shopify, senda vörumyndir til shopify';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to import product images from Shopify or export item pictures to Shopify for one shop; the direction follows the shop setting Sync Item Images and is not a request key. It does not create products or change prices.', Comment = 'is-IS=Notað til að sækja vörumyndir frá Shopify eða senda vörumyndir til Shopify fyrir eina verslun; stefnan fylgir stillingu verslunarinnar Sync Item Images og er ekki færibreyta. Býr ekki til vörur og breytir ekki verði.';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', 'The code of the Shopify shop (table 30102) whose product images are synced.'));
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
        Parameters.Add(ContractMgt.Parameter('productIdFilter', 'string', false, 'A filter on the Shopify product Id, such as 123|456. Leave it out for all products of the shop.'));
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
        Fields.Add(ContractMgt.ResponseField('syncDirection', 'string', 'ToShopify (item pictures exported) or FromShopify (product images imported), the same in every language.'));
        Fields.Add(ContractMgt.ResponseField('productIdFilter', 'string', 'The product filter that was used, empty for all products.'));
        Fields.Add(ContractMgt.ResponseField('productsConsidered', 'integer', 'The number of the shop''s Shopify products the image sync went through (within the filter).'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "productIdFilter" is not a valid filter: {filter}', 'The product filter cannot be interpreted. Nothing was changed.', 'Send a valid filter such as 123|456 or leave it out.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify shop {code} was not found.', 'No shop has this code. Nothing was changed.', 'Read table 30102 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify shop {code} is not enabled.', 'The shop is not enabled, so the connector cannot talk to Shopify. Nothing was changed.', 'Enable the shop on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shopify shop {code} does not sync item images.', 'The shop setting Sync Item Images is Disabled, so there is no direction to sync. Nothing was changed.', 'Set Sync Item Images to To Shopify or From Shopify on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not sync the images of shop {code}.', 'The connector refused or Shopify could not be reached. The connector''s own error text is returned.', 'Fix the cause named in the text, then call again.'));
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
        Preconditions.Add('The shop setting Sync Item Images is To Shopify or From Shopify.');
        Preconditions.Add('To Shopify: the shop''s products are mapped to items with pictures. From Shopify: the shop''s products exist in Business Central.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs the connector''s image sync (report Shpfy Sync Images, codeunit Shpfy Sync Product Image) for the shop. With Sync Item Images = To Shopify it exports the item pictures to the Shopify products (a Shopify bulk operation may be used, so Shopify can finish after the call; see table 30148 Shpfy Bulk Operation). With From Shopify it imports the Shopify product images into the items in Business Central. The export commits per product; if the connector fails, what it wrote after its last commit is rolled back.');
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
        Examples.Add(ContractMgt.Example('Sync the images of a shop',
            '{"type":"Shopify.Product.SyncImages","data":{"shopCode":"MAIN"}}',
            '{"status":"Success","shopCode":"MAIN","syncDirection":"ToShopify","productIdFilter":"","productsConsidered":12}'));
        Examples.Add(ContractMgt.Example('Import the images of two products',
            '{"type":"Shopify.Product.SyncImages","data":{"shopCode":"MAIN","productIdFilter":"123|456"}}',
            '{"status":"Success","shopCode":"MAIN","syncDirection":"FromShopify","productIdFilter":"123|456","productsConsidered":2}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Runs the connector''s own product image sync (report Shpfy Sync Images, codeunit Shpfy Sync Product Image) for one Shopify shop. The direction follows the shop setting Sync Item Images: To Shopify exports item pictures, From Shopify imports product images into Business Central. The standard checks of the connector run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: the connector compares image hashes, so unchanged images are not sent or imported again and a second call with nothing changed does nothing. The direction is not a request key; change the shop setting (Data.Records.Set) to change it. Export commits per product and may use a Shopify bulk operation, so Shopify can finish after the call; read table 30148 Shpfy Bulk Operation for its state. A failure of the connector is returned as a refusal with its text; what it wrote after its last commit is rolled back. productsConsidered counts the shop''s Shopify products within the filter. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for products and variants.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and runs the connector's image sync for the shop.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        ShopifyProduct: Record "Shpfy Product";
        ImagesRun: Codeunit "Product SyncImages Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        ProductFilter: Text;
        Direction: Text;
        NoPermissionErr: Label 'You do not have the permissions to sync Shopify product images.', Comment = 'is-IS=Þú hefur ekki heimildir til að samstilla vörumyndir Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "shopCode" is required.', Comment = 'is-IS=Færibreytan "shopCode" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode with the Shopify shop code.', Comment = 'is-IS=Sendu data.shopCode með kóða Shopify verslunarinnar.';
        TextExpectedLbl: Label 'a shop code of at most 20 characters', Comment = 'is-IS=kóði verslunar, mest 20 stafir';
        InvalidErr: Label 'Parameter "shopCode" must be text of at most 20 characters.', Comment = 'is-IS=Færibreytan "shopCode" verður að vera texti, mest 20 stafir.';
        InvalidNextLbl: Label 'Send the Shopify shop code as text.', Comment = 'is-IS=Sendu kóða Shopify verslunarinnar sem texta.';
        BadFilterErr: Label 'Parameter "productIdFilter" is not a valid filter: %1', Comment = '%1 = the filter||is-IS=Færibreytan "productIdFilter" er ekki gild sía: %1';
        FilterExpectedLbl: Label 'a filter on the Shopify product Id, such as 123|456', Comment = 'is-IS=sía á Shopify vörunúmer (Id), til dæmis 123|456';
        FilterNextLbl: Label 'Send a valid filter such as 123|456 or leave it out.', Comment = 'is-IS=Sendu gilda síu, til dæmis 123|456, eða slepptu henni.';
        NotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði Shopify verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled Shopify shop', Comment = 'is-IS=virk Shopify verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        NoDirectionErr: Label 'Shopify shop %1 does not sync item images.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 samstillir ekki vörumyndir.';
        DirectionExpectedLbl: Label 'a shop whose Sync Item Images is To Shopify or From Shopify', Comment = 'is-IS=verslun þar sem Sync Item Images er To Shopify eða From Shopify';
        SetDirectionLbl: Label 'Set Sync Item Images to To Shopify or From Shopify on the Shopify Shop Card.', Comment = 'is-IS=Stilltu Sync Item Images á To Shopify eða From Shopify á Shopify verslunarspjaldinu.';
        RefusedErr: Label 'Can not sync the images of shop %1. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að samstilla myndir verslunar %1. %2';
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
        if RequestJson.Get('productIdFilter', Token) then begin
            ProductFilter := Argument.TokenAsText(Token);
            if not IsValidProductFilter(ProductFilter) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(BadFilterErr, ProductFilter), 'productIdFilter', CopyStr(ProductFilter, 1, 250), FilterExpectedLbl, FilterNextLbl);
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
        case Shop."Sync Item Images" of
            Shop."Sync Item Images"::"To Shopify":
                Direction := 'ToShopify';
            Shop."Sync Item Images"::"From Shopify":
                Direction := 'FromShopify';
            else begin
                Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NoDirectionErr, Shop.Code), 'shopCode', Shop.Code, DirectionExpectedLbl, SetDirectionLbl);
                exit;
            end;
        end;

        // Commit first, so that a failure of the connector started in the if statement below rolls back exactly what it
        // wrote after its own commits and nothing before it.
        Commit();
        ImagesRun.SetParameters(Shop.Code, ProductFilter);
        ClearLastError();
        if not ImagesRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, GetLastErrorText()), 'shopCode', Shop.Code, SyncExpectedLbl, FixCauseLbl);
            exit;
        end;
        ShopifyProduct.SetRange("Shop Code", Shop.Code);
        if ProductFilter <> '' then
            ShopifyProduct.SetFilter(Id, ProductFilter);
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('syncDirection', Direction);
        ResponseJson.Add('productIdFilter', ProductFilter);
        ResponseJson.Add('productsConsidered', ShopifyProduct.Count());
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure IsValidProductFilter(FilterText: Text): Boolean
    var
        Probe: Record "Shpfy Product";
    begin
        if FilterText = '' then
            exit(true);
        exit(TryApplyFilter(Probe, FilterText));
    end;

    [TryFunction]
    local procedure TryApplyFilter(var Probe: Record "Shpfy Product"; FilterText: Text)
    begin
        Probe.SetFilter(Id, FilterText);
    end;
}
