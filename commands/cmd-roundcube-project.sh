#!/usr/bin/env bash

# workspace-name: Roundcube (webmail)

# Installed by the Roundcube plugin (plugins.sh --install roundcube); __WORKSPACE__ is the workspace it was installed into.
#
# Build a Roundcube webmail in a container: the latest Roundcube from its releases (the complete package), or the one
# --version names, on DDEV at https://<name>.ddev.site, with a mail server of its own beside it (GreenMail, the IMAP and
# SMTP test server Roundcube's own CI uses). With --install the webmail is installed (its database made by its own
# bin/initdb.sh) and the workspace account gets a mailbox on the mail server; with --add-users it also gets the default
# accounts: two mailboxes the test scenarios read and write; with --sample-data the mails, contacts, group and response
# the step pack's features name. The webmail's own tool is cmd-tools-roundcube-cli.sh.

# Bootstrap.
# Find the workspace tooling from this script, so a fresh clone needs no setup.
WORKSPACE_SCRIPTS="${WORKSPACE_SCRIPTS:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../core/scripts" && pwd)}";
source ${WORKSPACE_SCRIPTS}/bootstrap.sh || exit 1 ;

# Load workspace settings.
eval $(parse_yaml ${WORKSPACE_CONFIG}/workspace.__WORKSPACE__.settings.yml);

# Set site version.
site_version="latest";

# Distribution.
distribution_name="roundcube";
distribution_title="Roundcube";
distribution_webroot="public_html";

ARGPARSE_DESCRIPTION="Build a ${distribution_title} webmail in __WORKSPACE__"
# The args file comes with the plugin: core/scripts/plugins/roundcube/ is where plugins.sh --install puts it.
source ${WORKSPACE_SCRIPTS}/plugins/roundcube/args/arg-roundcube.sh || exit 1 ;

shift $#;

roundcube_build ;
