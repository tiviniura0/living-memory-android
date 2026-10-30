# Godot preparation via GitHub Actions — blocked before dispatch

Date: 29 octobre 2026 (Tahiti).

## Scope and source

Mission: reuse the approved plan `docs/superpowers/plans/2026-10-29-living-world-godot2d.md`, add a manual prerequisite check on `work/living-world-godot2d`, and start Task 1 only after a successful preparation run.
The user's current mission constitutes approval of the existing plan; its older “PLAN À VALIDER” label does not require another approval.
Starting branch head: `bb9d10940391566e9a06e77e2dd6324dd12d0668`.
Preparation workflow commit: [34b55c704978bc98418baff84a82f166b79eb1ef](https://github.com/tiviniura0/living-memory-android/commit/34b55c704978bc98418baff84a82f166b79eb1ef).

No application, simulation, memory, schema, asset, signing or stable-branch changes.

## Existing workflows and permissions

Read against the Godot branch. Runtime GITHUB_TOKEN permissions are distinct from the connector's available operations.

| Workflow | Trigger relevant here | Declared permissions |
| --- | --- | --- |
| world-l1.yml | push restricted to work/living-world-l1-observable; no manual trigger | contents: read |
| living-memory-v14.yml | manual; push restricted to V1.4 | contents: read |
| build-apk.yml | manual and existing branch/path filters; Godot branch absent from push list | contents: read |
| verify-apk.yml | manual; push restricted to local-rag | actions: read, contents: read |
| test_builds.yml | manual; push/PR main; schedule | build-and-test job: actions: write, contents: write |
| zizmor.yml | push/PR main with workflow path filter | job: contents: read |

The repository metadata reports default branch `main` and authenticated-user repository permissions including admin/push. This does **not** establish the GitHub App's Actions-write scope or administrative endpoint access.
The new workflow uses only `contents: read`, checkout without persisted credentials, fixed existing action SHAs, no secrets, no automatic event and an exact Godot-branch job guard.
No permissions were elevated.

## New preparation workflow

File: [world-godot.yml](https://github.com/tiviniura0/living-memory-android/blob/34b55c704978bc98418baff84a82f166b79eb1ef/.github/workflows/world-godot.yml).

Planned runner checks:
- Flutter 3.47.3, Java 17, installed Android SDK tools; record actual generated Gradle/AGP configuration.
- Candidate Godot 4.5.1 CLI and export templates from the official release, checked against that release's SHA512 list; record observed SHA256 values.
- Official Maven coordinate `org.godotengine:godot:4.5.1.stable`, POM/AAR download, AAR metadata and ARM64 contents.
- Generate a disposable Flutter app outside the source tree with minSdk 30, resolve the real Godot dependency and build an ARM64 debug probe; require the Godot native library inside the APK.
- Upload bounded evidence under `world-godot-preparation-<source SHA>` even on failure.

The probe is **not** Living World, does not implement GodotHost or render a scene, and is not a delivery APK. It is not uploaded as an installable application.
Version/security approval is still pending Task 1: a successful dependency probe cannot establish that the candidate Godot patch is acceptable or that a phone works.

## Exact dispatch blocker

1. The available GitHub connector exposes file writes, Actions run/job/artifact reads and rerun operations for known existing runs. It exposes **no workflow_dispatch creation operation**. Its generic fetch tool is GET-only.
2. An attempted GET of the workflow collection at `https://api.github.com/repos/tiviniura0/living-memory-android/actions/workflows` returned:
   `HTTPError: 400: GitHub Fetch URL is not an allowed public GitHub repository or search endpoint.`
   This is a connector endpoint restriction, **not evidence that GitHub Actions itself is disabled**.
3. GitHub's official manual-run documentation states: “To trigger the workflow_dispatch event, your workflow must be in the default branch.” The verified default branch is main. Its workflows directory contains build-apk.yml, test_builds.yml, verify-apk.yml and zizmor.yml, but no world-godot.yml.
4. The mission forbids stable-branch changes. No registration file was added to main. No push/PR trigger, alternate registered workflow or rerun workaround was used.
5. The Actions runs query for preparation commit `34b55c704978bc98418baff84a82f166b79eb1ef` returned `{"total_count":0,"workflow_runs":[]}`.

No workflow dispatch request could be issued. There is no run ID, job log, CI error or artifact URL to provide.
No repeated dispatch attempts, local SDK downloads, network/proxy changes or installation were performed.
Actions enablement, billing/quota and GitHub App Actions-write authorization remain **unverified**, not failed.

## Verification actually performed

- Parsed workflow YAML.
- Parsed all five embedded shell blocks with bash -n and embedded Python with ast.parse.
- Checked that workflow_dispatch is the only trigger, permissions are contents: read, and the job is restricted to the Godot branch.
- git diff --check passed for the local preparation.
- Read the committed workflow back through GitHub at its exact commit; contents match the reviewed submission.

These are static checks, not a GitHub-hosted execution.
Task 1: **NOT STARTED** because preparation has not run.
Flutter/Dart tests: **NOT EXECUTED**.
Godot engine execution: **NOT EXECUTED**.
ARM64 probe build and Living World APK: **NOT EXECUTED**.
Native instrumentation and S22 tests: **NOT EXECUTED**.

## Resumption without another audit

Recommended smallest change to the launch strategy: permit a narrowly filtered push trigger for this preflight on work/living-world-godot2d only. That can bootstrap the workflow without changing main or requiring a dispatch operation. This changes the requested manual-only launch policy, so it was not silently applied.
Alternatively, register a manual workflow on main and provide a dispatch-capable connection; this would require changing the stable-branch constraint.
Neither change is a completed or authorized workaround in this report.

Once a real preparation run succeeds, resume Task 1 from the existing plan, including native RED/GREEN tests, official API/security/version checks, lifecycle implementation and explicit ARM64 instrumentation gate. No claim of hardware success follows from compilation.

Official references:
- https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow
- https://docs.godotengine.org/en/4.5/tutorials/platform/android/android_library.html
