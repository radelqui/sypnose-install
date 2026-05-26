# Verification Law — Sypnose

NEVER declare "done" without concrete evidence.

## Verification by Change Type

| Change | How to Verify |
|--------|--------------|
| UI (.tsx, .jsx, .html) | Navigate + click + confirm visual |
| API endpoint | curl with response + status code |
| Database | SELECT query confirming the change |
| Python | pytest output with PASSED |
| JavaScript/TypeScript | npm test or npm run build output |
| Rust | cargo test output |
| Config/deploy | curl health endpoint |
| Bug fix | Reproduce original scenario, confirm fixed |
| Docker | docker ps + curl health |
| Shell script | bash -n [file] syntax check |

## PROHIBITED
- "Should work" — NOT evidence
- "Already changed it" without output — NOT evidence
- "Tests pass" without showing output — NOT evidence
- Declaring satisfaction before verifying

## Evidence Format
```
what_changed: "description"
how_verified: "concrete method (min 20 chars)"
result: "actual output (min 15 chars)"
```
