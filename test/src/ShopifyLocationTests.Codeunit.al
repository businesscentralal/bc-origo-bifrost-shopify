namespace Origo.Bifrost.Shopify.Test;

using Microsoft.Integration.Shopify;
using Origo.Bifrost;
using Origo.Bifrost.Shopify;
using System.TestLibraries.Utilities;

/// <summary>Issue 15 public Dispatcher tests: reconciliation, mappings, counts, refusals and rollback.</summary>
codeunit 97570 "Shopify Location Tests ori"
{
    Subtype = Test;
    TestPermissions = Disabled;
    RequiredTestIsolation = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Fixture: Codeunit "Shopify Location Fixture ori";
        Stub: Codeunit "Shopify Location Stub ori";

    /// <summary>Imports into an empty shop and leaves another shop untouched.</summary>
    [Test]
    procedure Scenario_AC02_NewLocation()
    var
        Response: JsonObject;
    begin
        // Story #15, AC02/AC06 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X15-NEW', true);
        Fixture.SeedShop('X15-OTHER', true);
        Stub.SeedLocation('X15-OTHER', 975700003, 'X15 Other', true);
        Commit();
        Response := Execute('{"shopCode":"X15-NEW"}');
        AssertCounts(Response, '0', '1', '1', '1', '0');
        Assert.IsTrue(Snapshot('X15-OTHER').Contains('X15 Other'), 'Other shop is unchanged.');
        Fixture.Cleanup();
    end;

    /// <summary>Updates retained locations, removes stale mappings and counts a simultaneous insert and delete.</summary>
    [Test]
    procedure Scenario_AC02_ReconcileRepeat()
    var
        Location: Record "Shpfy Shop Location";
        Response: JsonObject;
        BeforeRepeat: Text;
    begin
        // Story #15, AC02/AC06 + Gunnar deletion revision | Time: none | Risk: None
        Fixture.A1SeedFixture();
        Response := Execute('{"shopCode":"X15-OK"}');
        AssertCounts(Response, '2', '2', '0', '1', '1');
        Assert.IsFalse(Location.Get('X15-OK', 975700003), 'Stale location and its embedded mapping removed.');
        Assert.IsTrue(Location.Get('X15-OK', 975700001), 'Retained location exists.');
        Assert.AreEqual('X15 Refreshed warehouse', Location.Name, 'Existing name refreshed.');
        Assert.IsTrue(Location.Active and Location."Is Primary", 'Connector flags refreshed.');
        Assert.AreEqual('X15-WH|X15-SECOND', Location."Location Filter", 'Location filter retained.');
        Assert.AreEqual('X15-WH', Location."Default Location Code", 'Default BC location retained.');
        Assert.AreEqual("Shpfy Stock Calculation"::"Non-reserved Inventory", Location."Stock Calculation", 'Stock calculation retained.');
        BeforeRepeat := Snapshot('X15-OK');
        Response := Execute('{"shopCode":"X15-OK"}');
        AssertCounts(Response, '2', '2', '0', '0', '0');
        Assert.AreEqual(BeforeRepeat, Snapshot('X15-OK'), 'Repeat preserves all business fields.');
        Fixture.Cleanup();
    end;

    /// <summary>All stale locations can disappear, returning a negative net change, then zero on repeat.</summary>
    [Test]
    procedure Scenario_AC02_AllRemoved()
    var
        Response: JsonObject;
    begin
        // Story #15, AC02/AC06 + Gunnar deletion revision | Time: none | Risk: None
        Fixture.A1SeedFixture();
        Response := Execute('{"shopCode":"X15-EMPTY"}');
        AssertCounts(Response, '1', '0', '-1', '0', '1');
        Assert.AreEqual('', Snapshot('X15-EMPTY'), 'No stale location or mapping survives.');
        Response := Execute('{"shopCode":"X15-EMPTY"}');
        AssertCounts(Response, '0', '0', '0', '0', '0');
        Fixture.Cleanup();
    end;

    /// <summary>Local inserts, updates and deletions roll back even after explicit connector commits.</summary>
    [Test]
    procedure Scenario_AC04_FailureRollsBack()
    var
        Response: JsonObject;
        BeforeRows: Text;
    begin
        // Story #15, AC04/AC06 | Time: none | Risk: None
        Fixture.A1SeedFixture();
        BeforeRows := Snapshot('X15-FAIL');
        Response := Execute('{"shopCode":"X15-FAIL"}');
        Assert.AreEqual('BusinessCentralError', ReadText(Response, 'code'), 'Typed connector refusal.');
        Assert.IsTrue(ReadText(Response, 'error').Contains('X15 mock connector failure after commit.'), 'Connector text retained.');
        Assert.AreEqual(BeforeRows, Snapshot('X15-FAIL'), 'Every business field restored, including deleted mapping.');
        Fixture.Cleanup();
    end;
    /// <summary>Absent, malformed and unknown keys are typed refusals before any write.</summary>
    [Test]
    procedure Scenario_AC03_InvalidRequests()
    var
        Response: JsonObject;
        RequestText: Text;
        InvalidValues: List of [Text];
    begin
        // Story #15, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X15-OK', true);
        Response := Execute('{}');
        Assert.AreEqual('MissingParameter', ReadText(Response, 'code'), 'Missing key.');
        InvalidValues.Add('null');
        InvalidValues.Add('true');
        InvalidValues.Add('33');
        InvalidValues.Add('[]');
        InvalidValues.Add('{}');
        InvalidValues.Add('""');
        InvalidValues.Add('"   "');
        InvalidValues.Add('"123456789012345678901"');
        foreach RequestText in InvalidValues do begin
            Response := Execute('{"shopCode":' + RequestText + '}');
            Assert.AreEqual('InvalidParameterFormat', ReadText(Response, 'code'), 'Malformed code: ' + RequestText);
        end;
        Response := Execute('{"shopCode":"X15-OK","bogus":true}');
        Assert.AreEqual('UnknownParameter', ReadText(Response, 'code'), 'Unknown parameter is rejected by the public contract validator.');
        Assert.AreEqual('', Snapshot('X15-OK'), 'Refusals change nothing.');
        Fixture.Cleanup();
    end;

    /// <summary>Unknown and disabled shops fail before the connector event.</summary>
    [Test]
    procedure Scenario_AC03_UnknownDisabledShop()
    var
        Response: JsonObject;
    begin
        // Story #15, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Response := Execute('{"shopCode":"X15-MISSING"}');
        Assert.AreEqual('RecordNotFound', ReadText(Response, 'code'), 'Unknown shop.');
        Fixture.SeedShop('X15-DISABLED', false);
        Response := Execute('{"shopCode":"X15-DISABLED"}');
        Assert.AreEqual('PreconditionFailed', ReadText(Response, 'code'), 'Disabled shop.');
        Assert.AreEqual('', Snapshot('X15-DISABLED'), 'Disabled shop has no writes.');
        Fixture.Cleanup();
    end;

    /// <summary>Read-only permission refuses this write before any changes.</summary>
    [Test]
    procedure Scenario_AC01_AC03_ReadPermission()
    var
        LowerPermissions: Codeunit "Library - Lower Permissions";
        Response: JsonObject;
    begin
        // Story #15, AC01/AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X15-OK', true);
        LowerPermissions.StartLoggingNAVPermissions();
        LowerPermissions.SetExactPermissionSet('BIFROST Read ori');
        Response := Execute('{"shopCode":"X15-OK"}');
        LowerPermissions.StopLoggingNAVPermissions();
        Assert.AreEqual('PermissionDenied', ReadText(Response, 'code'), 'Read-only caller refused with the permission code.');
        Assert.AreEqual('', Snapshot('X15-OK'), 'No location was written.');
        Fixture.Cleanup();
    end;

    /// <summary>Boundary-length and filter-looking shop codes identify exactly one shop.</summary>
    [Test]
    procedure Scenario_AC03_ShopCodeBoundaries()
    var
        Response: JsonObject;
    begin
        // Story #15, AC03 | Time: none | Risk: None
        Fixture.Cleanup();
        Fixture.SeedShop('X15-&|()<>', true);
        Response := Execute('{"shopCode":"X15-&|()<>"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Filter characters are a literal shop code.');
        Fixture.Cleanup();
        Fixture.SeedShop('X15-1234567890123456', true);
        Response := Execute('{"shopCode":"X15-1234567890123456"}');
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Maximum length accepted.');
        Fixture.Cleanup();
    end;

    local procedure Execute(RequestText: Text) Response: JsonObject
    var
        Dispatcher: Codeunit "Dispatcher ori";
        RequestContent: BigText;
        ResponseContent: BigText;
        ResponseContentType: Text[100];
        MessageVersion: Enum "Message Version ori";
        ResponseText: Text;
    begin
        RequestContent.AddText(RequestText);
        Dispatcher.Execute("Message Type ori"::"Shopify.Location.Sync", MessageVersion, '', '', 'application/json', RequestContent, ResponseContent, ResponseContentType);
        ResponseContent.GetSubText(ResponseText, 1);
        Response.ReadFrom(ResponseText);
    end;

    local procedure ReadText(Response: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Response.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    /// <summary>The contract exposes write effects, deletion, callback updates and all count fields.</summary>
    [Test]
    procedure Scenario_AC01_AC05_Contract()
    var
        Impl: Codeunit "Location Sync Impl ori";
        Effect: JsonObject;
        Response: JsonObject;
        Notes: Text;
        Overview: Text;
        Examples: JsonArray;
        Serialized: Text;
    begin
        // Story #15, AC01/AC05 | Time: none | Risk: None
        Impl.GetEffect(Effect);
        Assert.AreEqual('write', ReadText(Effect, 'effect'), 'Write classification.');
        Assert.AreEqual('SHOPIFY Full ori', ReadText(Effect, 'permissionSet'), 'Full permission only.');
        Assert.IsTrue(ReadText(Effect, 'changes').Contains('Deletes stale Shopify locations and their BC location mappings'), 'Deletion disclosed.');
        Assert.IsTrue(ReadText(Effect, 'changes').Contains('callback URL'), 'Remote callback effect disclosed.');
        Assert.IsTrue(Impl.GetOverview(Overview), 'Overview exists.');
        Impl.GetNotes(Notes);
        Assert.IsTrue(Notes.Contains('Idempotent') and Notes.Contains('mappings on deleted locations are lost'), 'Idempotency and mapping loss documented.');
        Assert.IsTrue(Impl.GetExamples(Examples), 'Examples exist.');
        Impl.GetResponse(Response);
        Response.WriteTo(Serialized);
        Assert.IsTrue(Serialized.Contains('netChange') and Serialized.Contains('inserted') and Serialized.Contains('removed'), 'All count fields documented.');
    end;

    local procedure AssertCounts(Response: JsonObject; BeforeCount: Text; AfterCount: Text; NetCount: Text; InsertedCount: Text; RemovedCount: Text)
    begin
        Assert.AreEqual('Success', ReadText(Response, 'status'), 'Sync succeeds: ' + ReadText(Response, 'error'));
        Assert.AreEqual(BeforeCount, ReadText(Response, 'locationsBefore'), 'Before count.');
        Assert.AreEqual(AfterCount, ReadText(Response, 'locationsAfter'), 'After count.');
        Assert.AreEqual(NetCount, ReadText(Response, 'netChange'), 'Net count.');
        Assert.AreEqual(InsertedCount, ReadText(Response, 'inserted'), 'Inserted count.');
        Assert.AreEqual(RemovedCount, ReadText(Response, 'removed'), 'Removed count.');
    end;

    local procedure Snapshot(ShopCode: Code[20]): Text
    var
        Location: Record "Shpfy Shop Location";
        LocationRef: RecordRef;
        FieldValue: FieldRef;
        Rows: TextBuilder;
        FieldIndex: Integer;
    begin
        Location.SetRange("Shop Code", ShopCode);
        if Location.FindSet() then
            repeat
                LocationRef.GetTable(Location);
                for FieldIndex := 1 to LocationRef.FieldCount() do begin
                    FieldValue := LocationRef.FieldIndex(FieldIndex);
                    // Exclude SQL timestamp and platform audit fields; compare every business field.
                    if (FieldValue.Number < 2000000000) and (FieldValue.Number <> 3) and FieldValue.Active then
                        Rows.Append(Format(FieldValue.Value, 0, 9) + '|');
                end;
                Rows.AppendLine();
                LocationRef.Close();
            until Location.Next() = 0;
        exit(Rows.ToText());
    end;
}
