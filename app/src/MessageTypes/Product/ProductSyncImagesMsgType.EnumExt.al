namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732100 "Product SyncImages MsgType ori" extends "Message Type ori"
{
    value(73732100; "Shopify.Product.SyncImages")
    {
        Caption = 'Shopify.Product.SyncImages', Locked = true;
        Implementation = "Msg Interface ori" = "Product SyncImages Impl ori", "Msg Discovery ori" = "Product SyncImages Impl ori", "Msg Contract ori" = "Product SyncImages Impl ori";
    }
}
