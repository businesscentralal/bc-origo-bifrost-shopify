namespace Origo.Bifrost.Shopify;

/// <summary>Grants the adapter's read surface without Microsoft business-data write permissions.</summary>
permissionset 70013401 "SHOPIFY Read ori"
{
    Assignable = true;
    Caption = 'Bifrost Shopify Read', MaxLength = 30, Comment = 'is-IS=Bifröst Shopify lestur';
    IncludedPermissionSets = "SHOPIFY Base ori";
}