namespace Origo.Bifrost.Shopify;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost;

/// <summary>Creates Shopify customers through report 30112, with preflight validation and per-customer rollback.</summary>
codeunit 73732140 "Customer Add Impl ori" implements "Msg Interface ori", "Msg Discovery ori", "Msg Contract ori"
{
    Access = Internal;

    /// <summary>Reports whether the caller holds the table permissions this message type needs.</summary>
    /// <returns>True when the permissions are held.</returns>
    procedure IsEnabled(): Boolean
    var
        Customer: Record Customer;
        Shop: Record "Shpfy Shop";
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        exit(Customer.ReadPermission() and Shop.ReadPermission() and ShopifyCustomer.WritePermission());
    end;

    /// <summary>Identifies the table used by the message filter contract.</summary>
    /// <returns>The table ID.</returns>
    procedure GetFilterTableNo(): Integer
    begin
        exit(Database::"Shpfy Shop");
    end;

    /// <summary>Describes the creation operation in the current language.</summary>
    /// <returns>Translated description.</returns>
    procedure GetDescription(): Text[250]
    var
        DescriptionLbl: Label 'Creates Shopify customers from selected Business Central customers and links them to one enabled shop.', Comment = 'is-IS=Stofnar Shopify viðskiptamenn úr völdum Business Central viðskiptamönnum og tengir þá við eina virka verslun.';
    begin
        exit(DescriptionLbl);
    end;

    /// <summary>Supplies translated search keywords.</summary>
    /// <returns>Comma-separated search terms.</returns>
    procedure GetKeywords(): Text
    var
        KeywordsLbl: Label 'shopify add customer, create shopify customer, export customer to shopify', Comment = 'is-IS=shopify bæta við viðskiptamanni, stofna shopify viðskiptamann, flytja viðskiptamann í shopify';
    begin
        exit(KeywordsLbl);
    end;

    /// <summary>Distinguishes customer creation from synchronization.</summary>
    /// <returns>Translated selection guidance.</returns>
    procedure GetSelectionDescription(): Text
    var
        SelectionLbl: Label 'Use to create Shopify customers from 1 to 100 selected Business Central customers. Existing links are left unchanged. Use Shopify.Customer.Sync to synchronize existing customers.', Comment = 'is-IS=Notað til að stofna Shopify viðskiptamenn úr 1 til 100 völdum Business Central viðskiptamönnum. Núverandi tengingar haldast óbreyttar. Notaðu Shopify.Customer.Sync til að samstilla núverandi viðskiptamenn.';
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
        Parameters.Add(ContractMgt.Parameter('shopCode', 'string', true, 'The code of an enabled Shopify shop (at most 20 characters).'));
        Parameters.Add(ContractMgt.Parameter('customerNos', 'array', true, '1 to 100 distinct Business Central customer numbers, each a nonblank string of at most 20 characters.'));
        Parameters.Add(ContractMgt.Parameter('expectedCount', 'integer', true, 'Must equal the customerNos array length; confirms the write selection.'));
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
        Fields.Add(ContractMgt.ResponseField('status', 'string', 'Success means the selection was processed; inspect failed and results for individual failures.'));
        Fields.Add(ContractMgt.ResponseField('shopCode', 'string', 'Destination shop.'));
        Fields.Add(ContractMgt.ResponseField('requested', 'integer', 'Number of selected customers.'));
        Fields.Add(ContractMgt.ResponseField('created', 'integer', 'New customer link rows in this shop.'));
        Fields.Add(ContractMgt.ResponseField('alreadyLinked', 'integer', 'Customers already linked before their turn; the connector is not called for these.'));
        Fields.Add(ContractMgt.ResponseField('failed', 'integer', 'Customers for which no link could be created.'));
        Fields.Add(ContractMgt.ResponseField('results', 'array', 'One row per customer: customerNo, outcome (created, alreadyLinked, failed), shopifyCustomerId (0 for failure), and error with connector text when failed.'));
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
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::MissingParameter, 'A required parameter is missing.', 'Nothing was changed.', 'Send shopCode, customerNos and expectedCount.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::InvalidParameterFormat, 'A parameter has an invalid format.', 'Nothing was changed.', 'Use a shop code, 1 to 100 distinct customer numbers and an integer expectedCount matching the array length.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::RecordNotFound, 'Shop or customer not found.', 'Nothing was changed.', 'Read tables 30102 and 18 with Data.Records.Get.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PreconditionFailed, 'Shop is disabled or expectedCount does not match.', 'Nothing was changed.', 'Enable the shop and confirm the complete selection count.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::PermissionDenied, 'Permission refused.', 'Nothing was changed.', 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify customer permissions.'));
        Errors.Add(ContractMgt.ErrorEntry("Bifrost Error Code ori"::UnknownParameter, 'Unknown parameter.', 'Foundation refuses undeclared keys before execution.', 'Send only the declared parameters.'));
        exit(true);
    end;

    /// <summary>Supplies the effect chapter for this message type.</summary>
    /// <param name="Effect">Out: effect, changes, idempotency and preconditions.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetEffect(var Effect: JsonObject): Boolean
    var
        Preconditions: JsonArray;
    begin
        Preconditions.Add('Enabled shop, existing selected customers, expectedCount matching 1 to 100 distinct customer numbers, and SHOPIFY Full ori plus Microsoft Shopify permissions.');
        Effect.Add('effect', 'write');
        Effect.Add('description', 'Creates customers in Shopify and local links through report 30112. Each customer has a separate local rollback boundary; earlier successful customers remain. Remote Shopify writes cannot be rolled back.');
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
        Related.Add(ContractMgt.RelatedEntry('Data.Records.Get', 'You need to find the shop, table 30102 Shpfy Shop, or read the synchronized customers, table 30105 Shpfy Customer.'));
        exit(true);
    end;

    /// <summary>Declares that this implementation supplies no workflow chapter.</summary>
    /// <param name="Workflow">Unchanged.</param>
    /// <returns>False.</returns>
    procedure GetWorkflow(var Workflow: JsonObject): Boolean
    begin
        exit(false);
    end;

    /// <summary>Returns the examples for this message type; the request and answer JSON keeps its stable keys.</summary>
    /// <param name="Examples">Out: request and answer pairs.</param>
    /// <returns>True; examples are supplied.</returns>
    procedure GetExamples(var Examples: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Examples.Add(ContractMgt.Example('Create one Shopify customer',
            '{"type":"Shopify.Customer.Add","data":{"shopCode":"WEBSHOP","customerNos":["C00010"],"expectedCount":1}}',
            '{"status":"Success","shopCode":"WEBSHOP","requested":1,"created":1,"alreadyLinked":0,"failed":0,"results":[{"customerNo":"C00010","outcome":"created","shopifyCustomerId":12345}]}'));
        exit(true);
    end;

    /// <summary>Summarizes the operation.</summary>
    /// <param name="Overview">Out: the overview.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetOverview(var Overview: Text): Boolean
    begin
        Overview := 'Creates Shopify customers from selected Business Central customers through connector report 30112 Shpfy Add Customer to Shopify. Country ISO mapping, name splitting and customer matching follow the connector and shop settings.';
        exit(true);
    end;

    /// <summary>Explains the rules and limits of the operation.</summary>
    /// <param name="Notes">Out: the notes.</param>
    /// <returns>True; the chapter was supplied.</returns>
    procedure GetNotes(var Notes: Text): Boolean
    begin
        Notes := 'Effect: write in Shopify and Business Central customer links (table 30105). All inputs and all customer numbers are checked before the first write. Existing links in the selected shop are reported as alreadyLinked without running the connector; another shop does not count. Duplicates after Business Central code normalization are refused. Each new customer runs in a separate transaction with explicit connector commits ignored. A connector error or missing link rolls back local writes for that customer and returns failed with the connector error or a fresh Shopify Skipped Record reason. If logging is disabled or the connector exposes no reason, the result tells you to review logging and skipped records. The other customers continue. Repeating a completed call creates no second customer for existing links. Completed remote Shopify writes cannot be undone by local rollback; after a connection failure check Shopify before retrying. No page is opened. Permissions: SHOPIFY Full ori plus Microsoft Shopify customer permissions.';
        exit(true);
    end;

    /// <summary>Classifies the message direction for Foundation.</summary>
    /// <returns>The direction of the operation.</returns>
    procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Inbound);
    end;

    /// <summary>Preflights the entire selection, then processes each customer in its own rollback boundary.</summary>
    /// <param name="Argument">Licensed request and response.</param>
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        Shop: Record "Shpfy Shop";
        Customer: Record Customer;
        AddRun: Codeunit "Customer Add Run ori";
        Request: JsonObject;
        Response: JsonObject;
        Result: JsonObject;
        Results: JsonArray;
        Token: JsonToken;
        CustomerNos: List of [Code[20]];
        CustomerNo: Code[20];
        ShopCode: Text;
        ExpectedCount: Integer;
        Created: Integer;
        AlreadyLinked: Integer;
        Failed: Integer;
        CustomerId: BigInteger;
        Outcome: Text;
        ErrorText: Text;
        MissingErr: Label 'Parameter "%1" is required.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" er nauðsynleg.';
        InvalidErr: Label 'Parameter "%1" has an invalid value.', Comment = '%1 = parameter||is-IS=Færibreytan "%1" hefur ógilt gildi.';
        InputNextLbl: Label 'Send shopCode as text, customerNos as 1 to 100 distinct customer numbers, and expectedCount as the matching integer.', Comment = 'is-IS=Sendu shopCode sem texta, customerNos sem 1 til 100 ólík viðskiptamannanúmer og expectedCount sem samsvarandi heiltölu.';
        PermissionErr: Label 'You do not have permission to add Shopify customers.', Comment = 'is-IS=Þú hefur ekki heimild til að bæta við Shopify viðskiptamönnum.';
        PermissionNextLbl: Label 'Ask an administrator for SHOPIFY Full ori and Microsoft Shopify customer permissions.', Comment = 'is-IS=Biddu kerfisstjóra um SHOPIFY Full ori og Microsoft Shopify heimildir fyrir viðskiptamenn.';
        ShopMissingErr: Label 'Shopify shop %1 was not found.', Comment = '%1 = shop||is-IS=Shopify verslun %1 fannst ekki.';
        CustomerMissingErr: Label 'Customer %1 was not found.', Comment = '%1 = customer number||is-IS=Viðskiptamaður %1 fannst ekki.';
        FindNextLbl: Label 'Read tables 30102 and 18 with Data.Records.Get to find the shop and customers.', Comment = 'is-IS=Lestu töflur 30102 og 18 með Data.Records.Get til að finna verslun og viðskiptamenn.';
        DisabledErr: Label 'Shopify shop %1 is not enabled.', Comment = '%1 = shop||is-IS=Shopify verslun %1 er ekki virk.';
        EnableNextLbl: Label 'Enable the shop on the Shopify Shop Card.', Comment = 'is-IS=Virkjaðu verslunina á Shopify verslunarspjaldinu.';
        CountErr: Label 'expectedCount must equal the number of customerNos (%1).', Comment = '%1 = array count||is-IS=expectedCount verður að vera jafnt fjölda customerNos (%1).';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();
        if not IsEnabled() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PermissionDenied, PermissionErr, '', '', '', PermissionNextLbl);
            exit;
        end;
        Request := Argument.GetRequestJson();
        if not Request.Get('shopCode', Token) then begin
            RefuseInput(Argument, 'shopCode', MissingErr, InputNextLbl, true);
            exit;
        end;
        if not ReadCode(Token, ShopCode) then begin
            RefuseInput(Argument, 'shopCode', InvalidErr, InputNextLbl, false);
            exit;
        end;
        if not Request.Get('customerNos', Token) then begin
            RefuseInput(Argument, 'customerNos', MissingErr, InputNextLbl, true);
            exit;
        end;
        if not ReadCustomerNos(Token, CustomerNos) then begin
            RefuseInput(Argument, 'customerNos', InvalidErr, InputNextLbl, false);
            exit;
        end;
        if not Request.Get('expectedCount', Token) then begin
            RefuseInput(Argument, 'expectedCount', MissingErr, InputNextLbl, true);
            exit;
        end;
        if not ReadExpectedCount(Token, ExpectedCount) then begin
            RefuseInput(Argument, 'expectedCount', InvalidErr, InputNextLbl, false);
            exit;
        end;
        if ExpectedCount <> CustomerNos.Count() then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(CountErr, CustomerNos.Count()), 'expectedCount', Format(ExpectedCount, 0, 9), '', InputNextLbl);
            exit;
        end;
        Shop.SetLoadFields(Code, Enabled, "Shop Id");
        if not Shop.Get(CopyStr(ShopCode, 1, 20)) then begin
            Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(ShopMissingErr, ShopCode), 'shopCode', ShopCode, '', FindNextLbl);
            exit;
        end;
        if not Shop.Enabled then begin
            Argument.RespondWithError("Bifrost Error Code ori"::PreconditionFailed, StrSubstNo(DisabledErr, Shop.Code), 'shopCode', Shop.Code, '', EnableNextLbl);
            exit;
        end;
        Customer.SetLoadFields("No.", SystemId);
        foreach CustomerNo in CustomerNos do
            if not Customer.Get(CustomerNo) then begin
                Argument.RespondWithError("Bifrost Error Code ori"::RecordNotFound, StrSubstNo(CustomerMissingErr, CustomerNo), 'customerNos', CustomerNo, '', FindNextLbl);
                exit;
            end;

        // All validation precedes the first commit or connector invocation.
        Commit();
        foreach CustomerNo in CustomerNos do begin
            Customer.Get(CustomerNo);
            CustomerId := FindCustomerId(Shop."Shop Id", Customer.SystemId);
            ErrorText := '';
            if CustomerId <> 0 then begin
                Outcome := 'alreadyLinked';
                AlreadyLinked += 1;
            end else begin
                Clear(AddRun);
                AddRun.SetParameters(Shop.Code, CustomerNo);
                ClearLastError();
                if AddRun.Run() then begin
                    CustomerId := FindCustomerId(Shop."Shop Id", Customer.SystemId);
                    Outcome := 'created';
                    Created += 1;
                end else begin
                    ErrorText := GetLastErrorText();
                    Outcome := 'failed';
                    Failed += 1;
                end;
            end;
            Clear(Result);
            Result.Add('customerNo', CustomerNo);
            Result.Add('outcome', Outcome);
            Result.Add('shopifyCustomerId', CustomerId);
            if ErrorText <> '' then
                Result.Add('error', ErrorText);
            Results.Add(Result);
        end;
        Response.Add('status', 'Success');
        Response.Add('shopCode', Shop.Code);
        Response.Add('requested', CustomerNos.Count());
        Response.Add('created', Created);
        Response.Add('alreadyLinked', AlreadyLinked);
        Response.Add('failed', Failed);
        Response.Add('results', Results);
        Argument.SetResponseJson(Response);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure RefuseInput(var Argument: Record "Message Argument ori"; ParameterName: Text; MessageTemplate: Text; NextStep: Text; Missing: Boolean)
    begin
        if Missing then
            Argument.RespondWithError("Bifrost Error Code ori"::MissingParameter, StrSubstNo(MessageTemplate, ParameterName), ParameterName, '', '', NextStep)
        else
            Argument.RespondWithError("Bifrost Error Code ori"::InvalidParameterFormat, StrSubstNo(MessageTemplate, ParameterName), ParameterName, '', '', NextStep);
    end;

    local procedure ReadCode(Token: JsonToken; var Value: Text): Boolean
    begin
        if not Token.IsValue() then
            exit(false);
        if Token.AsValue().IsNull() then
            exit(false);
        Token.WriteTo(Value);
        if not Value.StartsWith('"') then
            exit(false);
        Value := Token.AsValue().AsText();
        exit((Value.Trim() <> '') and (StrLen(Value) <= 20));
    end;

    local procedure ReadCustomerNos(Token: JsonToken; var CustomerNos: List of [Code[20]]): Boolean
    var
        Element: JsonToken;
        Value: Text;
        CustomerNo: Code[20];
    begin
        if not Token.IsArray() then
            exit(false);
        if (Token.AsArray().Count() < 1) or (Token.AsArray().Count() > 100) then
            exit(false);
        foreach Element in Token.AsArray() do begin
            if not ReadCode(Element, Value) then
                exit(false);
            CustomerNo := CopyStr(Value, 1, MaxStrLen(CustomerNo));
            if CustomerNos.Contains(CustomerNo) then
                exit(false);
            CustomerNos.Add(CustomerNo);
        end;
        exit(true);
    end;

    local procedure ReadExpectedCount(Token: JsonToken; var ExpectedCount: Integer): Boolean
    var
        Value: Text;
    begin
        if not Token.IsValue() then
            exit(false);
        Token.WriteTo(Value);
        // Reject quoted numbers, booleans, fractions, exponent notation and out-of-range values without exceptions.
        if (Value = '') or (DelChr(Value, '=', '0123456789') <> '') then
            exit(false);
        if not Evaluate(ExpectedCount, Value, 9) then
            exit(false);
        exit((ExpectedCount >= 1) and (ExpectedCount <= 100));
    end;

    local procedure FindCustomerId(ShopId: Integer; CustomerSystemId: Guid): BigInteger
    var
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        ShopifyCustomer.SetLoadFields(Id);
        ShopifyCustomer.SetRange("Shop Id", ShopId);
        ShopifyCustomer.SetRange("Customer SystemId", CustomerSystemId);
        ShopifyCustomer.SetFilter(Id, '>0');
        if ShopifyCustomer.FindFirst() then
            exit(ShopifyCustomer.Id);
        exit(0);
    end;
}
