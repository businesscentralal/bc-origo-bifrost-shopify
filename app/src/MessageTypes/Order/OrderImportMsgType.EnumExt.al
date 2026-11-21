namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73731960 "Order Import MsgType ori" extends "Message Type ori"
{
    value(73731960; "Shopify.Order.Import")
    {
        Caption = 'Shopify.Order.Import', Locked = true;
        Implementation = "Msg Interface ori" = "Order Import Impl ori", "Msg Discovery ori" = "Order Import Impl ori", "Msg Contract ori" = "Order Import Impl ori";
    }
}
