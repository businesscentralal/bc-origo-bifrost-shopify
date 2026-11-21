# Bifrost: BC 28.0 W1 floor project (refs #54).
# AL-Go runs hooks from the project's own .AL-Go folder, so reuse the repository hook unchanged:
# the same internals strip, COSMO Alpaca initialization and shared Default/Test container checks.
# Dot-source it so the hook keeps the scope that Run-AlPipeline gave this script.
. (Join-Path $env:GITHUB_WORKSPACE '.AL-Go/PipelineInitialize.ps1')
