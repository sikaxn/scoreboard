<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it before grep/find or reading files when you need to understand or locate code. Use the `codegraph_explore` MCP tool when available, or `codegraph explore "<symbol names or question>"` from the shell. If there is no `.codegraph/` directory, skip CodeGraph; indexing is the user's decision.
<!-- CODEGRAPH_END -->

## Validation

Run focused tests for the behavior being changed, only when necessary. Do not run the whole test session or broad UI test suites unless the user explicitly requests them; those sessions can take over an hour. Use individual test filters and report the tests actually executed.
