namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers creation of Shopify customers from selected Business Central customers.</summary>
enumextension 73732140 "Customer Add MsgType ori" extends "Message Type ori"
{
    value(73732140; "Shopify.Customer.Add")
    {
        Caption = 'Shopify.Customer.Add', Locked = true;
        Implementation = "Msg Interface ori" = "Customer Add Impl ori", "Msg Discovery ori" = "Customer Add Impl ori", "Msg Contract ori" = "Customer Add Impl ori";
    }
}
