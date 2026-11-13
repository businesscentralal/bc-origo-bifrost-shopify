namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 70013460 "Product Sync MsgType ori" extends "Message Type ori"
{
    value(70013460; "Shopify.Product.Sync")
    {
        Caption = 'Shopify.Product.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Product Sync Impl ori", "Msg Discovery ori" = "Product Sync Impl ori", "Msg Contract ori" = "Product Sync Impl ori";
    }
}
