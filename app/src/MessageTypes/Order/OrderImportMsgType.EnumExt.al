namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 70013410 "Order Import MsgType ori" extends "Message Type ori"
{
    value(70013410; "Shopify.Order.Import")
    {
        Caption = 'Shopify.Order.Import', Locked = true;
        Implementation = "Msg Interface ori" = "Order Import Impl ori", "Msg Discovery ori" = "Order Import Impl ori", "Msg Contract ori" = "Order Import Impl ori";
    }
}
