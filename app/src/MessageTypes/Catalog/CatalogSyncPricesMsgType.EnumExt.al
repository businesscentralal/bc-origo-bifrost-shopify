namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the catalog price write message.</summary>
enumextension 73732082 "Catalog SyncPrices MsgType ori" extends "Message Type ori"
{
    value(73732082; "Shopify.Catalog.SyncPrices")
    {
        Caption = 'Shopify.Catalog.SyncPrices', Locked = true;
        Implementation = "Msg Interface ori" = "Catalog SyncPrices Impl ori", "Msg Discovery ori" = "Catalog SyncPrices Impl ori", "Msg Contract ori" = "Catalog SyncPrices Impl ori";
    }
}
