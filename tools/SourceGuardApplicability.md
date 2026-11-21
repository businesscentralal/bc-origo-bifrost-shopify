# Source guard applicability (issue #52)

The only new source absence rule is a missing `app/src`. An existing source tree
always follows the previous check and failure paths. The keyword guard additionally
uses its documented message-registration rule; it must fail if registrations exist
but no `KeywordsLbl` was checked. No workflow or check with input is weakened.

Complete inventory of `Test-*.ps1` under `tools/`:

| Script | Result with `app/src` absent |
| --- | --- |
| Test-NoClientCallstack.ps1 | `NOT_APPLICABLE: app/src is absent`, exit 0. |
| Test-ValidatedTableView.ps1 | `NOT_APPLICABLE: app/src is absent`, exit 0. |
| Test-PermissionCoverage.ps1 | `NOT_APPLICABLE: app/src is absent`, exit 0. |
| Test-ContractParameterKeys.ps1 | `NOT_APPLICABLE: app/src is absent`, exit 0. |
| Test-MixedLanguageLabels.ps1 | `NOT_APPLICABLE: app/src is absent`, exit 0. |
| Test-IcelandicKeywordCounts.ps1 | `NOT_APPLICABLE: no message types registered`, exit 0, only if no registration exists anywhere under the app folder. Registration or keyword input outside `src` is still checked. |
| Test-IcelandicXlfInSync.ps1 | `NOT_APPLICABLE: app/src is absent and there are no translation artifacts`, exit 0. If XLF input exists, has something to check anyway: translation build/sync requirements remain enforced. |
| Test-HelpLinks.ps1 | Has something to check anyway: manifest help, privacy, EULA and context-sensitive URLs. Skips only the absent source enumeration; bad manifest links still fail. |
| Test-NoObsolete.ps1 | Has something to check anyway: scans the entire app folder (not only `src`) for AL declarations/pragmas and validates its allow-list. Unchanged. |
| Test-ObjectIdsUnique.ps1 | Has something to check anyway: independently scans `test/src` as well as `app/src`; missing directories were already optional. Existing empty-directory and duplicate-ID failures remain. Unchanged. |
| Test-BifrostPipeline.ps1 | Has something to check anyway: workflow/settings pipeline contracts. Unchanged. |
| Test-SharedAlpacaContainer.ps1 | Has something to check anyway: synthetic shared-container contract tests. No live container is created. Unchanged. |
| Test-SourceGuardApplicability.ps1 | Has something to check anyway: self-created fixtures for each changed guard, independent of the repository's source. |

`Get-SharedAlpacaBuildOrder.ps1`, `SharedAlpacaContainer.ps1`, and
`Update-IcelandicXlf.ps1` are build/translation helpers, not source guards. They are
unchanged. This list covers every PowerShell file in `tools/`.

## Regression coverage

`Test-IcelandicKeywordCounts.ps1 -SelfTest` invokes
`Test-SourceGuardApplicability.ps1`, so the existing Source Guards self-test step
runs the new tests without a workflow edit. It tests absent-source results through
the real CLI, then checks a real violation for every changed guard: leaked
callstack, unvalidated table view, ungranted page, mismatched contract keys, mixed
language error, registered message with no keyword declaration and a short keyword
translation, source present but no translation build, and missing page help.
Manifest URLs and existing translation artifacts are checked even without source.
Fixtures use unique temporary folders and are deleted in `finally`.

The existing self-tests for contract keys, permission coverage, mixed language,
translation sync and keyword counts continue to test their original rule sets.
PR #53 has no merge-order dependency on PR #40. Either may merge first; the other
then takes a normal update from main without tooling changes. AC02 is a separate
postmerge check on PR #40's updated tip, not a claimed result of this tools PR.
