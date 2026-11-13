namespace Origo.Bifrost.Shopify;

/// <summary>Grants the adapter's action surface; callers must also hold Microsoft Shopify permissions.</summary>
permissionset 73731952 "SHOPIFY Full ori"
{
    Assignable = true;
    Caption = 'Bifrost Shopify Full', MaxLength = 30, Comment = 'is-IS=Bifröst Shopify allur aðgangur';
    IncludedPermissionSets = "SHOPIFY Read ori";
    Permissions = codeunit "Product CreateItem Impl ori" = X,
                  codeunit "Product CreateItem Run ori" = X;
}