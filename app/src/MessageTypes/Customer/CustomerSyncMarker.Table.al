namespace Origo.Bifrost.Shopify;

/// <summary>
/// Marks a Business Central customer written during the import pass of one Shopify.Customer.Sync call. The marker is
/// written inside the connector's own transaction for that customer, so it is committed only when the connector's work on
/// the customer is committed and is rolled back with it when a later step fails. The call reads and removes its markers.
/// </summary>
table 73732000 "Customer Sync Marker ori"
{
    Access = Internal;
    Caption = 'Customer Sync Marker', Comment = 'is-IS=Merki viðskiptamannasamstillingar';
    DataClassification = SystemMetadata;
    DataPerCompany = true;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;

    fields
    {
        field(1; "Run Id"; Guid)
        {
            Caption = 'Run Id', Comment = 'is-IS=Keyrslukenni';
            ToolTip = 'Specifies the Shopify.Customer.Sync call that wrote the marker.', Comment = 'is-IS=Tilgreinir Shopify.Customer.Sync kallið sem skrifaði merkið.';
        }
        field(2; "Customer SystemId"; Guid)
        {
            Caption = 'Customer SystemId', Comment = 'is-IS=SystemId viðskiptamanns';
            ToolTip = 'Specifies the SystemId of the Business Central customer that was written.', Comment = 'is-IS=Tilgreinir SystemId Business Central viðskiptamannsins sem var skrifaður.';
        }
    }

    keys
    {
        key(PK; "Run Id", "Customer SystemId")
        {
            Clustered = true;
        }
    }
}
