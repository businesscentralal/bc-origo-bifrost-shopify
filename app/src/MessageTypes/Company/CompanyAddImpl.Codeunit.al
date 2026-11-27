namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>
/// Implementation of <c>Shopify.Company.Add</c>. Creates Shopify B2B companies from selected Business Central customers
/// through the Shopify connector report Shpfy Add Company to Shopify (30113).
/// </summary>
codeunit 73732070 "Company Add Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    var
        MaxCustomersTok: Label '100', Locked = true;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
        Company: Record "Shpfy Company";
        CompanyLocation: Record "Shpfy Company Location";
    begin
        exit(Customer.ReadPermission() and Shop.ReadPermission() and Company.WritePermission() and CompanyLocation.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::Customer);
    end;

    /// <summary>Describes this message type for callers selecting an operation.</summary>
    /// <returns>The description in the current language.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates Shopify companies from selected Business Central customers.', Comment = 'is-IS=Stofnar Shopify fyrirtæki úr völdum viðskiptavinum í Business Central.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Search terms users say for this type, English with the Icelandic translation.</summary>
    /// <returns>Comma-separated keywords in the current language.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify add company, add customer as company, create shopify company, b2b company from customer, add company to shopify', Comment = 'is-IS=shopify bæta við fyrirtæki, bæta viðskiptavini við sem fyrirtæki, stofna shopify fyrirtæki, b2b fyrirtæki úr viðskiptavini, bæta fyrirtæki við shopify';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>What separates this type from its siblings when a caller is choosing one.</summary>
    /// <returns>One sentence.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to create a Shopify company, with a main contact and a location, from a Business Central customer. It does not import companies (use Shopify.Company.Sync) and does not add a customer as a location of a company that already exists.', Comment = 'is-IS=Notað til að stofna Shopify fyrirtæki, með aðaltengilið og staðsetningu, úr viðskiptavini í Business Central. Flytur ekki inn fyrirtæki (notaðu Shopify.Company.Sync) og bætir ekki viðskiptavini við sem staðsetningu fyrirtækis sem þegar er til.';
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
        ShopTargetLbl: Label 'The code of the Shopify shop (table 30102) the companies are created in.', Comment = 'is-IS=Kóði Shopify verslunarinnar (tafla 30102) sem fyrirtækin eru stofnuð í.';
        CustomerTargetLbl: Label 'The numbers of the Business Central customers (table 18) to create as companies.', Comment = 'is-IS=Númer viðskiptavinanna í Business Central (tafla 18) sem á að stofna sem fyrirtæki.';
    begin
        Target.Add(ContractMgt.TargetEntry('Shpfy Shop', 'data.shopCode', ShopTargetLbl));
        Target.Add(ContractMgt.TargetEntry('Customer', 'data.customerNos', CustomerTargetLbl));
        exit(true);
    end;

    /// <summary>Declares accepted request parameters.</summary>
    /// <param name="Parameters">Receives the parameter declarations.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        ShopCodeParamLbl: Label 'The code of an enabled Shopify shop, e.g. from Data.Records.Get on table 30102.', Comment = 'is-IS=Kóði virkrar Shopify verslunar, t.d. úr Data.Records.Get á töflu 30102.';
        CustomerNosParamLbl: Label 'Array of 1 to %1 customer numbers (text, at most 20 characters each), e.g. ["10000","20000"]. Every customer must exist. A repeated number is kept once. expectedCount is the length of the array as sent.', Comment = '%1 = maximum number of customers||is-IS=Fylki með 1 til %1 viðskiptavinarnúmerum (texti, mest 20 stafir hvert), t.d. ["10000","20000"]. Allir viðskiptavinirnir verða að vera til. Endurtekið númer er geymt einu sinni. expectedCount er lengd fylkisins eins og það er sent.';
        ExpectedCountParamLbl: Label 'Integer equal to the number of entries in customerNos, including any repeat. The call is refused when it differs.', Comment = 'is-IS=Heiltala jöfn fjölda færslna í customerNos, að meðtöldum endurtekningum. Kallinu er hafnað þegar hún er önnur.';
    begin
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, ShopCodeParamLbl));
        Parameters.Add(ContractMgt.Parameter('customerNos', 'array', true, StrSubstNo(CustomerNosParamLbl, MaxCustomersTok)));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, ExpectedCountParamLbl));
        exit(true);
    end;

    /// <summary>Supplies the response chapter for this message type.</summary>
    /// <param name="Response">Out: the response fields.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetResponse(var Response: JsonObject): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
        Fields: JsonArray;
        StatusLbl: Label 'Success. A customer the connector could not export is failed inside results and does not fail the call.', Comment = 'is-IS=Success (tókst). Viðskiptavinur sem tengillinn gat ekki flutt út er failed inni í results og fellir ekki kallið.';
        ShopCodeLbl: Label 'The Shopify shop code.', Comment = 'is-IS=Kóði Shopify verslunarinnar.';
        RequestedLbl: Label 'Number of distinct customers in the request.', Comment = 'is-IS=Fjöldi einstakra viðskiptavina í beiðninni.';
        CreatedLbl: Label 'Number of customers that got a new Shopify company by this call.', Comment = 'is-IS=Fjöldi viðskiptavina sem fékk nýtt Shopify fyrirtæki í þessu kalli.';
        AlreadyLinkedLbl: Label 'Number of customers that already had a company in this shop. No second company was created.', Comment = 'is-IS=Fjöldi viðskiptavina sem þegar áttu fyrirtæki í þessari verslun. Ekkert annað fyrirtæki var stofnað.';
        FailedLbl: Label 'Number of customers the connector could not export.', Comment = 'is-IS=Fjöldi viðskiptavina sem tengillinn gat ekki flutt út.';
        ResultsLbl: Label 'One entry per distinct customer: customerNo, outcome (created, alreadyLinked or failed), shopifyCompanyId (0 when failed) and message (the connector text when failed, otherwise empty).', Comment = 'is-IS=Ein færsla fyrir hvern einstakan viðskiptavin: customerNo, outcome (created, alreadyLinked eða failed), shopifyCompanyId (0 þegar failed) og message (texti tengilsins þegar failed, annars autt).';
    begin
        Fields.Add(ContractMgt.ResponseField('status', 'string', StatusLbl));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', ShopCodeLbl));
        Fields.Add(ContractMgt.ResponseField('requested', 'integer', RequestedLbl));
        Fields.Add(ContractMgt.ResponseField('created', 'integer', CreatedLbl));
        Fields.Add(ContractMgt.ResponseField('alreadyLinked', 'integer', AlreadyLinkedLbl));
        Fields.Add(ContractMgt.ResponseField('failed', 'integer', FailedLbl));
        Fields.Add(ContractMgt.ResponseField('results', 'array', ResultsLbl));
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
        MissingWhenLbl: Label 'The request has no shopCode, no customerNos or no expectedCount. Nothing was changed.', Comment = 'is-IS=Beiðnin hefur ekkert shopCode, ekkert customerNos eða ekkert expectedCount. Engu var breytt.';
        MissingNextLbl: Label 'Send data.shopCode, data.customerNos and data.expectedCount.', Comment = 'is-IS=Sendu data.shopCode, data.customerNos og data.expectedCount.';
        InvalidMsgLbl: Label 'Parameter "{name}" has an invalid value.', Comment = 'is-IS=Færibreytan "{name}" hefur ógilt gildi.';
        InvalidWhenLbl: Label 'shopCode is empty or longer than 20 characters, customerNos is not an array of 1 to 100 customer numbers of at most 20 characters, or expectedCount is not an integer equal to the length of customerNos. Nothing was changed.', Comment = 'is-IS=shopCode er autt eða lengra en 20 stafir, customerNos er ekki fylki með 1 til 100 viðskiptavinarnúmerum, mest 20 stafir hvert, eða expectedCount er ekki heiltala jöfn lengd customerNos. Engu var breytt.';
        InvalidNextLbl: Label 'Send the shop code as text, the customer numbers as an array of text, and expectedCount as the number of entries in that array.', Comment = 'is-IS=Sendu kóða verslunarinnar sem texta, viðskiptavinarnúmerin sem fylki af texta og expectedCount sem fjölda færslna í því fylki.';
        NotFoundMsgLbl: Label 'Shopify shop {code} or customer {no} was not found.', Comment = 'is-IS=Shopify verslun {code} eða viðskiptavinur {no} fannst ekki.';
        NotFoundWhenLbl: Label 'No shop has this code, or one of the customer numbers is not a customer. Nothing was changed.', Comment = 'is-IS=Engin verslun hefur þennan kóða, eða eitt viðskiptavinarnúmeranna er ekki viðskiptavinur. Engu var breytt.';
        NotFoundNextLbl: Label 'Read table 30102 (shops) or table 18 (customers) with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 (verslanir) eða töflu 18 (viðskiptavinir) með Data.Records.Get.';
        NotEnabledMsgLbl: Label 'Shopify shop {code} is not enabled.', Comment = 'is-IS=Shopify verslun {code} er ekki virk.';
        NotEnabledWhenLbl: Label 'The shop is not enabled. Nothing was changed.', Comment = 'is-IS=Verslunin er ekki virk. Engu var breytt.';
        NotEnabledNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        PermissionMsgLbl: Label 'You do not have the permissions to add companies to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að bæta fyrirtækjum við Shopify.';
        PermissionWhenLbl: Label 'The caller does not hold SHOPIFY Full ori. Nothing was changed.', Comment = 'is-IS=Sá sem kallar heldur ekki SHOPIFY Full ori. Engu var breytt.';
        PermissionNextLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
    begin
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, MissingMsgLbl, MissingWhenLbl, MissingNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, InvalidMsgLbl, InvalidWhenLbl, InvalidNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, NotFoundMsgLbl, NotFoundWhenLbl, NotFoundNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, NotEnabledMsgLbl, NotEnabledWhenLbl, NotEnabledNextLbl));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, PermissionMsgLbl, PermissionWhenLbl, PermissionNextLbl));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
        ShopEnabledLbl: Label 'The shop exists and is enabled.', Comment = 'is-IS=Verslunin er til og er virk.';
        CustomersExistLbl: Label 'Every requested customer exists. A customer without an e-mail address is not created; the connector logs the skip and this call reports that customer as failed.', Comment = 'is-IS=Allir umbeðnir viðskiptavinir eru til. Viðskiptavinur án netfangs er ekki stofnaður; tengillinn skráir að honum sé sleppt og þetta kall skilar honum sem failed.';
        ChangesLbl: Label 'Runs report Shpfy Add Company to Shopify (30113) once per customer, with create companies on: for a customer that has no company in this shop it creates the company in Shopify with a main contact and a location and stores the company and the location in Business Central. A company is looked up by customer within the shop, so a company in another shop does not block this one. Each customer runs in its own Run, and a failure rolls that customer back. A customer the connector cannot export is failed with the connector text and the others continue. This call commits after each customer that the connector finished.', Comment = 'is-IS=Keyrir skýrslu Shpfy Add Company to Shopify (30113) einu sinni fyrir hvern viðskiptavin, með stofnun fyrirtækja á: fyrir viðskiptavin sem hefur ekkert fyrirtæki í þessari verslun stofnar hún fyrirtækið í Shopify með aðaltengilið og staðsetningu og vistar fyrirtækið og staðsetninguna í Business Central. Fyrirtæki er flett upp eftir viðskiptavini innan verslunarinnar, svo fyrirtæki í annarri verslun stöðvar ekki þessa. Hver viðskiptavinur keyrir í eigin Run og villa afturkallar þann viðskiptavin. Viðskiptavinur sem tengillinn getur ekki flutt út er failed með texta tengilsins og hinir halda áfram. Þetta kall staðfestir eftir hvern viðskiptavin sem tengillinn kláraði.';
    begin
        Preconditions.Add(ShopEnabledLbl);
        Preconditions.Add(CustomersExistLbl);
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
        FindLbl: Label 'You need to find the shop (table 30102), the customers (table 18) or the companies created (table 30150).', Comment = 'is-IS=Þú þarft að finna verslunina (tafla 30102), viðskiptavinina (tafla 18) eða fyrirtækin sem voru stofnuð (tafla 30150).';
        SyncLbl: Label 'You need to import companies that already exist in Shopify.', Comment = 'is-IS=Þú þarft að flytja inn fyrirtæki sem þegar eru til í Shopify.';
    begin
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', FindLbl));
        Related.Add(ContractMgt.RelatedEntry('Shopify.Company.Sync', SyncLbl));
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
        Examples.Add(ContractMgt.Example('Create companies for two customers',
            '{"type":"Shopify.Company.Add","data":{"shopCode":"MAIN","customerNos":["10000","20000"],"expectedCount":2}}',
            '{"status":"Success","shopCode":"MAIN","requested":2,"created":1,"alreadyLinked":1,"failed":0,"results":[{"customerNo":"10000","outcome":"created","shopifyCompanyId":7890123456789,"message":""},{"customerNo":"20000","outcome":"alreadyLinked","shopifyCompanyId":7890123450000,"message":""}]}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates Shopify companies from selected Business Central customers by running the connector report Shpfy Add Company to Shopify (30113) for each customer, so the connector''s own checks run. Effect: write. Idempotent: a customer that already has a company in this shop is left unchanged (alreadyLinked) and a second call does not create a second company. A company in another shop does not count as linked.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Effect: write; it creates companies in Shopify, each with a main contact and a location, and the company and location rows in Business Central. Idempotent: a repeat call reports alreadyLinked and does not create a second company. The connector looks the company up by the customer within the shop, so the same customer can have a company in another shop. A customer the connector cannot export, for example one with no e-mail address, is failed with the connector''s text; the others still run, and a failure rolls back that customer so no half-made row remains. Missing, invalid or unknown keys, an unknown shop or customer, an expectedCount that is not the length of customerNos, a disabled shop and a caller without permission are refused before anything changes. Permissions: SHOPIFY Full ori, plus the Microsoft Shopify permissions for companies.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    /// <summary>Validates the request and creates a Shopify company for each customer through the connector report.</summary>
    /// <param name="Argument">The licensed request; receives the response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        AddRun: Codeunit "Company Add Run ori";
        CustomerNos: List of [Code[20]];
        RequestJson: JsonObject;
        ResponseJson: JsonObject;
        ResultsJson: JsonArray;
        ResultJson: JsonObject;
        Token: JsonToken;
        ShopCodeText: Text;
        TokenText: Text;
        FailureText: Text;
        CustomerNo: Code[20];
        CompanyIdBefore: BigInteger;
        CompanyId: BigInteger;
        RawCount: Integer;
        ExpectedCount: Integer;
        Requested: Integer;
        Created: Integer;
        AlreadyLinked: Integer;
        Failed: Integer;
        Outcome: Text;
        NoPermissionErr: Label 'You do not have the permissions to add companies to Shopify.', Comment = 'is-IS=Þú hefur ekki heimildir til að bæta fyrirtækjum við Shopify.';
        PermissionExpectedLbl: Label 'a user with the permission set SHOPIFY Full ori and the Shopify Connector permissions', Comment = 'is-IS=notandi með heimildasettið SHOPIFY Full ori og heimildir Shopify Connector';
        AskAdminLbl: Label 'Ask an administrator to assign the permission set SHOPIFY Full ori.', Comment = 'is-IS=Biddu kerfisstjóra um að úthluta heimildasettinu SHOPIFY Full ori.';
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" er nauðsynleg.';
        MissingNextLbl: Label 'Send data.shopCode, data.customerNos and data.expectedCount.', Comment = 'is-IS=Sendu data.shopCode, data.customerNos og data.expectedCount.';
        ShopExpectedLbl: Label 'a shop code of at most 20 characters', Comment = 'is-IS=kóði verslunar, mest 20 stafir';
        CustomersExpectedLbl: Label 'an array of 1 to %1 customer numbers of at most 20 characters', Comment = '%1 = maximum number of customers||is-IS=fylki með 1 til %1 viðskiptavinarnúmerum, mest 20 stafir hvert';
        CountExpectedLbl: Label 'an integer equal to the number of entries in customerNos', Comment = 'is-IS=heiltala jöfn fjölda færslna í customerNos';
        InvalidErr: Label 'Parameter "%1" has an invalid value.', Comment = '%1 = parameter name||is-IS=Færibreytan "%1" hefur ógilt gildi.';
        InvalidNextLbl: Label 'Send the shop code as text, the customer numbers as an array of text, and expectedCount as the number of entries in that array.', Comment = 'is-IS=Sendu kóða verslunarinnar sem texta, viðskiptavinarnúmerin sem fylki af texta og expectedCount sem fjölda færslna í því fylki.';
        ShopNotFoundErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 fannst ekki.';
        ExistingShopLbl: Label 'the code of an existing Shopify shop', Comment = 'is-IS=kóði Shopify verslunar sem er til';
        FindShopLbl: Label 'Read table 30102 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 30102 með Data.Records.Get.';
        CustomerNotFoundErr: Label 'Customer %1 was not found.', Comment = '%1 = Customer No.||is-IS=Viðskiptavinur %1 fannst ekki.';
        ExistingCustomerLbl: Label 'the number of an existing customer', Comment = 'is-IS=númer viðskiptavinar sem er til';
        FindCustomerLbl: Label 'Read table 18 with Data.Records.Get.', Comment = 'is-IS=Lestu töflu 18 með Data.Records.Get.';
        NotEnabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = Shop code||is-IS=Shopify verslun %1 er ekki virk.';
        EnabledShopLbl: Label 'an enabled Shopify shop', Comment = 'is-IS=virk Shopify verslun';
        EnableShopLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        NoSkipTextErr: Label 'The connector did not create a company for customer %1.', Comment = '%1 = Customer No.||is-IS=Tengillinn stofnaði ekki fyrirtæki fyrir viðskiptavin %1.';
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
        if not RequestJson.Get('customerNos', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, 'customerNos'), 'customerNos', '', StrSubstNo(CustomersExpectedLbl, MaxCustomersTok), MissingNextLbl);
            exit;
        end;
        if not ReadCustomerNos(Token, CustomerNos, RawCount) then begin
            Token.WriteTo(TokenText);
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, 'customerNos'), 'customerNos', CopyStr(TokenText, 1, 250), StrSubstNo(CustomersExpectedLbl, MaxCustomersTok), InvalidNextLbl);
            exit;
        end;
        if not RequestJson.Get('expectedCount', Token) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MissingErr, 'expectedCount'), 'expectedCount', '', CountExpectedLbl, MissingNextLbl);
            exit;
        end;
        if not TryReadInteger(Token, ExpectedCount) then begin
            Token.WriteTo(TokenText);
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, 'expectedCount'), 'expectedCount', CopyStr(TokenText, 1, 250), CountExpectedLbl, InvalidNextLbl);
            exit;
        end;
        if ExpectedCount <> RawCount then begin
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(InvalidErr, 'expectedCount'), 'expectedCount', Format(ExpectedCount, 0, 9), CountExpectedLbl, InvalidNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Code, Enabled);
        if not Shop.Get(CopyStr(ShopCodeText, 1, MaxStrLen(Shop.Code))) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopNotFoundErr, ShopCodeText), 'shopCode', ShopCodeText, ExistingShopLbl, FindShopLbl);
            exit;
        end;
        Customer.SetLoadFields("No.", SystemId);
        foreach CustomerNo in CustomerNos do
            if not Customer.Get(CustomerNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(CustomerNotFoundErr, CustomerNo), 'customerNos', CustomerNo, ExistingCustomerLbl, FindCustomerLbl);
                exit;
            end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(NotEnabledErr, Shop.Code), 'shopCode', Shop.Code, EnabledShopLbl, EnableShopLbl);
            exit;
        end;

        foreach CustomerNo in CustomerNos do begin
            Customer.Get(CustomerNo);
            CompanyIdBefore := FindCompanyId(Shop.Code, Customer.SystemId);
            AddRun.SetParameters(Shop.Code, Customer."No.");
            // Commit first, as the other Shopify message types do, so the Run below is its own transaction.
            // A failure then rolls back only what that run wrote, and the customers already finished stay.
            Commit();
            ClearLastError();
            if not AddRun.Run() then begin
                // The failed Run already rolled this customer back. Do not read the database here:
                // a connector error leaves the transaction stopped, and a further read would hide the connector text.
                FailureText := GetLastErrorText();
                CompanyId := CompanyIdBefore;
                Outcome := 'failed';
                Failed += 1;
            end else begin
                CompanyId := FindCompanyId(Shop.Code, Customer.SystemId);
                FailureText := '';
                if CompanyIdBefore <> 0 then begin
                    Outcome := 'alreadyLinked';
                    CompanyId := CompanyIdBefore;
                    AlreadyLinked += 1;
                end else
                    if CompanyId <> 0 then begin
                        Outcome := 'created';
                        Created += 1;
                    end else begin
                        Outcome := 'failed';
                        FailureText := FindSkippedReason(Customer);
                        if FailureText = '' then
                            FailureText := StrSubstNo(NoSkipTextErr, Customer."No.");
                        Failed += 1;
                    end;
                Commit();
            end;
            Requested += 1;
            Clear(ResultJson);
            ResultJson.Add('customerNo', CustomerNo);
            ResultJson.Add('outcome', Outcome);
            ResultJson.Add('shopifyCompanyId', CompanyId);
            ResultJson.Add('message', FailureText);
            ResultsJson.Add(ResultJson);
        end;

        ResponseJson.Add('status', 'Success');
        ResponseJson.Add('shopCode', Shop.Code);
        ResponseJson.Add('requested', Requested);
        ResponseJson.Add('created', Created);
        ResponseJson.Add('alreadyLinked', AlreadyLinked);
        ResponseJson.Add('failed', Failed);
        ResponseJson.Add('results', ResultsJson);
        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    /// <summary>Reads customerNos: an array of 1 to 100 non-empty texts of at most 20 characters. Duplicates are kept once. RawCount is the array length as sent.</summary>
    /// <param name="Token">The customerNos token.</param>
    /// <param name="CustomerNos">The distinct customer numbers.</param>
    /// <param name="RawCount">The array length, including duplicates.</param>
    /// <returns>True when the array is in range and every entry is a customer number.</returns>
    local procedure ReadCustomerNos(Token: JsonToken; var CustomerNos: List of [Code[20]]; var RawCount: Integer): Boolean
    var
        Element: JsonToken;
        CustomerNoText: Text;
    begin
        RawCount := 0;
        if not Token.IsArray() then
            exit(false);
        RawCount := Token.AsArray().Count();
        if (RawCount = 0) or (RawCount > 100) then
            exit(false);
        foreach Element in Token.AsArray() do begin
            if not Element.IsValue() then
                exit(false);
            if Element.AsValue().IsNull() then
                exit(false);
            CustomerNoText := Element.AsValue().AsText();
            if (CustomerNoText = '') or (StrLen(CustomerNoText) > 20) then
                exit(false);
            if not CustomerNos.Contains(CopyStr(UpperCase(CustomerNoText), 1, 20)) then
                CustomerNos.Add(CopyStr(UpperCase(CustomerNoText), 1, 20));
        end;
        exit(true);
    end;

    /// <summary>Reads a JSON integer. A string, a boolean, a null or a fraction is not an integer.</summary>
    /// <param name="Token">The token to read.</param>
    /// <param name="Value">The integer.</param>
    /// <returns>True when the token is an integer.</returns>
    [TryFunction]
    local procedure TryReadInteger(Token: JsonToken; var Value: Integer)
    var
        Number: Decimal;
    begin
        if not Token.IsValue() then
            Error('');
        if Token.AsValue().IsNull() then
            Error('');
        Number := Token.AsValue().AsDecimal();
        if Number <> Round(Number, 1) then
            Error('');
        Value := Number;
    end;

    /// <summary>Returns the Shopify company id linked to the customer in the shop, or 0 when there is none.</summary>
    /// <param name="ShopCode">The Shopify shop code.</param>
    /// <param name="CustomerSystemId">The customer system id.</param>
    /// <returns>The company id, or 0.</returns>
    local procedure FindCompanyId(ShopCode: Code[20]; CustomerSystemId: Guid): BigInteger
    var
        Company: Record "Shpfy Company";
    begin
        Company.SetLoadFields(Id);
        Company.SetRange("Shop Code", ShopCode);
        Company.SetRange("Customer SystemId", CustomerSystemId);
        if Company.FindFirst() then
            exit(Company.Id);
        exit(0);
    end;

    /// <summary>Returns the connector's skip text for the customer, or empty when the connector logged none.</summary>
    /// <param name="Customer">The customer the connector skipped.</param>
    /// <returns>The skipped reason.</returns>
    local procedure FindSkippedReason(Customer: Record Customer): Text
    var
        Skipped: RecordRef;
        RecordIdField: FieldRef;
        ReasonField: FieldRef;
    begin
        // Table 30159 Shpfy Skipped Record is internal to the connector. Field 5 is Record ID, field 7 is Skipped Reason.
        Skipped.Open(30159);
        Skipped.SetLoadFields(7);
        RecordIdField := Skipped.Field(5);
        RecordIdField.SetRange(Customer.RecordId);
        if Skipped.FindLast() then begin
            ReasonField := Skipped.Field(7);
            exit(ReasonField.Value);
        end;
        exit('');
    end;
}
