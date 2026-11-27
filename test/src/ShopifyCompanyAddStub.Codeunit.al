namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Microsoft.Sales.Customer;
using Origo.Bifrost.Shopify;

/// <summary>
/// Issue #19: stands in for the live Shopify API of report Shpfy Add Company to Shopify. Bound manually. Stores a company,
/// a main contact and a location for a customer that has none in the shop. A customer marked as failing is written and then
/// refused, so the caller's Run rolls the row back. A customer marked as pass-through is left to the connector report.
/// </summary>
codeunit 97528 "Shpfy Company Add Stub ori"
{
    EventSubscriberInstance = Manual;

    var
        FailCustomerNo: Code[20];
        PassThroughCustomerNo: Code[20];
        NextCompanyId: BigInteger;
        CannotExportErr: Label 'Stand-in: the connector cannot export customer %1.', Locked = true;

    /// <summary>The customer the stand-in writes and then refuses.</summary>
    /// <param name="CustomerNo">The customer number.</param>
    procedure SetFailCustomer(CustomerNo: Code[20])
    begin
        FailCustomerNo := CustomerNo;
    end;

    /// <summary>The customer the stand-in leaves to the connector report.</summary>
    /// <param name="CustomerNo">The customer number.</param>
    procedure SetPassThrough(CustomerNo: Code[20])
    begin
        PassThroughCustomerNo := CustomerNo;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Company Add Run ori", OnBeforeRunAddCompanyReport, '', false, false)]
    local procedure HandleAddCompany(ForShopCode: Code[20]; ForCustomerNo: Code[20]; var Handled: Boolean)
    var
        Customer: Record Customer;
        Company: Record "Shpfy Company";
    begin
        if (PassThroughCustomerNo <> '') and (ForCustomerNo = PassThroughCustomerNo) then
            exit;
        Customer.Get(ForCustomerNo);
        Company.SetRange("Shop Code", ForShopCode);
        Company.SetRange("Customer SystemId", Customer.SystemId);
        if not Company.IsEmpty() then begin
            Handled := true;
            exit;
        end;
        if ForCustomerNo = FailCustomerNo then begin
            InsertCompany(ForShopCode, Customer, Company);
            Error(CannotExportErr, ForCustomerNo);
        end;
        InsertCompany(ForShopCode, Customer, Company);
        InsertMainContact(ForShopCode, Customer, Company);
        InsertLocation(Customer, Company);
        Handled := true;
    end;

    local procedure InsertCompany(ShopCode: Code[20]; Customer: Record Customer; var Company: Record "Shpfy Company")
    var
        Shop: Record "Shpfy Shop";
    begin
        if NextCompanyId = 0 then
            NextCompanyId := 975280001;
        Company.Init();
        Company.Id := NextCompanyId;
        Company."Shop Code" := ShopCode;
        if Shop.Get(ShopCode) then
            Company."Shop Id" := Shop."Shop Id";
        Company.Name := Customer.Name;
        Company."External Id" := Customer."No.";
        Company."Customer SystemId" := Customer.SystemId;
        Company.Insert();
        NextCompanyId += 1;
    end;

    local procedure InsertMainContact(ShopCode: Code[20]; Customer: Record Customer; Company: Record "Shpfy Company")
    var
        Shop: Record "Shpfy Shop";
        ShopifyCustomer: Record "Shpfy Customer";
    begin
        ShopifyCustomer.Init();
        ShopifyCustomer.Id := Company.Id + 975280000;
        if Shop.Get(ShopCode) then
            ShopifyCustomer."Shop Id" := Shop."Shop Id";
        ShopifyCustomer."Customer SystemId" := Customer.SystemId;
        ShopifyCustomer.Email := Customer."E-Mail";
        ShopifyCustomer.Insert();
        Company."Main Contact Customer Id" := ShopifyCustomer.Id;
        Company.Modify();
    end;

    local procedure InsertLocation(Customer: Record Customer; Company: Record "Shpfy Company")
    var
        CompanyLocation: Record "Shpfy Company Location";
    begin
        CompanyLocation.Init();
        CompanyLocation.Id := Company.Id + 975281000;
        CompanyLocation."Company SystemId" := Company.SystemId;
        CompanyLocation.Name := Customer.Name;
        CompanyLocation.Default := true;
        CompanyLocation.Insert();
    end;
}
