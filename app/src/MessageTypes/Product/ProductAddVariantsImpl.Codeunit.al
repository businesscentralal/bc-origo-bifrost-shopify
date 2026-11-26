namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>Adds BC items as variants of an existing Shopify product through report 30117.</summary>
codeunit 73732050 "Product AddVariants Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        PermissionErr: Label 'You do not have permission to add Shopify variants.', Comment = 'is-IS=Þú hefur ekki heimild til að bæta við Shopify afbrigðum.';
        PermissionExpectedLbl: Label 'SHOPIFY Full ori and Microsoft Shopify write permissions', Comment = 'is-IS=SHOPIFY Full ori og skrifheimildir Microsoft Shopify';
        PermissionNextLbl: Label 'Ask an administrator to grant SHOPIFY Full ori and Shopify write permissions.', Comment = 'is-IS=Biddu kerfisstjóra um að veita SHOPIFY Full ori og skrifheimildir Shopify.';
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" er nauðsynleg.';
        UnknownKeyErr: Label 'Parameter "%1" is not supported.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" er ekki studd.';
        KeysExpectedLbl: Label 'productId, itemNos, expectedCount', Locked = true;
        IntegerErr: Label 'Parameter "%1" must be a positive whole number.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" verður að vera jákvæð heiltala.';
        IntegerExpectedLbl: Label 'a positive whole number', Comment = 'is-IS=jákvæð heiltala';
        RequiredNextLbl: Label 'Send productId, an array of 1 to 100 item numbers, and their exact expectedCount.', Comment = 'is-IS=Sendu productId, fylki með 1 til 100 vörunúmerum og réttan fjölda í expectedCount.';
        ItemsErr: Label 'Parameter "itemNos" must contain item numbers of 1 to 20 characters.', Comment = 'is-IS=Færibreytan "itemNos" verður að innihalda vörunúmer með 1 til 20 stöfum.';
        ItemsExpectedLbl: Label '1 to 100 existing item numbers and their exact count', Comment = 'is-IS=1 til 100 fyrirliggjandi vörunúmer og réttur fjöldi þeirra';
        CountErr: Label 'Provide 1 to 100 item numbers and an expectedCount equal to their count.', Comment = 'is-IS=Sendu 1 til 100 vörunúmer og expectedCount sem er jafn fjölda þeirra.';
        ProductMissingErr: Label 'Shopify product %1 was not found.', Comment = '%1 = product ID||is-IS=Shopify vara %1 fannst ekki.';
        ProductExpectedLbl: Label 'an imported Shopify product', Comment = 'is-IS=innflutt Shopify vara';
        ShopMissingErr: Label 'Shop %1 was not found.', Comment = '%1 = shop code||is-IS=Verslun %1 fannst ekki.';
        ShopDisabledErr: Label 'Shop %1 is not enabled.', Comment = '%1 = shop code||is-IS=Verslun %1 er ekki virk.';
        ShopExpectedLbl: Label 'an existing enabled shop', Comment = 'is-IS=fyrirliggjandi virk verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify Shop Card.';
        ItemMissingErr: Label 'Item %1 was not found.', Comment = '%1 = item number||is-IS=Vara %1 fannst ekki.';
        FindRecordsLbl: Label 'Read the product, shop and items with Data.Records.Get and correct the request.', Comment = 'is-IS=Lestu vöruna, verslunina og vörurnar með Data.Records.Get og leiðréttu beiðnina.';
        CanAddExpectedLbl: Label 'an item the connector can add as a variant', Comment = 'is-IS=vara sem tengillinn getur bætt við sem afbrigði';
        FixCauseLbl: Label 'Correct the connector refusal and retry only the remaining items; earlier successful items remain added.', Comment = 'is-IS=Leiðréttu höfnun tengilsins og reyndu aðeins vörurnar sem eftir eru; fyrri viðbætur haldast.';

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Variant: Record "Shpfy Variant";
        Product: Record "Shpfy Product";
    begin
        exit(Variant.WritePermission() and Product.WritePermission());
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
        DescriptionLbl: Label 'Adds Business Central items as variants of an existing Shopify product.', Comment = 'is-IS=Bætir Business Central vörum við sem afbrigðum af fyrirliggjandi Shopify vöru.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify add variants, add items as variants, existing shopify product variants, webshop variants, add product variant', Comment = 'is-IS=shopify bæta við afbrigðum, bæta vörum við sem afbrigðum, afbrigði fyrirliggjandi shopify vöru, vefverslunarafbrigði, bæta við vöruafbrigði';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to add items to an existing Shopify product as variants. Use Shopify.Product.AddItems to create new products.', Comment = 'is-IS=Notað til að bæta vörum við fyrirliggjandi Shopify vöru sem afbrigðum. Notaðu Shopify.Product.AddItems til að stofna nýjar vörur.';
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
        Parameters.Add(ContractMgt.Parameter('itemNos', 'array', true, 'One to 100 Business Central item numbers. Each item is processed separately.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Must equal the number of entries in itemNos.'));
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success or Error.'));
        Fields.Add(ContractMgt.ResponseField('productId', 'integer', 'The Shopify product ID.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'The shop of the product.'));
        Fields.Add(ContractMgt.ResponseField('itemsRequested', 'integer', 'Number of items in the request.'));
        Fields.Add(ContractMgt.ResponseField('variantsAdded', 'integer', 'Increase in variant rows for the product from successful items.'));
        Fields.Add(ContractMgt.ResponseField('results', 'array', 'Per processed item: itemNo, outcome (Added or Refused), message. Stops at the first refusal.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'productId, itemNos and expectedCount are required.', 'Send all required parameters.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has an invalid format.', 'Invalid ID, item array or count; nothing was changed.', 'Send a positive product ID, 1–100 item numbers and their exact expectedCount.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'An unknown parameter was supplied.', 'Only the documented keys are accepted.', 'Remove unknown keys.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'The product, shop or item was not found.', 'Nothing was changed.', 'Read the product, its shop and the requested items first.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'The shop is disabled.', 'Nothing was changed.', 'Enable the shop.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Write permission is required.', 'Nothing was changed.', 'Ask for SHOPIFY Full ori and Microsoft Shopify write permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, 'The connector refused the item.', 'The failing item is rolled back locally; earlier successful items remain added in Shopify and BC.', 'Read results and correct the cause before retrying only the remaining items.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('The imported product and its enabled shop exist; all 1–100 items exist and expectedCount matches.');
        Preconditions.Add('The connector shop and product settings allow adding variants, and the product remains under the connector limit of 2048 variants.');
        Effect.Add('effect', 'write');
        Effect.Add('changes', 'Runs report Shpfy Add Item As Variant (30117) once per item, with one exact Item No. filter and the parent product ID. Creates Shopify variants and local Shpfy Variant mappings. Commits once before starting; each successful runner transaction commits independently. Shopify is not transactional with BC: earlier successful items remain added after a refusal.');
        Effect.Add('idempotent', false);
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
        Examples.Add(ContractMgt.Example('Add two items as variants', '{"productId":123456,"itemNos":["1000","1001"],"expectedCount":2}',
            '{"status":"Success","productId":123456,"shopCode":"MAIN","itemsRequested":2,"variantsAdded":2,"results":[{"itemNo":"1000","outcome":"Added","message":""},{"itemNo":"1001","outcome":"Added","message":""}]}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Adds Business Central items as variants of an existing Shopify product through the connector report Shpfy Add Item As Variant (30117). This is a write in Shopify and Business Central. The shop comes from the product.';
        exit(true);
    end;

    /// <summary>Explains partial completion and retry behavior in the public English help.</summary>
    /// <param name="Notes">Receives the notes.</param>
    /// <returns>True.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Not idempotent as a batch: processing stops at the first refusal. An item already mapped as a variant of this product is refused without creating a duplicate. All parameters, items and the shop are validated before any write. Each item runs in its own rollback boundary. A failure rolls back the failing item in BC; Shopify is not transactional with BC, so an external write cannot be undone and earlier successful items stay added. Read results and retry only the remaining items. The connector performs its setup, blocked item and variant limit checks. Permissions: SHOPIFY Full ori plus Microsoft Shopify write permissions. No variants are removed. Connector source verified against installed 29.0.54011.55407 (minimum dependency 28.0).';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Validates all inputs, then adds one item per connector transaction.</summary>
    /// <param name="Argument">Licensed request and structured response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Product: Record "Shpfy Product";
        Shop: Record "Shpfy Shop";
        AddRun: Codeunit "Product AddVariants Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Results: JsonArray;
        ItemNos: List of [Code[20]];
        ItemNo: Code[20];
        ProductId: BigInteger;
        Added: Integer;
        Failure: Text;
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Refuse(Argument, "Bifrost Error Code ori"::PermissionDenied, PermissionErr, 'productId', '', PermissionExpectedLbl, PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not ValidateRequest(Argument, Request, ProductId, ItemNos) then
            exit;
        Product.SetLoadFields("Shop Code");
        if not Product.Get(ProductId) then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ProductMissingErr, ProductId), 'productId', Format(ProductId, 0, 9), ProductExpectedLbl, FindRecordsLbl);
            exit;
        end;
        Shop.SetLoadFields(Enabled);
        if not Shop.Get(Product."Shop Code") then begin
            Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopMissingErr, Product."Shop Code"), 'productId', Format(ProductId, 0, 9), ShopExpectedLbl, FindRecordsLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Refuse(Argument, "Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(ShopDisabledErr, Shop.Code), 'productId', Format(ProductId, 0, 9), ShopExpectedLbl, EnableShopLbl);
            exit;
        end;
        // The Boolean Run commits each successful item. No writes occur in this loop outside the runner.
        Added := 0;
        Commit();
        foreach ItemNo in ItemNos do begin
            Clear(AddRun);
            AddRun.SetItem(ProductId, ItemNo);
            ClearLastError();
            if not AddRun.Run() then begin
                Failure := GetLastErrorText();
                AddResult(Results, ItemNo, 'Refused', Failure);
                Refuse(Argument, "Bifrost Error Code ori"::BusinessCentralError, Failure, 'itemNos', ItemNo, CanAddExpectedLbl, FixCauseLbl);
                Response := Argument.GetResponseJson();
                SetSummary(Response, ProductId, Shop.Code, ItemNos.Count(), Added, Results);
                Argument.SetResponseJson(Response);
                exit;
            end;
            Added += AddRun.GetVariantsAdded();
            AddResult(Results, ItemNo, 'Added', '');
        end;
        Response.Add('status', 'Success');
        SetSummary(Response, ProductId, Shop.Code, ItemNos.Count(), Added, Results);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure ValidateRequest(var Argument: Record "Message Argument ori"; Request: JsonObject; var ProductId: BigInteger; var ItemNos: List of [Code[20]]): Boolean
    var
        Item: Record Item;
        Token: JsonToken;
        Items: JsonArray;
        ParameterName: Text;
        ItemText: Text;
        Serialized: Text;
        CountValue: BigInteger;
        ItemNo: Code[20];
    begin
        foreach ParameterName in Request.Keys() do
            if not (ParameterName in ['productId', 'itemNos', 'expectedCount']) then begin
                Refuse(Argument, "Bifrost Error Code ori"::UnknownParameter, StrSubstNo(UnknownKeyErr, ParameterName), ParameterName, '', KeysExpectedLbl, RequiredNextLbl);
                exit(false);
            end;
        if not ReadInteger(Argument, Request, 'productId', ProductId) then
            exit(false);
        if not ReadInteger(Argument, Request, 'expectedCount', CountValue) then
            exit(false);
        if not Request.Get('itemNos', Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, 'itemNos'), 'itemNos', '', ItemsExpectedLbl, RequiredNextLbl);
            exit(false);
        end;
        if not Token.IsArray() then begin
            InvalidItems(Argument);
            exit(false);
        end;
        Items := Token.AsArray();
        if (Items.Count() < 1) or (Items.Count() > 100) or (CountValue <> Items.Count()) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, CountErr, 'expectedCount', Format(CountValue, 0, 9), ItemsExpectedLbl, RequiredNextLbl);
            exit(false);
        end;
        foreach Token in Items do begin
            Token.WriteTo(Serialized);
            if not Token.IsValue() or (CopyStr(Serialized, 1, 1) <> '"') then begin
                InvalidItems(Argument);
                exit(false);
            end;
            ItemText := Token.AsValue().AsText();
            if (StrLen(ItemText) < 1) or (StrLen(ItemText) > MaxStrLen(ItemNo)) then begin
                InvalidItems(Argument);
                exit(false);
            end;
            ItemNo := CopyStr(ItemText, 1, MaxStrLen(ItemNo));
            Item.SetLoadFields("No.");
            if not Item.Get(ItemNo) then begin
                Refuse(Argument, "Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemMissingErr, ItemNo), 'itemNos', ItemNo, ItemsExpectedLbl, FindRecordsLbl);
                exit(false);
            end;
            ItemNos.Add(ItemNo);
        end;
        exit(true);
    end;

    local procedure ReadInteger(var Argument: Record "Message Argument ori"; Request: JsonObject; ParameterName: Text; var Value: BigInteger): Boolean
    var
        Token: JsonToken;
        Serialized: Text;
    begin
        if not Request.Get(ParameterName, Token) then begin
            Refuse(Argument, "Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, ParameterName), ParameterName, '', IntegerExpectedLbl, RequiredNextLbl);
            exit(false);
        end;
        Token.WriteTo(Serialized);
        if not Evaluate(Value, Serialized, 9) or (Value <= 0) then begin
            Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(IntegerErr, ParameterName), ParameterName, Serialized, IntegerExpectedLbl, RequiredNextLbl);
            exit(false);
        end;
        exit(true);
    end;

    local procedure InvalidItems(var Argument: Record "Message Argument ori")
    begin
        Refuse(Argument, "Bifrost Error Code ori"::InvalidParameterFormat, ItemsErr, 'itemNos', '', ItemsExpectedLbl, RequiredNextLbl);
    end;

    local procedure Refuse(var Argument: Record "Message Argument ori"; ErrorCode: Enum "Bifrost Error Code ori"; Message: Text; Parameter: Text; Received: Text; Expected: Text; NextStep: Text)
    begin
        Argument.RespondWithError(ErrorCode, Message, Parameter, Received, Expected, NextStep);
    end;

    local procedure AddResult(var Results: JsonArray; ItemNo: Code[20]; Outcome: Text; Message: Text)
    var
        Result: JsonObject;
    begin
        Result.Add('itemNo', ItemNo);
        Result.Add('outcome', Outcome);
        Result.Add('message', Message);
        Results.Add(Result);
    end;

    local procedure SetSummary(var Response: JsonObject; ProductId: BigInteger; ShopCode: Code[20]; Requested: Integer; Added: Integer; Results: JsonArray)
    begin
        Response.Add('productId', ProductId);
        Response.Add('shopCode', ShopCode);
        Response.Add('itemsRequested', Requested);
        Response.Add('variantsAdded', Added);
        Response.Add('results', Results);
    end;

}
