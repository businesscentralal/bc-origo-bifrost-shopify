namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732040 "Product AddItems MsgType ori" extends "Message Type ori"
{
    value(73732040; "Shopify.Product.AddItems")
    {
        Caption = 'Shopify.Product.AddItems', Locked = true;
        Implementation = "Msg Interface ori" = "Product AddItems Impl ori", "Msg Discovery ori" = "Product AddItems Impl ori", "Msg Contract ori" = "Product AddItems Impl ori";
    }
}
