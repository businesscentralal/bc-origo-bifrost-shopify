namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73731953 "Refund CrMemo MsgType ori" extends "Message Type ori"
{
    value(73731955; "Shopify.Refund.CreateCreditMemo")
    {
        Caption = 'Shopify.Refund.CreateCreditMemo', Locked = true;
        Implementation = "Msg Interface ori" = "Refund CrMemo Impl ori", "Msg Discovery ori" = "Refund CrMemo Impl ori", "Msg Contract ori" = "Refund CrMemo Impl ori";
    }
}
