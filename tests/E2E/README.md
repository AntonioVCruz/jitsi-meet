# Local Jitsi instance for browser tests

Run `bash tests/E2E/scripts/install-jitsi-meet.sh` from a Linux checkout with Docker Compose 2.24.4 or newer,
curl, flock, git, OpenSSL, Python 3 and tar. The default instance binds only loopback ports:
HTTPS 18443, HTTP 18080 and UDP 11000. The focus REST API is not published.
The HTTPS development certificate is self-signed. No cloud test service is contacted.

The installer builds the current committed application revision with Node 24 in Docker, then copies its assets
into the web image from Docker release `stable-11248-3`. The other services use that release's published images
and Compose file. This is a source-built frontend on released backends, not a source build of every Jitsi project.
Uncommitted application edits are excluded deliberately. The image label and `/source-revision.txt` identify the
application commit; the latter is checked during readiness.

Runtime files, service passwords, downloaded release files and source snapshots stay in ignored `.runtime/`.
Set `JITSI_E2E_RUNTIME_DIR` to a private Linux filesystem directory when using WSL, rather than Windows bind mounts.
Other inputs are `JITSI_E2E_PROJECT`, `JITSI_E2E_RELEASE`, `JITSI_E2E_PUBLIC_URL`, `JITSI_E2E_ADVERTISE_IP`,
`JITSI_E2E_HTTP_PORT`, `JITSI_E2E_HTTPS_PORT` and `JITSI_E2E_MEDIA_PORT`.
Choose a separate runtime directory and project name for another instance. Existing environment files are preserved;
change their configuration intentionally rather than expecting new environment inputs to replace saved settings.

Run the script with `status`, `logs`, `restart`, or `reset` to manage the same instance. Reset runs
`docker compose down` followed by `docker compose up -d --no-build`: it retains service credentials/configuration
and resets transient meeting state. It does not erase persistent authentication or recordings.

Jitsi has no first-run admin wizard, commerce database, CSRF installation form or HTTP sample-data API.
This anonymous test deployment sets the welcome/prejoin pages, required display names and English UI in configuration.
Rooms and their sample participants are created by joining; tests must use unique room names and leave afterward.
The unattended readiness probe checks the home page, generated configuration and source revision. It authenticates
two anonymous XMPP clients over HTTP/BOSH, asks Jicofo to create a unique room, joins both clients, verifies a chat
message reaches the second participant, then terminates both sessions. The sample data is transient and cleaned up.
It does not claim a successful rendered join, media connectivity or cloud-tunnel compatibility.
Remote cloud browsers need a reachable secure origin and a separately verified media path; loopback advertisement
is intended for local browsers only. P2P is disabled to let local multi-participant checks exercise the Videobridge.

## Browser cases as code

The YAML cases cover participant/chat delivery and departure, required display-name validation, profile changes and
saved names on rejoin, and poll vote/result propagation. Each case creates a unique room and explicitly leaves it.
Case labels `jitsi-tc01` through `jitsi-tc04` support focused runs; `jitsi-e2e` selects the combined suite.
The reusable rules are fixed-name files so the suite works with Windows filenames too.

The current browser profile disables initial media capture and starts audio/video muted. These cases exercise the
rendered UI and signaling; they do not validate audio/video transmission or quality. Additional deployment modes such
as authenticated hosts, lobby restrictions, recording and media require their own environment and coverage.

The browser deployment needs these supported configuration values in its custom web configuration:

```javascript
config.disableInitialGUM = true;
config.startWithAudioMuted = true;
config.startWithVideoMuted = true;
config.showPollSingleAnswerSetting = true;
```

For Docker, use the release's `web/custom-config.js` configuration hook and restart the web service after changing it.
Preserve any existing custom configuration. The final flag exposes an optional poll control that is hidden by default;
its absence in an unconfigured deployment is not an application defect. Verify the served configuration before running.

