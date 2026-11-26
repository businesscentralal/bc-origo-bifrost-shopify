namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Inventory.Item;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Product.AddItems</c>. Adds a selection of Business Central items to one Shopify shop as products,
/// through the Shopify connector report Shpfy Add Item to Shopify (30106), the code behind the action Add Items on Shopify Products.
/// </summary>
codeunit 73732040 "Product AddItems Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        MaxItemsTok: Label '100', Locked = true;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Item: Record Item;
        Product: Record "Shpfy Product";
    begin
        exit(Item.ReadPermission() and Product.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Item);
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Adds selected Business Central items to a Shopify shop as products.', Comment = 'is-IS=Bætir völdum vörum úr Business Central við Shopify verslun sem vörum.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify add items, add item to shopify, publish item to shopify, create shopify product from item, put items in webshop', Comment = 'is-IS=shopify bæta við vörum, bæta vöru við shopify, birta vöru í shopify, stofna shopify vöru úr vöru, setja vörur í vefverslun';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to create Shopify products from Business Central items. It does not create items from Shopify products (use Shopify.Product.CreateItem) and does not sync products that are already in the shop (use Shopify.Product.Sync).', Comment = 'is-IS=Notað til að stofna Shopify vörur úr vörum í Business Central. Stofnar ekki vörur úr Shopify vörum (notaðu Shopify.Product.CreateItem) og samstillir ekki vörur sem þegar eru í versluninni (notaðu Shopify.Product.Sync).';
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
    /// <param name="Target">Out: the records the request addresses.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetTarget(var Target: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopTargetLbl: Label 'The code of the Shopify shop (table 30102) the items are added to.', Comment = 'is-IS=Kóði Shopify verslunarinnar (tafla 30102) sem vörunum er bætt við.';
        ItemTargetLbl: Label 'The numbers of the Business Central items (table 27) to add.', Comment = 'is-IS=Númer varanna í Business Central (tafla 27) sem á að bæta við.';
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', ShopTargetLbl));
        Target.Add(ContractMgt.TargetEntry('Item', 'data.itemNos', ItemTargetLbl));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopCodeParamLbl: Label 'The code of an enabled Shopify shop, e.g. from Data.Records.Get on table 30102.', Comment = 'is-IS=Kóði virkrar Shopify verslunar, t.d. úr Data.Records.Get á töflu 30102.';
        ItemNosParamLbl: Label 'Array of 1 to %1 item numbers (text, at most 20 characters each), e.g. ["1896-S","1900-S"]. Every item must exist.', Comment = '%1 = maximum number of items||is-IS=Fylki með 1 til %1 vörunúmerum (texti, mest 20 stafir hvert), t.d. ["1896-S","1900-S"]. Allar vörurnar verða að vera til.';
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, ShopCodeParamLbl));
        Parameters.Add(ContractMgt.Parameter('itemNos', 'array', true, StrSubstNo(ItemNosParamLbl, MaxItemsTok)));
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the response fields.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success.', Comment = 'is-IS=Success (tókst).';
        ShopCodeLbl: Label 'The Shopify shop code.', Comment = 'is-IS=Kóði Shopify verslunarinnar.';
        ItemsAddedLbl: Label 'Number of requested items that got a Shopify product by this call.', Comment = 'is-IS=Fjöldi umbeðinna vara sem fengu Shopify vöru í þessu kalli.';
        ItemsLbl: Label 'One entry per requested item: itemNo, productId (0 when the item has no product in the shop) and result: Added (added by this call), AlreadyInShop (had a product before; left unchanged) or NotAdded (the connector skipped it, e.g. blocked, sales blocked or no description; see Shopify Skipped Records).', Comment = 'is-IS=Ein færsla fyrir hverja umbeðna vöru: itemNo, productId (0 þegar varan hefur enga vöru í versluninni) og result: Added (bætt við í þessu kalli), AlreadyInShop (hafði vöru fyrir; óbreytt) eða NotAdded (tengillinn sleppti henni, t.d. lokuð, lokuð fyrir sölu eða án lýsingar; sjá Shopify Skipped Records).';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', ShopCodeLbl));
        Fields.Add(ContractMgt.ResponseField('itemsAdded', 'integer', ItemsAddedLbl));
        Fields.Add(ContractMgt.ResponseField('items', 'array', ItemsLbl));
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
        MissingMsgLbl: Label 'Parameter "{name}" is required.', Comment = 'is-IS=Færibreytan "{name}" er nauðsynleg.';
        MissingWhenLbl: Label 'The request has no shopCode or no itemNos. Nothing was changed.', Comment = 'is-IS=Beiðnin hefur ekkert shopCode eða ekkert itemNos. Engu var breytt.';
        MissingNextLbl: Label 'Send data.shopCode and data.itemNos.', Comment = 'is-IS=Sendu data.shopCode og data.itemNos.';
        InvalidMsgLbl: Label 'Parameter "{name}" has an invalid value.', Comment = 'is-IS=Færibreytan "{name}" hefur ógilt gildi.';
        InvalidWhenLbl: Label 'shopCode is empty or longer than 20 characters, or itemNos is not an array of 1 to 100 item numbers of at most 20 characters. Nothing was changed.', Comment = 'is-IS=shopCode er autt eða lengra en 20 stafir, eða itemNos er ekki fylki með 1 til 100 vörunúmerum, mest 20 stafir hvert. Engu var breytt.';
        InvalidNextLbl: Label 'Send the shop code as text and the item numbers as an array of text.', Comment = 'is-IS=Sendu kóða verslunarinnar sem texta og vörunúmerin sem fylki af texta.';
        NotFoundMsgLbl: Label 'Shopify shop {code} or item {no} was not found.', Comment = 'is-IS=Shopify verslun {code} eða vara {no} fannst ekki.';
        NotFoundWhenLbl: Label 'No shop has this code, or one of the item numbers is not an item. Nothing was changed.', Comment = 'is-IS=Engin verslun hefur þennan kóða, eða eitt vörunúmeranna er ekki vara. Engu var breytt.';
        NotFoundNextLbl: Label 'Read table 30102 (shops) or table 27 (items) with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 (verslanir) eða töflu 27 (vörur) með Data.Records.Get.';
        NotEnabledMsgLbl: Label 'Shopify shop {code} is not enabled.', Comment = 'is-IS=Shopify verslun {code} er ekki virk.';
        NotEnabledWhenLbl: Label 'The shop is not enabled. Nothing was changed.', Comment = 'is-IS=Verslunin er ekki virk. Engu var breytt.';
        NotEnabledNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        RefusedMsgLbl: Label 'Can not add the items to Shopify shop {code}.', Comment = 'is-IS=Ekki er hægt að bæta vörunum við Shopify verslun {code}.';
        RefusedWhenLbl: Label 'Business Central or Shopify refused, for example the shop has a fulfillment-service default location but no SKU mapping, or Shopify cannot be reached. The text names the cause. Product records written after the connector''s commit are rolled back.', Comment = 'is-IS=Business Central eða Shopify hafnaði, til dæmis hefur verslunin sjálfgefna staðsetningu afgreiðsluþjónustu en enga SKU vörpun, eða ekki næst samband við Shopify. Textinn nefnir orsökina. Vörufærslur skrifaðar eftir staðfestingu tengilsins eru afturkallaðar.';
        RefusedNextLbl: Label 'Fix the cause named in the text, then call again; items already in the shop are not added twice.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur; vörum sem þegar eru í versluninni er ekki bætt við tvisvar.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingMsgLbl, MissingWhenLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidMsgLbl, InvalidWhenLbl, InvalidNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundMsgLbl, NotFoundWhenLbl, NotFoundNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotEnabledMsgLbl, NotEnabledWhenLbl, NotEnabledNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::BusinessCentralError, RefusedMsgLbl, RefusedWhenLbl, RefusedNextLbl));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ShopEnabledLbl: Label 'The shop exists and is enabled, with a working connection to Shopify.', Comment = 'is-IS=Verslunin er til og er virk, með virka tengingu við Shopify.';
        ItemsExistLbl: Label 'Every requested item exists. Blocked, sales-blocked items and items without a description are skipped by the connector.', Comment = 'is-IS=Allar umbeðnar vörur eru til. Tengillinn sleppir lokuðum vörum, vörum lokuðum fyrir sölu og vörum án lýsingar.';
        SkuMappingLbl: Label 'When the shop''s default product location is a fulfillment service, the shop has an SKU mapping.', Comment = 'is-IS=Þegar sjálfgefin vörustaðsetning verslunarinnar er afgreiðsluþjónusta hefur verslunin SKU vörpun.';
        ChangesLbl: Label 'Runs the connector report Shpfy Add Item to Shopify (30106) for the shop and the requested items, with Sync Images and Sync Inventory off: for each item that has no product in the shop it creates the product with its variants in Shopify (or maps an existing Shopify variant found by SKU or barcode) and stores it in Shopify Products and Variants; skipped items are logged in Shopify Skipped Records. This call commits (Commit()) once before it starts the report; the connector commits once more after it syncs the shop locations at the first item. A failure after that rolls back the product records of this call, while products already created in Shopify stay there and are mapped again by the next call.', Comment = 'is-IS=Keyrir skýrslu tengilsins Shpfy Add Item to Shopify (30106) fyrir verslunina og umbeðnar vörur, með Sync Images og Sync Inventory af: fyrir hverja vöru sem hefur enga vöru í versluninni stofnar hún vöruna með afbrigðum í Shopify (eða varpar Shopify afbrigði sem finnst eftir SKU eða strikamerki) og vistar hana í Shopify Products og Variants; vörur sem er sleppt eru skráðar í Shopify Skipped Records. Þetta kall staðfestir (Commit()) einu sinni áður en skýrslan byrjar; tengillinn staðfestir aftur eftir að hann samstillir staðsetningar verslunarinnar við fyrstu vöruna. Villa eftir það afturkallar vörufærslur þessa kalls, en vörur sem þegar voru stofnaðar í Shopify verða þar áfram og næsta kall varpar þeim aftur.';
    begin
        Preconditions.Add(ShopEnabledLbl);
        Preconditions.Add(ItemsExistLbl);
        Preconditions.Add(SkuMappingLbl);
        Effect.Add('effect', 'write');
        Effect.Add('changes', ChangesLbl);
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
        FindLbl: Label 'You need to find the shop (table 30102), the items (table 27) or the products created (table 30127).', Comment = 'is-IS=Þú þarft að finna verslunina (tafla 30102), vörurnar (tafla 27) eða vörurnar sem voru stofnaðar (tafla 30127).';
        SyncLbl: Label 'You need to send later changes of the items to Shopify.', Comment = 'is-IS=Þú þarft að senda síðari breytingar á vörunum til Shopify.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', FindLbl));
        Related.Add(ContractMgt.RelatedEntry('Shopify.Product.Sync', SyncLbl));
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
        Examples.Add(ContractMgt.Example('Add two items to a Shopify shop',
            '{"type":"Shopify.Product.AddItems","data":{"shopCode":"MAIN","itemNos":["1896-S","1900-S"]}}',
            '{"status":"Success","shopCode":"MAIN","itemsAdded":1,"items":[{"itemNo":"1896-S","productId":7890123456789,"result":"Added"},{"itemNo":"1900-S","productId":7890123450000,"result":"AlreadyInShop"}]}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    var
        OverviewLbl: Label 'Adds selected Business Central items to one Shopify shop as products by running the connector report Shpfy Add Item to Shopify (30106), the code behind the action Add Items on Shopify Products, so the connector''s own checks and mapping rules run.', Comment = 'is-IS=Bætir völdum vörum úr Business Central við eina Shopify verslun sem vörum með því að keyra skýrslu tengilsins Shpfy Add Item to Shopify (30106), kóðann á bak við aðgerðina Add Items á Shopify Products, svo athuganir og vörpunarreglur tengilsins keyra.';
    begin
        Overview := OverviewLbl;
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    var
        NotesLbl: Label 'Effect: write; it creates products in Shopify. Idempotent: an item that already has a product in the shop is left unchanged (AlreadyInShop), and a Shopify variant found by SKU or barcode is mapped instead of created again. Blocked or sales-blocked items and items without a description are not refused but skipped (NotAdded) and logged in Shopify Skipped Records. Images and inventory are not synced by this call; use Shopify.Inventory.Sync for stock. Missing, invalid or unknown keys, an unknown shop or item and a disabled shop are refused before anything changes. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for products.', Comment = 'is-IS=Áhrif: skrif; stofnar vörur í Shopify. Endurtekningaröruggt (idempotent): vara sem þegar hefur vöru í versluninni er óbreytt (AlreadyInShop), og Shopify afbrigði sem finnst eftir SKU eða strikamerki er varpað í stað þess að stofna það aftur. Lokuðum vörum, vörum lokuðum fyrir sölu og vörum án lýsingar er ekki hafnað heldur sleppt (NotAdded) og þær skráðar í Shopify Skipped Records. Myndir og birgðir eru ekki samstilltar í þessu kalli; notaðu Shopify.Inventory.Sync fyrir birgðir. Vantandi, ógildum eða óþekktum lyklum, óþekktri verslun eða vöru og óvirkri verslun er hafnað áður en nokkru er breytt. Heimildir: SHOPIFY Full ori, auk Microsoft Shopify heimilda fyrir vörur.';
    begin
        Notes := NotesLbl;
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and adds the items to the shop through the Shopify connector report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Item: Record Item;
        AddRun: Codeunit "Product AddItems Run ori";
        ItemNos: List of [Code[20]];
        ProductsBefore: Dictionary of [Code[20], BigInteger];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ItemsJson: JsonArray;
        ItemJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        TokenText: Text;
        ItemNo: Code[20];
        ProductId: BigInteger;
        ItemsAdded: Integer;
        Result: Text;
        NoPermissionErr: Label 'You do not have the permissions to add items to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að bæta vörum við Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode and data.itemNos.', Comment = 'is-IS=Sendu data.shopCode og data.itemNos.';
        ShopExpectedLbl: Label 'a shop code of at most 20 characters', Comment = 'is-IS=kóði verslunar, mest 20 stafir';
        ItemsExpectedLbl: Label 'an array of 1 to %1 item numbers of at most 20 characters', Comment = '%1 = maximum number of items||is-IS=fylki með 1 til %1 vörunúmerum, mest 20 stafir hvert';
        InvalidErr: Label 'Parameter "%1" has an invalid value.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" hefur ógilt gildi.';
        InvalidNextLbl: Label 'Send the shop code as text and the item numbers as an array of text.', Comment = 'is-IS=Sendu kóða verslunarinnar sem texta og vörunúmerin sem fylki af texta.';
        ShopNotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði Shopify verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get.';
        ItemNotFoundErr: Label 'Item %1 was not found.', Comment = '%1 = Item No.||is-IS=Vara %1 fannst ekki.';
        ExistingItemLbl: Label 'the number of an existing item', Comment = 'is-IS=númer vöru sem er til';
        FindItemLbl: Label 'Read table 27 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 27 með Data.Records.Get.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled Shopify shop', Comment = 'is-IS=virk Shopify verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        RefusedErr: Label 'Can not add the items to Shopify shop %1. %2', Comment = '%1 = Shop code, %2 = detailed text||is-IS=Ekki er hægt að bæta vörunum við Shopify verslun %1. %2';
        AddExpectedLbl: Label 'items the connector can add to the shop', Comment = 'is-IS=vörur sem tengillinn getur bætt við verslunina';
        FixCauseLbl: Label 'Fix the cause named in the text, then call again; items already in the shop are not added twice.', Comment = 'is-IS=Lagaðu orsökina sem textinn nefnir og kallaðu aftur; vörum sem þegar eru í versluninni er ekki bætt við tvisvar.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, NoPermissionErr, 'shopCode', '', PermissionExpectedLbl, AskAdminLbl);
            exit;
        end;
        RequestJson := Argument.GetRequestJson();
        if not RequestJson.Get('shopCode', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, 'shopCode'), 'shopCode', '', ShopExpectedLbl, MissingNextLbl);
            exit;
        end;
        ShopCodeText := Argument.TokenAsText(Token);
        if (ShopCodeText = '') or (StrLen(ShopCodeText) > MaxStrLen(Shop.Code)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, 'shopCode'), 'shopCode', ShopCodeText, ShopExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if not RequestJson.Get('itemNos', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, 'itemNos'), 'itemNos', '', StrSubstNo(ItemsExpectedLbl, MaxItemsTok), MissingNextLbl);
            exit;
        end;
        if not ReadItemNos(Token, ItemNos) then begin
            Token.WriteTo(TokenText);
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, 'itemNos'), 'itemNos', CopyStr(TokenText, 1, 250), StrSubstNo(ItemsExpectedLbl, MaxItemsTok), InvalidNextLbl);
            exit;
        end;
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopNotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopLbl, FindShopLbl);
            exit;
        end;
        foreach ItemNo in ItemNos do
            if not Item.Get(ItemNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ItemNotFoundErr, ItemNo), 'itemNos', ItemNo, ExistingItemLbl, FindItemLbl);
                exit;
            end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledShopLbl, EnableShopLbl);
            exit;
        end;

        foreach ItemNo in ItemNos do
            ProductsBefore.Add(ItemNo, FindProductId(Shop.Code, ItemNo));

        // Commit first, so that a failure of the connector report started in the if statement below rolls back exactly what
        // that report wrote after its own commit and nothing before it.
        Commit();
        AddRun.SetParameters(Shop.Code, BuildItemView(ItemNos));
        ClearLastError();
        if not AddRun.Run() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::BusinessCentralError, StrSubstNo(RefusedErr, Shop.Code, GetLastErrorText()), 'shopCode', Shop.Code, AddExpectedLbl, FixCauseLbl);
            exit;
        end;

        foreach ItemNo in ItemNos do begin
            ProductId := FindProductId(Shop.Code, ItemNo);
            case true of
                ProductsBefore.Get(ItemNo) <> 0:
                    Result := 'AlreadyInShop';
                ProductId <> 0:
                    begin
                        Result := 'Added';
                        ItemsAdded += 1;
                    end;
                else
                    Result := 'NotAdded';
            end;
            Clear(ItemJson);
            ItemJson.Add('itemNo', ItemNo);
            ItemJson.Add('productId', ProductId);
            ItemJson.Add('result', Result);
            ItemsJson.Add(ItemJson);
        end;
        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('itemsAdded', ItemsAdded);
        ResponseJson.Add('items', ItemsJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Reads itemNos: an array of 1 to 100 non-empty texts of at most 20 characters; duplicates are kept once.</summary>
    local procedure ReadItemNos(Token: JsonToken; var ItemNos: List of [Code[20]]): Boolean
    var
        Element: JsonToken;
        ItemNoText: Text;
        MaxItems: Integer;
    begin
        if not Token.IsArray() then
            exit(false);
        Evaluate(MaxItems, MaxItemsTok);
        if (Token.AsArray().Count() = 0) or (Token.AsArray().Count() > MaxItems) then
            exit(false);
        foreach Element in Token.AsArray() do begin
            if not Element.IsValue() then
                exit(false);
            if Element.AsValue().IsNull() then
                exit(false);
            ItemNoText := Element.AsValue().AsText();
            if (ItemNoText = '') or (StrLen(ItemNoText) > 20) then
                exit(false);
            if not ItemNos.Contains(CopyStr(UpperCase(ItemNoText), 1, 20)) then
                ItemNos.Add(CopyStr(UpperCase(ItemNoText), 1, 20));
        end;
        exit(true);
    end;

    /// <summary>Builds a view of table Item that selects exactly the given item numbers; values are passed as filter parameters, so filter characters in a number are taken literally.</summary>
    local procedure BuildItemView(ItemNos: List of [Code[20]]): Text
    var
        Item: Record Item;
        ItemNo: Code[20];
    begin
        foreach ItemNo in ItemNos do
            if Item.GetFilter("No.") = '' then
                Item.SetFilter("No.", '%1', ItemNo)
            else
                Item.SetFilter("No.", Item.GetFilter("No.") + '|%1', ItemNo);
        exit(Item.GetView());
    end;

    /// <summary>Returns the Shopify product ID of the item in the shop, or 0 when it has none.</summary>
    local procedure FindProductId(ShopCode: Code[20]; ItemNo: Code[20]): BigInteger
    var
        Item: Record Item;
        Product: Record "Shpfy Product";
    begin
        if not Item.Get(ItemNo) then
            exit(0);
        Product.SetRange("Shop Code", ShopCode);
        Product.SetRange("Item SystemId", Item.SystemId);
        if Product.FindFirst() then
            exit(Product.Id);
        exit(0);
    end;
}
