#!/usr/bin/env bash

# Roundcube for the Webship Workspace: build a webmail with a mail server of its own, run a command in its folder, add
# its default accounts and the sample data, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install roundcube` in core/scripts/plugins/roundcube/functions/, where bootstrap sources it
# after the core's own functions. Everything runs in the project's containers (`ddev exec …`), never on the host. The
# container tool has no project type for Roundcube, so a webmail is a `php` project served by Apache (the release's
# public_html/ serves its scripts at static.php/<path>, which Apache passes on), with public_html/ as its docroot; its
# program/include/iniset.php is how the functions here recognise one.
#
# The mail server: Roundcube keeps no account of its own, a user is a mailbox of an IMAP server. The builder puts
# GreenMail (the IMAP and SMTP test server Roundcube's own CI runs its browser tests against, Apache-2.0) beside the
# webmail as a service of the DDEV project (.ddev/docker-compose.greenmail.yaml), with the workspace account's mailbox
# and, with --add-users, the default accounts'. An account is written into that file (so it is there after a restart)
# and given to the running server through its own API (so no restart is needed). GreenMail keeps its mail in memory: a
# start of the project finds the mailboxes empty. A webmail with the sample data gets it again after every start (the
# post-start hook of the plugin's claim runs the plugin's script, which keeps what a mailbox holds); mail sent since is
# gone.
#
# The runtimes: the webmail builds on DDEV only. A service of a platform's own (here the mail server) is something the
# workspace's other runtimes do not carry yet (core/docs/plugins-on-runtimes.md, "What does not fit yet"): the builder
# says so and stops before anything is built, when the workspace's container.runtime or --runtime names another one.
#
# The claim: the type php says nothing of the platform, so the builder claims the project for the plugin with
# .ddev/config.roundcube.yaml, by which the dashboard's row knows the webmail and offers its test users.
#
# Four names are the ones the core's tools look for:
#   set_roundcube_users          the default accounts            (cmd-tools-add-users.sh <project> roundcube)
#   add_roundcube_users          give them to the mail server    (the same tool, and --add-users of the builder)
#   cancel_roundcube_users       delete them                     (cmd-tools-cancel-users.sh <project> roundcube)
#   testing_configure_roundcube  the step pack in the testing stack (cmd-tools-testing.sh <project>)

# The step pack a webmail is tested with, and the release line it is required at.
readonly ROUNDCUBE_STEPS_PACKAGE='@webship-js/roundcube-steps';
readonly ROUNDCUBE_STEPS_VERSION='^2.0.0';

# Where the project publishes its releases, the line this plugin builds, and the release it was proven on.
readonly ROUNDCUBE_RELEASES='https://api.github.com/repos/roundcube/roundcubemail/releases?per_page=30';
readonly ROUNDCUBE_MAJOR='1';
readonly ROUNDCUBE_PROVEN_VERSION='1.7.7';

# The mail server: the image, the host the webmail reaches it at, and its ports in the project's network.
readonly ROUNDCUBE_GREENMAIL_IMAGE='greenmail/standalone:2.1.15';
readonly ROUNDCUBE_MAIL_HOST='greenmail';

# The default accounts: two mailboxes of the mail server, the ones a scenario logs in as. Accounts are configuration:
# a test suite never creates or deletes one. Each logs in with its address; the name is the one its identity shows.
function set_roundcube_users() {
  users=(alice bob);
  local names=('Alice Test' 'Bob Test') i user ;
  for i in "${!users[@]}" ; do
    user="${users[$i]}" ;
    printf -v "user_${user}_name" '%s' "${user}@example.com" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_role" '%s' 'Mailbox' ;
    printf -v "user_${user}_fullname" '%s' "${names[$i]}" ;
  done
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's setting, else DDEV). A
# core without the runtime layer has DDEV only, and its --runtime names it.
function roundcube_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of ; return ; fi
  local asked="${RUNTIME:-_none_}" ; [ "${asked}" = '_none_' ] && asked='ddev' ;
  echo "${asked}" ;
}

# The address of the webmail in this folder.
function roundcube_url() {
  if declare -f rt_url > /dev/null ; then rt_url ; else echo "https://${PROJECT_NAME}.ddev.site" ; fi
}

