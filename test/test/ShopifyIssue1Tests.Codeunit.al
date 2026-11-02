namespace Origo.Bifrost.Shopify.Test;

using Origo.Bifrost;
using System.TestLibraries.Utilities;

/// <summary>Issue #1: checks registry metadata and repeat-safe registration through Foundation.</summary>
codeunit 97400 "Shopify Issue 1 Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        LowerPermissions: Codeunit "Library - Lower Permissions";

    /// <summary>Checks that Shopify registration permits read-only Foundation setup with the licence-admin role in English.</summary>
    [Test]
    procedure LicenceAdminOpensSetupEnglish()
    begin
        AssertLicenceAdminSetup(1033);
    end;

    /// <summary>Checks that Shopify registration permits read-only Foundation setup with the licence-admin role in Icelandic.</summary>
    [Test]
    procedure LicenceAdminOpensSetupIcelandic()
    begin
        AssertLicenceAdminSetup(1039);
    end;

    /// <summary>Checks that installing the adapter makes its module visible to Foundation.</summary>
    [Test]
    procedure RegistryContainsShopify()
    var
        TempApps: Record "Registered App ori" temporary;
        Registry: Codeunit "App Registry ori";
        AppId: Guid;
    begin
        AppId := '61a67425-c1e2-45e1-85b5-9e01488f6c1d';
        Registry.GetApps(TempApps);
        TempApps.SetLoadFields("App Id");
        Assert.IsTrue(TempApps.Get(AppId), 'Bifrost Shopify must be registered.');
    end;

    /// <summary>Checks that repeated registry construction does not duplicate app metadata.</summary>
    [Test]
    procedure RegistryCanBeReadTwice()
    var
        TempApps: Record "Registered App ori" temporary;
        Registry: Codeunit "App Registry ori";
        FirstCount: Integer;
    begin
        Registry.GetApps(TempApps);
        FirstCount := TempApps.Count();
        Registry.GetApps(TempApps);
        Assert.AreEqual(FirstCount, TempApps.Count(), 'Registry reads must not duplicate entries.');
    end;

    /// <summary>Checks that an unknown module is not invented by registration.</summary>
    [Test]
    procedure RegistryDoesNotInventUnknownApp()
    var
        TempApps: Record "Registered App ori" temporary;
        Registry: Codeunit "App Registry ori";
    begin
        Registry.GetApps(TempApps);
        TempApps.SetLoadFields("App Id");
        Assert.IsFalse(TempApps.Get(CreateGuid()), 'An unknown module must not be registered.');
    end;

    local procedure AssertLicenceAdminSetup(LanguageId: Integer)
    var
        BifrostSetup: Record "Setup ori";
        TempApps: Record "Registered App ori" temporary;
        Registry: Codeunit "App Registry ori";
        SetupPage: TestPage "Setup ori";
        AppId: Guid;
        PreviousLanguage: Integer;
        PageEditable: Boolean;
        SyncVisible: Boolean;
        ShopifyRegistered: Boolean;
        HadWriteBefore: Boolean;
        HasWriteAfter: Boolean;
    begin
        AppId := '61a67425-c1e2-45e1-85b5-9e01488f6c1d';
        BifrostSetup.InsertIfNotExists();
        PreviousLanguage := GlobalLanguage();
        GlobalLanguage(LanguageId);

        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST LicAdm ori');
        HadWriteBefore := BifrostSetup.WritePermission();
        SetupPage.OpenView();
        PageEditable := SetupPage.Editable();
        SyncVisible := SetupPage.RefreshLicense.Visible();
        SetupPage.Close();
        Registry.GetApps(TempApps);
        TempApps.SetLoadFields("App Id");
        ShopifyRegistered := TempApps.Get(AppId);
        HasWriteAfter := BifrostSetup.WritePermission();
        LowerPermissions.StopLoggingNAVPermissions();
        GlobalLanguage(PreviousLanguage);

        Assert.IsTrue(ShopifyRegistered, 'Shopify must be registered for the exact licence-admin role.');
        Assert.IsFalse(PageEditable, 'A licence administrator must open read-only Foundation setup.');
        Assert.IsTrue(SyncVisible, 'Licence refresh must remain visible to the licence administrator.');
        Assert.IsFalse(HadWriteBefore, 'The licence-admin role must not grant persistent setup writes.');
        Assert.IsFalse(HasWriteAfter, 'Reading the registry must not grant persistent setup writes.');
    end;
}