namespace Origo.Bifrost.Shopify;

using Origo.Bifrost;

/// <summary>Registers the Get Locations write message.</summary>
enumextension 73732120 "Location Sync MsgType ori" extends "Message Type ori"
{
    /// <summary>Reconciles Shopify locations, including stale location and mapping removal.</summary>
    value(73732120; "Shopify.Location.Sync")
    {
        Caption = 'Shopify.Location.Sync', Locked = true;
        Implementation = "Msg Interface ori" = "Location Sync Impl ori", "Msg Discovery ori" = "Location Sync Impl ori", "Msg Contract ori" = "Location Sync Impl ori";
    }
}