# The docroot of a project, from its own container configuration (.ddev/config.yaml).
function roundcube_docroot() {
  local project_path="$1" ;
  grep -E '^docroot:' "${project_path}/.ddev/config.yaml" 2>/dev/null | head -1 | sed -E 's/^docroot:[[:space:]]*//; s/^"(.*)"$/\1/; s/[[:space:]]*$//' ;
}

# Is this folder a Roundcube webmail? A DDEV project whose folder holds Roundcube's program/ and its public_html/.
function roundcube_is_project() {
  local project_path="$1" ;
  [ -f "${project_path}/.ddev/config.yaml" ] || return 1 ;
  [ -f "${project_path}/program/include/iniset.php" ] && [ -f "${project_path}/public_html/index.php" ] ;
}

# Is the webmail installed? Its configuration names its database.
function roundcube_is_installed() {
  [ -f "$1/config/config.inc.php" ] && grep -q "db_dsnw" "$1/config/config.inc.php" ;
}

# The release of the webmail in a project folder, as its own code names it.
function roundcube_version() {
  sed -n "s/^define('RCMAIL_VERSION', '\([^']*\)');.*/\1/p" "$1/program/include/iniset.php" 2>/dev/null | head -1 ;
}

# Go to the project a tool was asked about, or say why not.
function roundcube_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! roundcube_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Roundcube webmail (its folder has no program/ and public_html/ of one)." ;
    return 1 ;
  fi
  cd "${project_path}" || return 1 ;
}

# The claim of this plugin on the project, in the folder of the container tool: a config overlay with one key the
# webmail does not read, and the hook that writes the sample data again after a start. The dashboard reads the file's
# name: a project that carries config.<plugin>.yaml takes the test users of that plugin.
function roundcube_write_claim() {
  local project_path="$1" ;
  mkdir -p "${project_path}/.ddev" || return 1 ;
  cat > "${project_path}/.ddev/config.roundcube.yaml" <<'YAMLEOF'
# Written by the Roundcube plugin of the Webship Workspace (cmd-roundcube-project.sh).
#
# It is the plugin's claim on this project: the project type php names no platform, so the workspace's tools and its
# dashboard read this file to know the webmail, and take its test users for it (cmd-tools-add-users.sh <project>
# roundcube). The key below is in the environment of the web container from its next start; nothing of the webmail
# reads it.
web_environment:
  - WEBSHIP_WORKSPACE_PLATFORM=roundcube
# The mail server keeps its mail in memory, so every start of the project (a restart, Stop and Start, an add-on that
# restarts it) finds the mailboxes empty. A webmail with the sample data (.ddev/roundcube/, written with it) gets it
# again after each start; what a mailbox holds is kept. Without .ddev/roundcube/ the hook does nothing.
hooks:
  post-start:
    - exec: "[ ! -f /mnt/ddev_config/roundcube/after-start.sh ] || bash /mnt/ddev_config/roundcube/after-start.sh"
YAMLEOF
}

# The sample data across a start of the project: GreenMail keeps its mail in memory, so a start finds the mailboxes
# empty. The plugin's script and a short script for the hook of the claim go in .ddev/roundcube/ (the web container
# sees the folder at /mnt/ddev_config/roundcube/), and the claim is written again, so a webmail built with an older
# claim gets the hook too (from its next start). Run in the project folder, once the sample data is written.
function roundcube_keep_sample() {
  local script="${WORKSPACE_SCRIPTS}/plugins/roundcube/mail-site.php" ;
  [ -f "${script}" ] || return 1 ;
  mkdir -p .ddev/roundcube && cp "${script}" .ddev/roundcube/mail-site.php || return 1 ;
  cat > .ddev/roundcube/after-start.sh <<'SHEOF'
#!/usr/bin/env bash
# Written by the Roundcube plugin of the Webship Workspace. Run in the web container after every start of the project
# (the post-start hook of .ddev/config.roundcube.yaml): the mail server keeps its mail in memory, so a start finds the
# mailboxes empty, and the sample data is written again with the plugin's script (mail-site.php, beside this one).
# What a mailbox holds is kept. It never stops a start: whatever happens, it ends well.
cd /var/www/html || exit 0
[ -f config/config.inc.php ] || exit 0
# The mail server opens its IMAP port a few seconds after its container starts.
for i in $(seq 1 60) ; do (exec 3<>/dev/tcp/greenmail/3143) 2> /dev/null && break ; sleep 1 ; done
cp /mnt/ddev_config/roundcube/mail-site.php .webship-mail-site.php || exit 0
if php .webship-mail-site.php sample > /dev/null 2>&1 ; then
  echo "The webmail's sample data is in its mailboxes again (the mail server keeps its mail in memory)."
else
  echo "The webmail's sample data could not be written again: cmd-tools-roundcube-cli.sh <project> --sample-data writes it."
fi
rm -f .webship-mail-site.php
exit 0
SHEOF
  roundcube_write_claim "$(pwd)" ;
}

