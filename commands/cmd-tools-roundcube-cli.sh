#!/usr/bin/env bash

# Installed by the Roundcube plugin (plugins.sh --install roundcube); __WORKSPACE__ is the workspace it was installed into.
#
# The webmail of one site of this workspace, in the project's web container: say what its accounts hold (their folders
# and mails, contacts, identities, responses), run a command in its folder (one of its own bin/ scripts), add or cancel
# the default accounts, add the sample data, take away what a stopped test run left. Nothing here runs on the host.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Distribution.
distribution_name="roundcube";

ARGPARSE_DESCRIPTION="The webmail of a site of __WORKSPACE__: what its accounts hold, a command in its folder, the default accounts, the sample data, a tidy-up"
# The args file comes with the plugin: core/scripts/plugins/roundcube/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/roundcube/args/arg-roundcube-cli.sh || exit 1 ;

shift $#;

roundcube_cli_tool ;
