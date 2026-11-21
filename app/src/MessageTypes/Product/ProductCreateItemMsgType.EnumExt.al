namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73731970 "Product CreateItem MsgType ori" extends "Message Type ori"
{
    value(73731970; "Shopify.Product.CreateItem")
    {
        Caption = 'Shopify.Product.CreateItem', Locked = true;
        Implementation = "Msg Interface ori" = "Product CreateItem Impl ori", "Msg Discovery ori" = "Product CreateItem Impl ori", "Msg Contract ori" = "Product CreateItem Impl ori";
    }
}