# No sample data to keep across a start (the default accounts were cancelled): the hook of the claim finds nothing.
function roundcube_drop_sample() {
  rm -f .ddev/roundcube/mail-site.php .ddev/roundcube/after-start.sh ;
  rmdir .ddev/roundcube 2> /dev/null ;
  return 0 ;
}

# Can a password be given to the mail server in its list of accounts? It splits the list on ",", an account on ":" and
# "@", and the container tool reads "$" in the file: a password with one of them, or a space, is said before a build.
function roundcube_password_fits() {
  [[ ! "$1" =~ [[:space:]:@,\$\"\\\`] ]] && [ "${#1}" -ge 1 ] ;
}

# The accounts the mail server has, as its list in the project's file: "login:password@domain,…".
function roundcube_mail_accounts() {
  local file=".ddev/docker-compose.greenmail.yaml" ;
  sed -n 's/.*-Dgreenmail\.users=\([^ "]*\).*/\1/p' "${file}" 2>/dev/null | head -1 ;
}

# Does the list of the mail server hold an account with this address? Each entry is login:password@domain, and neither
# a login nor a password holds ":" or "@".
function roundcube_mail_has_account() {
  local local_part="${1%@*}" domain="${1#*@}" entry list=() ;
  IFS=',' read -r -a list <<< "$(roundcube_mail_accounts)" ;
  for entry in "${list[@]}" ; do
    [ "${entry%%:*}" == "${local_part}" ] && [ "${entry##*@}" == "${domain}" ] && return 0 ;
  done
  return 1 ;
}

# Write the mail server's service of the project with a list of accounts ("login:password@domain,…"; none: no list,
# the server starts with no account).
function roundcube_write_mailserver() {
  local accounts="$1" users="" ;
  [ -n "${accounts}" ] && users=" -Dgreenmail.users=${accounts}" ;
  mkdir -p .ddev || return 1 ;
  cat > .ddev/docker-compose.greenmail.yaml <<YAMLEOF
# Written by the Roundcube plugin of the Webship Workspace (cmd-roundcube-project.sh).
#
# The mail server of the webmail: GreenMail (Apache-2.0), the IMAP and SMTP test server Roundcube's own CI runs its
# browser tests against. The webmail reaches it at ${ROUNDCUBE_MAIL_HOST}:3143 (IMAP) and ${ROUNDCUBE_MAIL_HOST}:3025 (SMTP); its
# own API (${ROUNDCUBE_MAIL_HOST}:8080) adds and removes an account while it runs. It keeps its mail in memory: a start of the
# project finds the mailboxes empty, and the hook of .ddev/config.roundcube.yaml writes the sample data again.
# The accounts are the list below (login:password@domain): cmd-tools-add-users.sh and cmd-tools-cancel-users.sh change it.
services:
  ${ROUNDCUBE_MAIL_HOST}:
    container_name: ddev-\${DDEV_SITENAME}-${ROUNDCUBE_MAIL_HOST}
    image: ${ROUNDCUBE_GREENMAIL_IMAGE}
    restart: "no"
    labels:
      com.ddev.site-name: \${DDEV_SITENAME}
      com.ddev.approot: \${DDEV_APPROOT}
    environment:
      GREENMAIL_OPTS: "-Dgreenmail.setup.test.smtp -Dgreenmail.setup.test.imap -Dgreenmail.hostname=0.0.0.0 -Dgreenmail.users.login=email${users}"
    expose:
      - "3025"
      - "3143"
      - "8080"
YAMLEOF
}

# Give an account to the mail server: in the project's file (it is there after a restart) and through the running
# server's own API (no restart). An account that is there is kept.
function roundcube_mail_account_add() {
  local address="$1" password="$2" accounts ;
  if ! roundcube_mail_has_account "${address}" ; then
    accounts="$(roundcube_mail_accounts)" ;
    roundcube_write_mailserver "${accounts:+${accounts},}${address%@*}:${password}@${address#*@}" || return 1 ;
  fi
  ddev exec "curl -fsS -m 20 -X POST -H 'Content-Type: application/json' -d $(printf '%q' "{\"email\":\"${address}\",\"login\":\"${address}\",\"password\":\"${password}\"}") http://${ROUNDCUBE_MAIL_HOST}:8080/api/user > /dev/null 2>&1 || curl -fsS -m 20 http://${ROUNDCUBE_MAIL_HOST}:8080/api/user | grep -q '\"${address}\"'" < /dev/null ;
}

# Take an account from the mail server: from the project's file and from the running server.
function roundcube_mail_account_remove() {
  local address="$1" local_part="${1%@*}" domain="${1#*@}" kept=() entry list=() ;
  IFS=',' read -r -a list <<< "$(roundcube_mail_accounts)" ;
  for entry in "${list[@]}" ; do
    [ "${entry%%:*}" == "${local_part}" ] && [ "${entry##*@}" == "${domain}" ] || kept+=("${entry}") ;
  done
  roundcube_write_mailserver "$(IFS=',' ; echo "${kept[*]}")" || return 1 ;
  ddev exec "curl -fsS -m 20 -X DELETE http://${ROUNDCUBE_MAIL_HOST}:8080/api/user/${address} > /dev/null 2>&1 || true" < /dev/null ;
}

# Run mail-site.php in the webmail, in the project folder: the accounts' users, the sample data, a reset, a status, the
# counts, each written or read with Roundcube's own classes. The script is copied into the project's folder for the
# run, and removed.
function roundcube_mail_site() {
  local script="${WORKSPACE_SCRIPTS}/plugins/roundcube/mail-site.php" status ;
  if [ ! -f "${script}" ] ; then
    echo "The Roundcube plugin's mail-site.php is not at ${script}: install the plugin again (plugins.sh --install roundcube)." ;
    return 1 ;
  fi
  cp "${script}" ".webship-mail-site.php" || return 1 ;
  ddev exec -d /var/www/html php .webship-mail-site.php "$@" < /dev/null ;
  status=$? ;
  rm -f ".webship-mail-site.php" ;
  return ${status} ;
}

# The release of Roundcube to download: the number asked for, or the newest stable one of the line this plugin builds,
# from the project's releases (read in the container; the proven release when the list cannot be read).
function roundcube_release() {
  local wanted="$1" ;
  if [ "${wanted}" != 'latest' ] ; then echo "${wanted}" ; return 0 ; fi
  ddev exec "curl -fsSL --retry 3 --retry-delay 2 '${ROUNDCUBE_RELEASES}'" 2>/dev/null < /dev/null | python3 -c '
import json, sys
major = sys.argv[1]
try:
    releases = json.load(sys.stdin)
except ValueError:
    sys.exit(1)
tags = [r["tag_name"] for r in releases if not r.get("prerelease") and not r.get("draft") and str(r.get("tag_name", "")).startswith(major + ".")]
if not tags:
    sys.exit(1)
print(sorted(tags, key=lambda t: [int(x) for x in t.split(".") if x.isdigit()])[-1])
' "${ROUNDCUBE_MAJOR}" || echo "${ROUNDCUBE_PROVEN_VERSION}" ;
}

# The configuration of the webmail: the database of the container, the mail server beside it, the release's own plugins
# and skin, and what makes a list read the same on every machine and every run (the time zone UTC, the messages
# sorted by date), the default folders made at the first login. A key of its own (des_key) for each build.
function roundcube_write_config() {
  local key ;
  key="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 24)" ;
  cat > config/config.inc.php <<PHPEOF
<?php
// The configuration of the webmail (written by the Roundcube plugin of the Webship Workspace).
\$config = [];
\$config['db_dsnw'] = 'mysql://db:db@db/db';
\$config['imap_host'] = '${ROUNDCUBE_MAIL_HOST}:3143';
\$config['smtp_host'] = '${ROUNDCUBE_MAIL_HOST}:3025';
\$config['support_url'] = '';
\$config['des_key'] = '${key}';
\$config['plugins'] = ['archive', 'zipdownload'];
\$config['skin'] = 'elastic';
\$config['timezone'] = 'UTC';
\$config['message_sort_col'] = 'date';
\$config['message_sort_order'] = 'DESC';
\$config['create_default_folders'] = true;
PHPEOF
}

# Build a Roundcube webmail from nothing: the container, the mail server, the code, and with --install the webmail.
function roundcube_build() {
  trim_project_name ;
  local base_url ;
  if [ "$(roundcube_runtime)" != 'ddev' ] ; then
    echo "Roundcube builds on DDEV only for now: its stack (the webmail and a mail server of its own beside it) is not on the other runtimes yet (webship/workspace#694). Build with --runtime ddev." ;
    exit 1 ;
  fi
  local version="${VERSION:-${site_version:-latest}}" ;
  local php_version="${PHP_VERSION:-${site_php_version:-8.3}}" ;
  local docroot="${distribution_webroot:-public_html}" ;

  if [ ! "${version}" == 'latest' ] && [[ ! "${version}" == ${ROUNDCUBE_MAJOR}.* ]] ; then
    echo "This builder makes a Roundcube ${ROUNDCUBE_MAJOR}.x webmail: --version is latest or a ${ROUNDCUBE_MAJOR}.x number such as ${ROUNDCUBE_PROVEN_VERSION}." ;
    exit 1 ;
  fi
  # The workspace account is a mailbox of the mail server, which reads its list of accounts in a form a few signs break.
  if [ "${INSTALL}" == 'yes' ] ; then
    if [[ ! "${account_mail}" =~ ^[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+$ ]] || ! roundcube_password_fits "${account_pass}" ; then
      echo "The mail server takes an account with an address and a password without a space or any of : @ , \$ \" \\ \`, and the workspace account does not fit." ;
      echo "Change account: in core/config/settings.yml, or build without --install." ;
      exit 1 ;
    fi
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;
  drop_database ;
  rm -rf "${PROJECT_NAME}" ;
  mkdir -p "${PROJECT_NAME}/${docroot}" ;
  cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;

  ddev config --project-type=php --docroot="${docroot}" --project-name=${PROJECT_NAME} --webserver-type=apache-fpm \
    --php-version=${php_version} --database=mariadb:10.11 --nodejs-version=$(ddev_nodejs_version) || exit 1 ;
  roundcube_write_claim "$(pwd)" || { echo "The plugin's claim on the project could not be written." ; exit 1 ; } ;

  # The mail server, with the workspace account's mailbox (and the default accounts' with --add-users).
  local accounts="" ;
  if [ "${INSTALL}" == 'yes' ] ; then
    accounts="${account_mail%@*}:${account_pass}@${account_mail#*@}" ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_roundcube_users ;
      local user user_mail user_password ;
      for user in "${users[@]}" ; do
        user_mail="user_${user}_mail"; user_password="user_${user}_password";
        accounts="${accounts},${!user_mail%@*}:${!user_password}@${!user_mail#*@}" ;
      done
    fi
  fi
  roundcube_write_mailserver "${accounts}" || exit 1 ;

  base_url="$(roundcube_url)" ;
  ddev_up start -y || exit 1 ;

  version="$(roundcube_release "${version}")" ;
  echo "Downloading Roundcube ${version}." ;
  ddev exec "cd /tmp && rm -f roundcube-release.tar.gz && curl -fsSL --retry 3 --retry-delay 2 -o roundcube-release.tar.gz 'https://github.com/roundcube/roundcubemail/releases/download/${version}/roundcubemail-${version}-complete.tar.gz' \
    && tar -xzf roundcube-release.tar.gz --strip-components=1 -C /var/www/html && rm -f roundcube-release.tar.gz" < /dev/null \
    || { echo "The Roundcube ${version} release could not be downloaded or unpacked." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Installing the webmail." ;
    roundcube_write_config || exit 1 ;
    ddev exec -d /var/www/html "bin/initdb.sh --dir=SQL" < /dev/null || { echo "The database of the webmail could not be made." ; exit 1 ; } ;

    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_roundcube_users ;
      add_roundcube_users ;
      cd ${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME} || exit 1 ;
    fi
    if [ "${SAMPLE_DATA}" == 'yes' ] ; then
      if [ "${ADD_USERS}" != 'yes' ] ; then
        echo "--sample-data needs --add-users: the sample data is the default accounts' mail." ;
      else
        roundcube_mail_site sample || { echo "The sample data could not be added." ; exit 1 ; } ;
        roundcube_keep_sample || echo "The sample data will not come back by itself after a restart: cmd-tools-roundcube-cli.sh ${PROJECT_NAME} --sample-data writes it." ;
      fi
    fi

    echo "${doc_name} ${PROJECT_NAME} has been installed: Roundcube ${version}.";
    echo "Go to ${base_url}/ and log in as ${account_mail}";
  else
    [ "${ADD_USERS}" == 'yes' ] && echo "--add-users needs --install: there is no webmail to add accounts to yet." ;
    [ "${SAMPLE_DATA}" == 'yes' ] && echo "--sample-data needs --install: there is no webmail to add it to yet." ;
    echo "${doc_name} ${PROJECT_NAME} is unpacked: Roundcube ${version}, not installed (--install makes its configuration and its database).";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Give the default accounts to the mail server, and make their users in the webmail the way a first login makes them,
# with the names their identities show (mail-site.php accounts). An account that is there is kept. The list is loaded
# by the caller (set_roundcube_users): the core's add_users, the builder, the webmail's tool.
function add_roundcube_users() {
  roundcube_enter_project || return 1 ;
  local user user_name user_mail user_password user_role user_fullname status=0 ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_role="user_${user}_role"; user_fullname="user_${user}_fullname";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role}";
    echo "   Display name: ${!user_fullname}";
    echo " ================================================================= ";
    roundcube_mail_account_add "${!user_mail}" "${!user_password}" || { echo "  the mail server did not take ${!user_mail}" ; status=1 ; } ;
  done
  roundcube_mail_site accounts || status=1 ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Delete the default accounts: from the webmail with what it keeps of them (Roundcube's own bin/deluser.sh), then from
# the mail server; the sample data is no longer written again after a start.
function cancel_roundcube_users() {
  roundcube_enter_project || return 1 ;
  local user user_name user_mail ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo " ================================================================= ";
    ddev exec -d /var/www/html "php bin/deluser.sh --host=${ROUNDCUBE_MAIL_HOST} $(printf '%q' "${!user_mail}")" < /dev/null ;
    roundcube_mail_account_remove "${!user_mail}" ;
  done
  # The sample data is theirs: nothing to write again after a start.
  roundcube_drop_sample ;
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# What cmd-tools-roundcube-cli.sh does: the first of --run, --add-users, --cancel-users, --sample-data, --tidy that was
# asked for; with none of them, what the accounts hold.
function roundcube_cli_tool() {
  trim_project_name ;
  roundcube_enter_project || exit 1 ;
  if ! ddev describe -j 2>/dev/null < /dev/null | grep -q '"status":"running"' ; then
    ddev start -y < /dev/null || exit 1 ;
  fi
  if [ ! "${RUN}" == '_none_' ] ; then
    # One string on purpose: --run "bin/gc.sh" is a command and its arguments, run in the webmail's folder.
    ddev exec -d /var/www/html "${RUN}" < /dev/null ;
    exit $? ;
  fi
  if ! roundcube_is_installed "$(pwd)" ; then
    echo "${doc_name}/${PROJECT_NAME}: the webmail is not installed yet: build it again with --install." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] ; then
    set_roundcube_users ;
    add_roundcube_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    set_roundcube_users ;
    cancel_roundcube_users ;
  elif [ "${SAMPLE_DATA}" == 'yes' ] ; then
    roundcube_mail_site sample || exit 1 ;
    roundcube_keep_sample ;
  elif [ "${TIDY}" == 'yes' ] ; then
    roundcube_mail_site reset || exit 1 ;
    roundcube_keep_sample ;
    echo "The webmail is back as the sample data left it." ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Roundcube $(roundcube_version "$(pwd)") at $(roundcube_url)/ (the mail server's accounts: $(roundcube_mail_accounts | tr ',' '\n' | sed 's/:[^@]*@/@/' | paste -sd ' ' -))" ;
    echo "" ;
    roundcube_mail_site status || exit 1 ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a webmail. The core's testing_configure calls this in the project folder once
# webship-js is scaffolded and before the dependencies are installed; for a project that is not a webmail it changes
# nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, the tags that
# keep its assertions that must fail out of a normal run, the webmail's folders by their role (the trash, the sent
# folder, the drafts), the users registry (a handle a scenario reads, mapped to an account; never the workspace
# account), and writes a first feature when the project has none of its own. Every part is skipped when it is already
# there, so a second run adds what the first missed and never resets a suite.
function testing_configure_roundcube() {
  local project_path="$1";
  roundcube_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Roundcube: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi
  echo "Adding the Roundcube step pack (${ROUNDCUBE_STEPS_PACKAGE} ${ROUNDCUBE_STEPS_VERSION}).";
  set_roundcube_users ;
  local registry="" user user_name user_mail user_password user_fullname ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail"; user_password="user_${user}_password"; user_fullname="user_${user}_fullname";
    registry="${registry}${user}|${!user_name}|${!user_password}|${!user_mail}|${!user_fullname}"$'\n' ;
  done

  python3 - "${project_path}" "${ROUNDCUBE_STEPS_PACKAGE}" "${ROUNDCUBE_STEPS_VERSION}" 'RC' "${registry}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry = sys.argv[1:6]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=2) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

# The pack's step definitions, after webship-js's own.
if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

# The pack's assertions that must fail are no part of a normal run.
if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        src = src[:default.end()] + '\n' + pad + "// Work in progress and the assertions that must fail (@must-fail) stay out of a normal run.\n" \
            + pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail'," + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the webmail's folders and the users registry to.")
pad = world.group(1) + '  '

# The webmail's folders by their role, which the restores read.
if not re.search(r"^[ \t]*mail:[ \t]*\{", src, re.M):
    block = pad + "// The webmail's folders by their role: a message deleted for good goes through the trash.\n" \
        + pad + "mail: { trash: 'Trash', sent: 'Sent', drafts: 'Drafts' },"
    src = src[:world.end()] + '\n' + block + src[world.end():]
    print("  cucumber.js: the webmail's folders (the trash, the sent folder, the drafts)")
    world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)

rows = [r.split('|') for r in registry.splitlines() if r.strip()]
entry = lambda handle, login, password, mail, name: "%s: { username: process.env.%s_%s_USER || '%s', password: process.env.%s_%s_PASSWORD || '%s', email: '%s', name: '%s' }," % (
    handle, prefix, handle.upper(), login, prefix, handle.upper(), password, mail, name)
users = re.search(r"^([ \t]*)users:[ \t]*\{[ \t]*$", src, re.M)
if users:
    missing = [r for r in rows if not re.search(r"^[ \t]*%s:[ \t]*\{" % re.escape(r[0]), src, re.M)]
    if missing:
        inner = users.group(1) + '  '
        src = src[:users.end()] + '\n' + '\n'.join(inner + entry(*r) for r in missing) + src[users.end():]
        print("  cucumber.js: the webmail's accounts in the users registry (%s)" % ', '.join(r[0] for r in missing))
else:
    block = [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the mail server (the default",
        pad + "// accounts: cmd-tools-add-users.sh <project> roundcube). Override one with %s_<HANDLE>_USER and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ] + [pad + '  ' + entry(*r) for r in rows] + [pad + "},"]
    src = src[:world.end()] + '\n' + '\n'.join(block) + src[world.end():]
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature for the webmail, when the project has none: the login, a message of the inbox, the address book.
  local feature="${WORKSPACE_SCRIPTS}/plugins/roundcube/webmail.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/webmail.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/webmail.feature" \
      && echo "  tests/features/webmail.feature: a first feature for the webmail" ;
  fi

  # The scenarios log in as the default accounts: make sure an installed webmail has them.
  if roundcube_is_installed "${project_path}" ; then
    ( add_roundcube_users > /dev/null ) && echo "  the default accounts of the webmail are there (${users[*]})" ;
  fi
}
