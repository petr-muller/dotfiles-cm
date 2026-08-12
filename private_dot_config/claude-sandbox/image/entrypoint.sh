#!/bin/bash
set -euo pipefail

# Optional RH JIRA access via acli: JIRA_TOKEN/JIRA_SITE/JIRA_EMAIL are only
# set (by claude::sandbox::_run) when ~/.config/claude-sandbox/secrets/jira-token
# and ~/.config/claude-sandbox/jira-config exist on the host. acli has no
# env-var token auth for ongoing commands, only a one-time `auth login` that
# persists into (container-local, non-bind-mounted) ~/.config/acli — so log
# in once here per container start, then drop JIRA_TOKEN so it's not sitting
# in the session's environment for the rest of the run (unlike GH_TOKEN,
# nothing downstream needs it after this point).
if [ -n "${JIRA_TOKEN:-}" ]; then
    echo "$JIRA_TOKEN" | acli jira auth login --site "$JIRA_SITE" --email "$JIRA_EMAIL" --token >/dev/null
    unset JIRA_TOKEN
fi

exec claude "$@"