Use a dedicated Desktop Web suite and provide its supported token through the process environment. Do not commit
credentials or change another project's saved CLI defaults. Check the installed CLI version and help before execution.
Validate against local rules before running:

```bash
testrigor test-suite validate-syntax "$TESTRIGOR_SUITE_ID" \
    --test-cases-path 'tests/E2E/test-cases/*.yaml' \
    --rules-path 'tests/E2E/rules/*.txt' --explicit-mutations
```

In syntax validation, `--explicit-mutations` selects only the supplied rules and does not save them.
Execution with local definitions can update remote content even without that flag. Obtain the suite owner's approval
for upload/run scope and any replacement. Start with sequential execution; a run-level settings JSON can specify
`{"useParallelCombinator": false}`. Never overlap runs on one remote suite.
Preserve unique run directories with the app revision, exact definition hashes/ZIP, run ID, CLI result and JUnit.
Record suspected application bugs separately for discussion; a descriptor/setup error is not itself an app defect.

## Access control, moderation and private chat

TC-05 through TC-08 cover meeting password enforcement,
lobby rejection/admission, participant removal with a surviving meeting, and private-message isolation.
TC-07 and TC-08 use three independent browsers. The `jitsi-e2e` label selects all eight cases;
`jitsi-expansion` selects TC-05 through TC-08. Use the individual case labels for focused debugging.
All eight cases passed a sequential browser regression against the documented local no-media profile.
That result does not establish support on every deployment or repeated-run reliability.

Lobby and moderator controls depend on server capabilities and participant roles. Confirm them on the target
deployment before claiming coverage. The private-message case checks rendered chat visibility with public-message
controls; it does not establish transport confidentiality or cryptographic security.

## Opt-in GitHub Actions workflow

`.github/workflows/e2e-tests.yml` runs for same-repository pull requests targeting the default branch and for manual
`workflow_dispatch` runs from that branch. It does not run on pushes or a schedule. The gate succeeds and the browser job skips when either
the repository secret `TESTRIGOR_CI_TOKEN` or repository variable `TESTRIGOR_SUITE_ID` is missing, or when dispatched
from another branch. PRs originating from another fork are skipped even if configuration is present.
The workflow has read-only repository permissions and does not request suite replacement.

Use a dedicated Desktop Web Chrome/Ubuntu CI suite managed by the repository's designated owner. Store its suite
CI token in `TESTRIGOR_CI_TOKEN`; the run step maps it to the CLI's `TESTRIGOR_API_KEY` environment variable.
Do not put a personal access token in source or command arguments. Install and run CLI version 2.0.9.
The CI job builds the committed frontend and starts the pinned Docker release through the installer, provisions
`config/web-config.js`, checks HTTP/XMPP readiness, and runs all eight cases sequentially through the localhost tunnel.
Source/harness commit IDs, definition hashes and container image IDs are saved with the JUnit report.

Concurrency uses the suite ID and does not cancel an active job. GitHub concurrency is scoped to one repository:
use a separate suite for another repository and coordinate local/manual executions with the CI suite owner.
Avoid canceling an active browser run. The job allows 120 minutes for provisioning and execution; if a job times out
or is interrupted, inspect the remote task before starting another run. Builds and cloud service capacity can vary.

The PR workflow checks out the PR head commit and records that exact source/harness revision; manual runs use the
selected default-branch commit. A test failure fails the job. Branch protection and required-check policy remain
repository-owner decisions.
JUnit, provenance and sanitized failure container logs are uploaded under a run-specific artifact name for seven days.
Only `tests/E2E/.run/` is uploaded; runtime service configuration and passwords stay outside it.
Rotate the CI token through the suite owner's account and replace the GitHub secret. To disable execution, remove
either the secret or suite variable; to remove the integration, remove the workflow and revoke its dedicated token.
The owner should triage test, environment and application failures separately. Upstream suite ownership and service
terms remain maintainer decisions. Hosted runner build capacity and tunnel connectivity require a hosted validation;
the passing local browser run alone does not verify GitHub Actions execution.
