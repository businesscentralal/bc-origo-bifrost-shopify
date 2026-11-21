namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732010 "Product Sync MsgType ori" extends "Message Type ori"
{
    value(73732010; "Shopify.Product.Sync")
    {
        Caption = 'Shopify.Product.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Product Sync Impl ori", "Msg Discovery ori" = "Product Sync Impl ori", "Msg Contract ori" = "Product Sync Impl ori";
    }
}
