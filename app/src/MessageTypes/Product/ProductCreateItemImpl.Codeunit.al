namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Product.CreateItem</c>. Creates Business Central items for the variants of one imported Shopify
/// product and maps them, through the Shopify connector codeunit Shpfy Create Item (30171), the code behind the Create Item action.
/// </summary>
codeunit 70013420 "Product CreateItem Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
        Product: Record "Shpfy Product";
    begin
        exit(Item.WritePermission() and Product.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Product");
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates Business Central items from an imported Shopify product and maps its variants to them.', Comment = 'is-IS=Býr til vörur í Business Central úr innfluttri Shopify vöru og varpar afbrigðum hennar á þær.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify create item, create item from shopify product, convert shopify product to item, map shopify product to item, create webshop item', Comment = 'is-IS=shopify stofna vöru, stofna vöru úr shopify vöru, breyta shopify vöru í vöru, varpa shopify vöru á vöru, stofna vefverslunarvöru';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to turn a Shopify product that is already imported into Business Central items. It does not contact Shopify, does not import products (use the product sync of the Shopify connector) and does not read products (use Data.Records.Get on table 30127).', Comment = 'is-IS=Notað til að breyta Shopify vöru sem þegar er innflutt í vörur í Business Central. Hefur ekki samband við Shopify, flytur ekki inn vörur (notaðu vörusamstillingu Shopify tengisins) og les ekki vörur (notaðu Data.Records.Get á töflu 30127).';
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
        Target.Add(ContractMgt.TargetEntry('Shpfy Product', 'data.productId', 'The Shopify product ID of an imported product (table 30127).'));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('productId', 'integer', true, 'The Id of an imported Shopify product, e.g. from Data.Records.Get on table 30127. The shop is taken from the product.'));
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
        Fields.Add(ContractMgt.ResponseField('productId', 'integer', 'The Shopify product ID.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop of the product.'));
        Fields.Add(ContractMgt.ResponseField('itemNo', 'string', 'The Business Central item the product is mapped to; empty when no item is mapped.'));
        Fields.Add(ContractMgt.ResponseField('variantsMapped', 'integer', 'Number of variants of the product that got mapped by this call.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'Parameter "productId" is required.', 'The request has no productId. Nothing was changed.', 'Send data.productId with the Id of the Shopify product.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'Parameter "productId" must be a positive whole number.', 'The value is not a Shopify product ID. Nothing was changed.', 'Send the Id of the Shopify product.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shopify product {id} was not found.', 'No imported product has this Id. Nothing was changed.', 'Read table 30127 with Data.Records.Get to find the product Id.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop {code} is not enabled.', 'The shop of the product is not enabled. Nothing was changed.', 'Enable the shop on the Shopify Shop Card.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'Can not create an item for product {id}.', 'Business Central refused: for example no item template is set for the shop, or the item template or SKU mapping is invalid. The text names the cause. Nothing was changed.', 'Fix the cause named in the text, for example the item template on the Shopify Shop Card, then call again.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The product is imported (table Shpfy Product) and its shop is enabled.');
        Preconditions.Add('The shop has an item template (or the product has a matching template by item category) and a valid SKU mapping.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs codeunit Shpfy Create Item (30171) for each variant of the product that has no item variant mapping: creates the item from the item template of the shop, sets description, unit of measure, price and cost, category and vendor from the product, creates item variants and item references (barcode, vendor item number) as the shop SKU mapping requires, and stores the mapping on the Shopify product and variants. Items that already exist for the SKU are mapped instead of created again. This call commits (Commit()) once before it starts the Shopify code, as the connector''s own product import does; the Shopify code itself does not commit, so a failure rolls back everything it created.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find imported products, table 30127 Shpfy Product, or read the created item, table 27.'));
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
        Examples.Add(ContractMgt.Example('Create the item of an imported Shopify product',
            '{"type":"Shopify.Product.CreateItem","data":{"productId":7890123456789}}',
            '{"status":"Success","productId":7890123456789,"shopCode":"WEBSHOP","itemNo":"1000","variantsMapped":1}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates Business Central items for the variants of one imported Shopify product and maps them, by running the Shopify connector codeunit Shpfy Create Item (30171), the code behind the Create Item action on Shopify Products, so the connector''s own validation and checks run.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Idempotent: a variant that is already mapped to an item is skipped and an item that already exists for the SKU is mapped instead of created again. The call does not contact Shopify and does not import products. The Shopify codeunit is internal to the connector, so it is started by its object ID; a future connector version that changes it may need an update of this type. Business Central refusals (for example a missing item template) are returned as a refusal and nothing is kept. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions and the right to create items.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates the request and creates the items through the Shopify connector.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Product: Record "Shpfy Product";
        Variant: Record "Shpfy Variant";
        Item: Record Item;
        CreateRun: Codeunit "Product CreateItem Run ori";
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        Token: JsonToken;
        ProductIdText: Text;
        ProductId: BigInteger;
        ItemNo: Code[20];
        MappedBefore: Integer;
        NoPermissionErr: Label 'You do not have the permissions to create items from Shopify products.', Comment = 'is-IS=Þú hefur ekki heimildir til að búa til vörur úr Shopify vörum.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the right to create items', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimild til að búa til vörur';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "productId" is required.', Comment = 'is-IS=Færibreytan "productId" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.productId with the Id of the Shopify product.', Comment = 'is-IS=Sendu data.productId með Id Shopify vörunnar.';
        ProductIdExpectedLbl: Label 'the Id of an imported Shopify product (a positive whole number)', Comment = 'is-IS=Id innfluttrar Shopify vöru (jákvæð heiltala)';
        InvalidErr: Label 'Parameter "productId" must be a positive whole number.', Comment = 'is-IS=Færibreytan "productId" verður að vera jákvæð heiltala.';
        InvalidNextLbl: Label 'Send the Id of the Shopify product.', Comment = 'is-IS=Sendu Id Shopify vörunnar.';
        NotFoundErr: Label 'Shopify product %1 was not found.', Comment = '%1 = Product Id||is-IS=Shopify vara %1 fannst ekki.';
        ExistingProductExpectedLbl: Label 'the Id of an imported Shopify product', Comment = 'is-IS=Id innfluttrar Shopify vöru';
        FindProductLbl: Label 'Read table 30127 with Data.Records.Get to find the product Id.', Comment = 'is-IS=Lestu töflu 30127 með Data.Records.Get til að finna Id vörunnar.';
        NotEnabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Verslun %1 er ekki virk.';
        EnabledExpectedLbl: Label 'a product of an enabled shop', Comment = 'is-IS=vara í virkri verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify Shop Card.';
        CreatedExpectedLbl: Label 'a product that Business Central can create items for', Comment = 'is-IS=vara sem Business Central getur búið til vörur fyrir';
        RefusedErr: Label 'Can not create an item for product %1. %2', Comment = '%1 = Product Id, %2 = detailed text||is-IS=Ekki er hægt að búa til vöru fyrir Shopify vöru %1. %2';
        FixCauseLbl: Label 'Fix the cause named in the text, for example the item template on the Shopify Shop Card, then call again.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir, til dæmis vörusniðmátið á Shopify Shop Card, og kallaðu aftur.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'productId', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('productId', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, MissingErr, 'productId', '', ProductIdExpectedLbl, MissingNextLbl);
            exit;
        end;
        ProductIdText := Argument.TokenAsText(Token);
        if not Evaluate(ProductId, ProductIdText, 9) or (ProductId <= 0) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, InvalidErr, 'productId', ProductIdText, ProductIdExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not Product.Get(ProductId) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(NotFoundErr, ProductIdText), 'productId', ProductIdText, ExistingProductExpectedLbl, FindProductLbl);
            exit;
        end;
        if not Shop.Get(Product."Shop Code") or not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Product."Shop Code"), 'productId', ProductIdText, EnabledExpectedLbl, EnableShopLbl);
            exit;
        end;

        Variant.SetRange("Product Id", ProductId);
        Variant.SetFilter("Item SystemId", '<>%1', NullGuidValue());
        MappedBefore := Variant.Count();

        // Commit first, as the connector's own product import does, so that a failure of the Shopify code in the
        // if statement below rolls back exactly what that code created and nothing before it.
        Commit();
        CreateRun.SetProductId(ProductId);
        ClearLastError();
        if not CreateRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, ProductIdText, GetLastErrorText()), 'productId', ProductIdText, CreatedExpectedLbl, FixCauseLbl);
            exit;
        end;

        Product.Get(ProductId);
        if not IsNullGuid(Product."Item SystemId") then
            if Item.GetBySystemId(Product."Item SystemId") then
                ItemNo := Item."No.";
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('productId', ProductId);
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('itemNo', ItemNo);
        ResponseJson.Add('variantsMapped', Variant.Count() - MappedBefore);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure NullGuidValue() NullGuid: Guid
    begin
    end;
}
