# Living Memory V1.3.1 Security Implementation Plan

Goal: harden V1.3 while preserving its SQLite schema, RAG, models and multimodal adapters.
Architecture: SQLCipher through the already pinned sqlite3 3.7.1 hook; Android Keystore wraps a random database key. Plaintext migration is copy/verify/atomic replace, never reset. Explicit deletion scopes and no content logging.
Tech stack: Flutter/Dart, Kotlin AndroidKeyStore, SQLCipher, GitHub Actions.
Spec: user's Living Memory V1.3.1 Security Hardening mission; V1.3 AUDIT/REPORT/REVALIDATION/INSTALL_S22 read in full.
Base: b77ba4663e8bdd5d6fe54c8a939a99e456d66080. No stable branch writes.

## Review focus
- Key loss/corrupt envelope must never reset the database.
- Interrupted migration/disk full must retain original data; reject future schemas.
- Delete one session/source/agent without changing other scopes; purge FTS remnants.
- Reject insecure redirects, malformed hash and excessive model sizes before transfer.
- Signing mismatch must block upgrade instructions, never recommend uninstall.

## Tasks
- [x] Storage: test real SQLCipher migration, reopen, wrong key, integrity, FTS and failure preservation. Add encrypted_database.dart and Android Keystore channel; wire MemoryScreen; preserve schema 4. Verify full Flutter suite and build.
- [x] Privacy: remove content-bearing logs, sanitize uncaught errors, audit native output. Tests use synthetic sentinels; report limits of third-party logging.
- [x] Deletion: implement scoped deleteSession and transactional deleteAgent with full child deletion and FTS optimization; expose confirmation UI; tests with two agents and sessions.
- [x] Models: validate HTTPS at transport boundary, credentials/fragments/redirects, bounds and checksum syntax; preserve optional trusted hashes and explicit unverified provenance; test malformed inputs and rollback.
- [x] Android/signing: retain privacy manifest gates; explicit experimental signing opt-in, external stable signing procedure and certificate check. No production secret generation.
- [x] Validation: CI full regression, analyze/format, ARM64 APK/signature/content/hash, native resolved dependencies and source audit. Independent branch review. Report every unexecuted hardware test and residual risk.

## Ledger
Baseline local: 7 Python Android/native dependency security tests pass. Flutter SDK absent initially; pinned 3.47.3 being prepared. No device connected. No APK or hardware success claimed.

Progress (before final CI): independent source review complete; all reproduced Important findings implemented. Runtime head eeb4f42c. Red evidence: privacy 40650705154; model transport and export stage 40651513235; local model bound 40653527934; failed-deletion callback reproduced in the following security run. Full regression 40652615949 found signed-fragment and version metadata regressions; fixes retained their assertions.
Ruling: native inline implementation on the explicitly requested isolated branch; no stable writes. CI is the safer alternative to blocked local Flutter, not a local execution workaround.
Ruling: SQLCipher is mandatory for Android private-memory disk opens; desktop keeps its existing storage. No silent encryption fallback. Cost: lost Keystore/envelope requires recovery rather than opening a blank DB.
Ruling: stable signing is prepared by a documented external-key procedure; no production key is generated, and experimental CI signing remains nonpersistent. Cost: incompatible installed certificate cannot be upgraded by this artifact.
Ruling: callback-on-failed-deletion reclassified as an Important privacy/UI error; corrected after a red test.
Deferred review strengthening: explicit hidden-rowid comparison during migration (not a demonstrated defect; indexed-table transfer and the historical-deletion FTS fixture verified instead). Actual Keystore corruption/reboot, power-loss and native Logcat checks remain hardware work, not simulated pass claims.

Final: run 40654444799 success / runtime f73a8e13. Full suite 3060 passed, 15 skipped; focused memory/LLM 147 passed; analyze/format, ARM64 APK, merged manifest, resolved native graph and signature/content gates passed. Light evidence ZIP digest verified and final manifest/graph checks rerun locally. Hardware remains unexecuted. Stable branch references checked unchanged. No merge; isolated branch/worktree retained as requested.
