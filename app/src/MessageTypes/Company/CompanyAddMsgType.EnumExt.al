namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

enumextension 73732070 "Company Add MsgType ori" extends "Message Type ori"
{
    value(73732070; "Shopify.Company.Add")
    {
        Caption = 'Shopify.Company.Add', Locked = true;
        Implementation = "Msg Interface ori" = "Company Add Impl ori", "Msg Discovery ori" = "Company Add Impl ori", "Msg Contract ori" = "Company Add Impl ori";
    }
}
