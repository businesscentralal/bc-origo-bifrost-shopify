namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 70013470 "Order CreateDoc MsgType ori" extends "Message Type ori"
{
    value(70013470; "Shopify.Order.CreateSalesDocument")
    {
        Caption = 'Shopify.Order.CreateSalesDocument', Locked = true;
        Implementation = "Msg Interface ori" = "Order CreateSalesDoc Impl ori", "Msg Discovery ori" = "Order CreateSalesDoc Impl ori", "Msg Contract ori" = "Order CreateSalesDoc Impl ori";
    }
}
