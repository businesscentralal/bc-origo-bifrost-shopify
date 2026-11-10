namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 70013440 "Product SyncPrices MsgType ori" extends "Message Type ori"
{
    value(70013440; "Shopify.Product.SyncPrices")
    {
        Caption = 'Shopify.Product.SyncPrices', Locked = true;
        Implementation = "Msg Interface ori" = "Product SyncPrices Impl ori", "Msg Discovery ori" = "Product SyncPrices Impl ori", "Msg Contract ori" = "Product SyncPrices Impl ori";
    }
}
