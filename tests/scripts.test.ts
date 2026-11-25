import test, { after } from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { spawnSync } from 'child_process';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const FUNCTIONS = path.join(PKG, 'scripts', 'functions', 'fun-roundcube.sh');

// The cucumber.js webship-js scaffolds, as far as the testing hook reads it.
const SCAFFOLD = `module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: [
      'node_modules/webship-js/tests/step-definitions/**/*.js',          // Webship-js core step definitions.
      'tests/step-definitions/**/*.js',                                  // Your custom step definitions.
    ],
    paths: ['tests/features/**/*.feature'],
    worldParameters: {
      launchUrl: process.env.LAUNCH_URL || 'http://localhost:8080',
    },
  },
};
`;

// Every folder a test makes goes when the tests are done.
const ROOTS: string[] = [];
after(() => {
  for (const root of ROOTS) fs.rmSync(root, { recursive: true, force: true });
});

/** The files of a release of Roundcube in a project folder; installed, its configuration. */
function webmailFiles(dir: string, installed: boolean) {
  fs.mkdirSync(path.join(dir, 'program', 'include'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'public_html'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'config'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'program', 'include', 'iniset.php'), "<?php\ndefine('RCMAIL_VERSION', '1.7.7');\n");
  fs.writeFileSync(path.join(dir, 'public_html', 'index.php'), '<?php\n');
  if (installed) fs.writeFileSync(path.join(dir, 'config', 'config.inc.php'), "<?php\n$config['db_dsnw'] = 'mysql://db:db@db/db';\n");
}

/** A project folder with the testing stack scaffolded, and the tooling folder the installer would have filled. */
function project(kind: 'roundcube' | 'uninstalled' | 'other' = 'roundcube') {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'roundcube-plugin-'));
  ROOTS.push(root);
  const dir = path.join(root, 'dev', 'mail1');
  fs.mkdirSync(path.join(dir, '.ddev'), { recursive: true });
  fs.writeFileSync(path.join(dir, '.ddev', 'config.yaml'), `name: mail1\ntype: ${kind === 'other' ? 'drupal11' : 'php'}\ndocroot: ${kind === 'other' ? 'web' : 'public_html'}\n`);
  if (kind !== 'other') webmailFiles(dir, kind === 'roundcube');
  fs.writeFileSync(path.join(dir, 'cucumber.js'), SCAFFOLD);
  fs.writeFileSync(path.join(dir, 'package.json'), JSON.stringify({ name: 'mail1', devDependencies: { 'webship-js': '^2.0.16' } }, null, 2));
  const scripts = path.join(root, 'core', 'scripts');
  fs.mkdirSync(path.join(scripts, 'plugins', 'roundcube'), { recursive: true });
  fs.copyFileSync(path.join(PKG, 'testing', 'webmail.feature'), path.join(scripts, 'plugins', 'roundcube', 'webmail.feature'));
  fs.copyFileSync(path.join(PKG, 'scripts', 'mail-site.php'), path.join(scripts, 'plugins', 'roundcube', 'mail-site.php'));
  return { root, dir, scripts };
}

// The recorder of the container tool: every call is written to DDEV_LOG; a run of the webmail's script also says
// whether the script is in the project's folder then. What a command is fed is read.
const RECORDER = `ddev() { echo "ddev $*" >> "\${DDEV_LOG:-/dev/null}" ; case "$*" in *'php .webship-mail-site.php'*) echo "the script is there: $(ls -a | grep -c '^\\.webship-mail-site\\.php$')" >> "\${DDEV_LOG:-/dev/null}" ;; esac ; [ "$1" == describe ] && echo '"status":"running"' ; [ -t 0 ] || cat > /dev/null ; return 0 ; }`;

/** Run bash with the plugin's functions sourced and `ddev` replaced by the recorder. */
function bash(script: string, env: Record<string, string> = {}) {
  return spawnSync('bash', ['-c', `${RECORDER}\nsource ${FUNCTIONS}\n${script}`],
    { encoding: 'utf8', env: { ...process.env, ...env }, stdio: ['ignore', 'pipe', 'pipe'] });
}

test('the default accounts are two mailboxes of the mail server, with example addresses and the names their identities show', () => {
  const r = bash('set_roundcube_users ; for u in "${users[@]}" ; do n="user_${u}_name" ; m="user_${u}_mail" ; p="user_${u}_password" ; f="user_${u}_fullname" ; echo "${!n}|${!m}|${!p}|${!f}" ; done');
  assert.strictEqual(r.status, 0, r.stderr);
  const rows = r.stdout.trim().split('\n').map((l) => l.split('|'));
  assert.deepStrictEqual(rows.map((x) => x[0]), ['alice@example.com', 'bob@example.com'], 'each logs in with its address');
  assert.deepStrictEqual(rows.map((x) => x[3]), ['Alice Test', 'Bob Test']);
  for (const row of rows) assert.ok(bash(`roundcube_password_fits ${JSON.stringify(row[2])}`).status === 0, 'the mail server takes the password in its list');
  // The script of the webmail writes the same accounts' users: the list and the script never part.
  const script = fs.readFileSync(path.join(PKG, 'scripts', 'mail-site.php'), 'utf8');
  for (const [, mail, , name] of rows) assert.ok(script.includes(`'${mail}' => '${name}'`), `the script knows ${mail} as ${name}`);
});

test('a webmail is a DDEV project whose folder holds Roundcube\'s program and its public_html', () => {
  assert.strictEqual(bash(`roundcube_is_project ${project('roundcube').dir}`).status, 0);
  assert.strictEqual(bash(`roundcube_is_project ${project('uninstalled').dir}`).status, 0, 'a release not installed yet is one too');
  assert.strictEqual(bash(`roundcube_is_project ${project('other').dir}`).status, 1);
  assert.strictEqual(bash(`roundcube_is_installed ${project('roundcube').dir}`).status, 0);
  assert.strictEqual(bash(`roundcube_is_installed ${project('uninstalled').dir}`).status, 1);
  assert.strictEqual(bash(`roundcube_version ${project('roundcube').dir}`).stdout, '1.7.7\n', 'the release, as its own code names it');
});

test('a password the mail server cannot list is said, one it can is taken', () => {
  for (const ok of ['dD.123123ddd', 'Ci-Webship-Workspace-2026', 'CHANGE_ME']) assert.strictEqual(bash(`roundcube_password_fits '${ok}'`).status, 0, ok);
  for (const bad of ['a:b', 'a@b', 'a,b', 'a b', 'a$b']) assert.notStrictEqual(bash(`roundcube_password_fits '${bad}'`).status, 0, bad);
});

test('the testing hook adds the step pack, the tags, the webmail\'s folders, the users registry and a first feature, once', () => {
  const p = project('roundcube');
  const log = path.join(p.root, 'ddev.log');
  const run = () => bash(`cd ${p.dir} && testing_configure_roundcube ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1', DDEV_LOG: log });
  const r = run();
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const pkg = JSON.parse(fs.readFileSync(path.join(p.dir, 'package.json'), 'utf8'));
  assert.strictEqual(pkg.devDependencies['@webship-js/roundcube-steps'], '^2.0.0');
  const cucumber = fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8');
  const lines = cucumber.split('\n');
  const core = lines.findIndex((l) => l.includes('node_modules/webship-js/tests/step-definitions'));
  assert.strictEqual(lines[core + 1], "      'node_modules/@webship-js/roundcube-steps/tests/step-definitions/**/*.js',", 'the pack is listed right after webship-js');
  assert.match(cucumber, /^\s*tags: process\.env\.CUCUMBER_TAGS \|\| 'not @wip and not @must-fail',$/m);
  assert.match(cucumber, /^\s*mail: \{ trash: 'Trash', sent: 'Sent', drafts: 'Drafts' \},$/m);
  assert.match(cucumber, /^\s*alice: \{ username: process\.env\.RC_ALICE_USER \|\| 'alice@example\.com', password: process\.env\.RC_ALICE_PASSWORD \|\| '[^']+', email: 'alice@example\.com', name: 'Alice Test' \},$/m);
  assert.doesNotMatch(cucumber, /webmaster|account_/, 'the workspace account is in no registry');
  const loaded = spawnSync(process.execPath, ['-e', `const c = require(${JSON.stringify(path.join(p.dir, 'cucumber.js'))}).default; const w = c.worldParameters; console.log(JSON.stringify([c.require, Object.keys(w.users), w.mail.trash, w.users.bob.name, c.tags]))`], { encoding: 'utf8' });
  assert.strictEqual(loaded.status, 0, loaded.stderr);
  const [requires, handles, trash, bob, tags] = JSON.parse(loaded.stdout);
  assert.strictEqual(requires.length, 3);
  assert.deepStrictEqual(handles, ['alice', 'bob'], 'the handles the pack\'s features log in as');
  assert.strictEqual(trash, 'Trash');
  assert.strictEqual(bob, 'Bob Test');
  assert.match(tags, /not @must-fail/);
  assert.ok(fs.existsSync(path.join(p.dir, 'tests', 'features', 'webmail.feature')));
  // An installed webmail gets the default accounts: the mail server takes them, the webmail makes their users.
  const calls = fs.readFileSync(log, 'utf8');
  assert.match(calls, /api\/user/);
  assert.match(calls, /^ddev exec -d \/var\/www\/html php \.webship-mail-site\.php accounts$/m);
  assert.match(calls, /^the script is there: 1$/m);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8'), /-Dgreenmail\.users=alice:[^@]+@example\.com,bob:[^@]+@example\.com"/);
  // Again, after a person changed the feature: nothing is doubled, nothing is reset.
  fs.writeFileSync(path.join(p.dir, 'tests', 'features', 'webmail.feature'), 'Feature: mine\n');
  assert.strictEqual(run().status, 0);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), cucumber);
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'tests', 'features', 'webmail.feature'), 'utf8'), 'Feature: mine\n');
  assert.strictEqual((fs.readFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8').match(/alice:/g) || []).length, 1, 'an account the mail server has is not listed twice');
});

test('the testing hook leaves a project of another platform alone', () => {
  const p = project('other');
  const r = bash(`cd ${p.dir} && testing_configure_roundcube ${p.dir}`, { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1' });
  assert.strictEqual(r.status, 0);
  assert.strictEqual(r.stdout, '');
  assert.strictEqual(fs.readFileSync(path.join(p.dir, 'cucumber.js'), 'utf8'), SCAFFOLD);
});

test('the user tools give the accounts to the mail server and the webmail, take them back, and refuse a project that is not a webmail', () => {
  const p = project('roundcube');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1', DDEV_LOG: log };
  fs.writeFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), '      GREENMAIL_OPTS: "-Dgreenmail.users=webmaster:Long.enough1@example.com"\n');
  let r = bash('set_roundcube_users ; add_roundcube_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  assert.match(r.stdout, /User name: alice@example\.com/);
  const compose = fs.readFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8');
  assert.match(compose, /-Dgreenmail\.users=webmaster:Long\.enough1@example\.com,alice:[^@]+@example\.com,bob:[^@]+@example\.com"/, 'the workspace account stays, the default ones join it');
  assert.match(fs.readFileSync(log, 'utf8'), /^ddev exec -d \/var\/www\/html php \.webship-mail-site\.php accounts$/m);
  fs.writeFileSync(log, '');
  r = bash('set_roundcube_users ; cancel_roundcube_users', env);
  assert.strictEqual(r.status, 0, r.stderr + r.stdout);
  const cancelled = fs.readFileSync(log, 'utf8');
  assert.match(cancelled, /^ddev exec -d \/var\/www\/html php bin\/deluser\.sh --host=greenmail alice@example\.com$/m, 'Roundcube\'s own script deletes what the webmail keeps of an account');
  assert.match(cancelled, /-X DELETE http:\/\/greenmail:8080\/api\/user\/bob@example\.com/);
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8'), /-Dgreenmail\.users=webmaster:Long\.enough1@example\.com"/, 'the workspace account stays');
  assert.deepStrictEqual(fs.readdirSync(p.dir).filter((f) => f.startsWith('.webship-')), [], 'the script is gone from the folder afterwards');
  const other = project('other');
  const refused = bash('set_roundcube_users ; add_roundcube_users', { WORKSPACE_ROOT: other.root, WORKSPACE_SCRIPTS: other.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1' });
  assert.strictEqual(refused.status, 1);
  assert.match(refused.stdout, /is not a Roundcube webmail/);
});

test('the webmail\'s tool runs the first of its flags, and says what the accounts hold without one', () => {
  const p = project('roundcube');
  const log = path.join(p.root, 'ddev.log');
  fs.writeFileSync(path.join(p.dir, '.ddev', 'docker-compose.greenmail.yaml'), '      GREENMAIL_OPTS: "-Dgreenmail.users=webmaster:Secret.1@example.com,alice:dD.123123ddd@example.com"\n');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1', DDEV_LOG: log };
  const run = (flags: string) => {
    fs.writeFileSync(log, '');
    const r = bash(`trim_project_name() { :; } ; RUN=_none_ ; ADD_USERS=no ; CANCEL_USERS=no ; SAMPLE_DATA=no ; TIDY=no ; ${flags} roundcube_cli_tool`, env);
    assert.strictEqual(r.status, 0, r.stderr + r.stdout);
    return { out: r.stdout, calls: fs.readFileSync(log, 'utf8') };
  };
  const status = run('');
  assert.match(status.calls, /^ddev exec -d \/var\/www\/html php \.webship-mail-site\.php status$/m);
  assert.match(status.out, /^dev\/mail1: Roundcube 1\.7\.7 at https:\/\/mail1\.ddev\.site\/ \(the mail server's accounts: webmaster@example\.com alice@example\.com\)$/m);
  assert.doesNotMatch(status.out, /Secret\.1|dD\.123123ddd/, 'no password is printed');
  assert.match(run('RUN="bin/gc.sh"').calls, /^ddev exec -d \/var\/www\/html bin\/gc\.sh$/m, 'a command in the webmail\'s folder');
  const kept = path.join(p.dir, '.ddev', 'roundcube');
  assert.ok(!fs.existsSync(kept));
  assert.match(run('SAMPLE_DATA=yes').calls, /php \.webship-mail-site\.php sample$/m);
  assert.deepStrictEqual(fs.readdirSync(kept).sort(), ['after-start.sh', 'mail-site.php'], 'the sample data comes back after every start from now on');
  assert.match(fs.readFileSync(path.join(p.dir, '.ddev', 'config.roundcube.yaml'), 'utf8'), /post-start:/, 'and the claim carries the hook, an older claim too');
  assert.match(run('TIDY=yes').calls, /php \.webship-mail-site\.php reset$/m);
  assert.match(run('ADD_USERS=yes').calls, /php \.webship-mail-site\.php accounts$/m);
  assert.ok(fs.existsSync(kept), 'adding the accounts again keeps it');
  assert.match(run('CANCEL_USERS=yes').calls, /bin\/deluser\.sh/);
  assert.ok(!fs.existsSync(kept), 'with the accounts cancelled, there is no sample data to write again');
  assert.doesNotMatch(run('ADD_USERS=yes SAMPLE_DATA=yes').calls, /php \.webship-mail-site\.php sample/, 'one thing at a time: the first flag');
});

test('another runtime, a version of another line, or a workspace account the mail server cannot list, is refused before anything is built', () => {
  const p = project('other');
  const log = path.join(p.root, 'ddev.log');
  const env = { WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', DDEV_LOG: log, PROJECT_NAME: 'mail2', RUNTIME: '_none_', account_mail: 'webmaster@example.com', account_pass: 'Long.enough1' };
  let r = bash('RUNTIME=docker ; trim_project_name() { :; } ; roundcube_build', env);
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /Roundcube builds on DDEV only for now/);
  r = bash('runtime_of() { echo kubernetes ; } ; trim_project_name() { :; } ; roundcube_build', env);
  assert.strictEqual(r.status, 1, 'the workspace\'s own runtime counts too');
  assert.match(r.stdout, /Build with --runtime ddev/);
  r = bash('VERSION=2.0.0 ; trim_project_name() { :; } ; roundcube_build', env);
  assert.strictEqual(r.status, 1);
  assert.match(r.stdout, /This builder makes a Roundcube 1\.x webmail/);
  for (const account of ['account_mail=nobody', "account_pass='a:b'", "account_pass='a b'"]) {
    r = bash(`VERSION=latest ; INSTALL=yes ; ${account} ; trim_project_name() { :; } ; roundcube_build`, env);
    assert.strictEqual(r.status, 1, account);
    assert.match(r.stdout, /The mail server takes an account with an address and a password/, account);
  }
  assert.ok(!fs.existsSync(log), 'the container tool was not called');
  assert.ok(!fs.existsSync(path.join(p.root, 'dev', 'mail2')), 'no folder was made');
});

test('a release is chosen from the project\'s releases: the newest stable one of the line by number, the one named, or the proven one', () => {
  const list = JSON.stringify([
    { tag_name: '1.7.10', prerelease: false, draft: false },
    { tag_name: '1.7.7', prerelease: false, draft: false },
    { tag_name: '1.6.22', prerelease: false, draft: false },
    { tag_name: '1.8-beta', prerelease: true, draft: false },
    { tag_name: '2.0.0', prerelease: false, draft: false },
  ]);
  const pick = (wanted: string, answer: string) => spawnSync('bash', ['-c', `ddev() { printf '%s' "$LIST" ; }\nsource ${FUNCTIONS}\nroundcube_release ${wanted}`], { encoding: 'utf8', env: { ...process.env, LIST: answer } });
  assert.strictEqual(pick('latest', list).stdout.trim(), '1.7.10', 'by number, not by text, and never another line or a pre-release');
  assert.strictEqual(pick('1.6.22', list).stdout.trim(), '1.6.22');
  assert.strictEqual(pick('latest', 'rate limit exceeded').stdout.trim(), '1.7.7', 'the release the plugin was proven on, when the list cannot be read');
});

/** The builder in a throwaway workspace, with `ddev` replaced by a recorder that leaves what the container tool would. */
function build(env: Record<string, string> = {}) {
  const p = project('other');
  fs.rmSync(p.dir, { recursive: true });
  const log = path.join(p.root, 'ddev.log');
  const prelude = [
    `ddev() { echo "ddev $*" >> "${log}" ;`,
    `  [ "$1" == config ] && mkdir -p .ddev && printf 'name: mail1\\ntype: php\\ndocroot: public_html\\n' > .ddev/config.yaml ;`,
    `  case "$*" in *'tar -xzf roundcube-release.tar.gz'*) mkdir -p program/include public_html config && echo "<?php define('RCMAIL_VERSION', '1.7.7');" > program/include/iniset.php && touch public_html/index.php ;; esac ;`,
    '  [ -t 0 ] || cat > /dev/null ; return 0 ; }',
    'trim_project_name() { :; } ; drop_database() { echo "drop_database" >> "$DDEV_LOG" ; } ; ddev_nodejs_version() { echo 24 ; } ; ddev_up() { ddev "$@" ; }',
    `source ${FUNCTIONS}`,
    'roundcube_release() { echo "${1/latest/1.7.7}" ; }',
    'roundcube_build',
  ].join('\n');
  const r = spawnSync('bash', ['-c', prelude], { encoding: 'utf8', env: { ...process.env, WORKSPACE_ROOT: p.root, WORKSPACE_SCRIPTS: p.scripts, doc_name: 'dev', PROJECT_NAME: 'mail1', DDEV_LOG: log,
    INSTALL: 'yes', ADD_USERS: 'no', SAMPLE_DATA: 'no', LAUNCH: 'no', VERSION: 'latest', PHP_VERSION: '8.3', distribution_webroot: 'public_html',
    RUNTIME: '_none_', account_name: 'webmaster', account_pass: 'Change_Me.123', account_mail: 'webmaster@example.com', ...env },
    stdio: ['ignore', 'pipe', 'pipe'] });
  const calls = fs.existsSync(log) ? fs.readFileSync(log, 'utf8').trim().split('\n').filter((c) => /^(ddev|drop_database)( |$)/.test(c)) : [];
  return { r, calls, dir: path.join(p.root, 'dev', 'mail1') };
}

test('a webmail is built in order: a php project served by Apache, the claim, the mail server, the release, the configuration, the database', () => {
  const b = build();
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  const at = (re: RegExp) => b.calls.findIndex((c) => re.test(c));
  assert.strictEqual(b.calls[0], 'drop_database', 'a build is a clean slate');
  assert.match(b.calls[1], /^ddev config --project-type=php --docroot=public_html --project-name=mail1 --webserver-type=apache-fpm --php-version=8\.3 --database=mariadb:10\.11 --nodejs-version=24$/);
  assert.strictEqual(b.calls[2], 'ddev start -y');
  assert.ok(at(/roundcubemail-1\.7\.7-complete\.tar\.gz/) > 2, 'the complete release of the project');
  assert.ok(at(/^ddev exec -d \/var\/www\/html bin\/initdb\.sh --dir=SQL$/) > at(/roundcubemail-1\.7\.7-complete/), 'the database by Roundcube\'s own script');
  assert.ok(!b.calls.some((c) => c.includes('.webship-mail-site.php')), 'no account and no sample data were asked for');
  const claim = fs.readFileSync(path.join(b.dir, '.ddev', 'config.roundcube.yaml'), 'utf8');
  assert.match(claim, /^web_environment:\n {2}- WEBSHIP_WORKSPACE_PLATFORM=roundcube\n/m);
  assert.match(claim, /^hooks:\n {2}post-start:\n {4}- exec: "\[ ! -f \/mnt\/ddev_config\/roundcube\/after-start\.sh \] \|\| bash \/mnt\/ddev_config\/roundcube\/after-start\.sh"\n/m,
    'after a start, the hook writes the sample data again, and does nothing for a webmail without it');
  assert.ok(!fs.existsSync(path.join(b.dir, '.ddev', 'roundcube')), 'no sample data, nothing for the hook to write again');
  const mailserver = fs.readFileSync(path.join(b.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8');
  assert.match(mailserver, /image: greenmail\/standalone:[0-9.]+/);
  assert.match(mailserver, /-Dgreenmail\.users=webmaster:Change_Me\.123@example\.com"/, 'the workspace account is a mailbox of the mail server');
  const config = fs.readFileSync(path.join(b.dir, 'config', 'config.inc.php'), 'utf8');
  for (const line of ["$config['db_dsnw'] = 'mysql://db:db@db/db';", "$config['imap_host'] = 'greenmail:3143';", "$config['smtp_host'] = 'greenmail:3025';", "$config['timezone'] = 'UTC';", "$config['message_sort_col'] = 'date';", "$config['create_default_folders'] = true;"]) {
    assert.ok(config.includes(line), line);
  }
  assert.match(config, /\$config\['des_key'\] = '[A-Za-z0-9]{24}';/, 'a key of its own for each build');
  assert.match(b.r.stdout, /Go to https:\/\/mail1\.ddev\.site\/ and log in as webmaster@example\.com/);
});

test('--add-users and --sample-data give the default accounts to the mail server, then write their users and the sample data', () => {
  const b = build({ ADD_USERS: 'yes', SAMPLE_DATA: 'yes' });
  assert.strictEqual(b.r.status, 0, b.r.stderr + b.r.stdout);
  const at = (re: RegExp) => b.calls.findIndex((c) => re.test(c));
  assert.match(fs.readFileSync(path.join(b.dir, '.ddev', 'docker-compose.greenmail.yaml'), 'utf8'), /-Dgreenmail\.users=webmaster:Change_Me\.123@example\.com,alice:[^@]+@example\.com,bob:[^@]+@example\.com"/, 'all the accounts, from the start of the mail server');
  assert.ok(at(/php \.webship-mail-site\.php accounts$/) > at(/bin\/initdb\.sh/));
  assert.ok(at(/php \.webship-mail-site\.php sample$/) > at(/php \.webship-mail-site\.php accounts$/));
  assert.deepStrictEqual(fs.readdirSync(b.dir).filter((f) => f.startsWith('.webship-')), [], 'the script is gone afterwards');
  // The mail server keeps its mail in memory: the hook of the claim writes the sample data again after every start.
  assert.deepStrictEqual(fs.readdirSync(path.join(b.dir, '.ddev', 'roundcube')).sort(), ['after-start.sh', 'mail-site.php']);
  assert.strictEqual(fs.readFileSync(path.join(b.dir, '.ddev', 'roundcube', 'mail-site.php'), 'utf8'), fs.readFileSync(path.join(PKG, 'scripts', 'mail-site.php'), 'utf8'));
  const after = path.join(b.dir, '.ddev', 'roundcube', 'after-start.sh');
  assert.strictEqual(spawnSync('bash', ['-n', after]).status, 0, 'the hook\'s script parses');
  const hook = fs.readFileSync(after, 'utf8');
  assert.match(hook, /php \.webship-mail-site\.php sample /, 'it writes the sample data, keeping what a mailbox holds');
  assert.match(hook, /\/dev\/tcp\/greenmail\/3143/, 'it waits for the mail server\'s IMAP port');
  assert.doesNotMatch(hook, /set -e|exit 1/, 'it never stops a start');
  assert.match(hook.trim(), /exit 0$/);
});

test('without --install the release is unpacked only; --sample-data needs the default accounts', () => {
  const unpacked = build({ INSTALL: 'no', ADD_USERS: 'yes', SAMPLE_DATA: 'yes' });
  assert.strictEqual(unpacked.r.status, 0, unpacked.r.stderr + unpacked.r.stdout);
  assert.ok(!unpacked.calls.some((c) => /initdb|webship-mail-site/.test(c)), 'nothing is installed');
  assert.ok(!fs.existsSync(path.join(unpacked.dir, 'config', 'config.inc.php')));
  assert.match(unpacked.r.stdout, /--add-users needs --install/);
  const alone = build({ SAMPLE_DATA: 'yes' });
  assert.strictEqual(alone.r.status, 0, alone.r.stderr + alone.r.stdout);
  assert.match(alone.r.stdout, /--sample-data needs --add-users/);
  assert.ok(!alone.calls.some((c) => c.includes('.webship-mail-site.php sample')));
});

test('the first feature names no platform in a step, logs in as each account by its handle, and creates no account', () => {
  const feature = fs.readFileSync(path.join(PKG, 'testing', 'webmail.feature'), 'utf8');
  const steps = feature.split('\n').filter((l) => /^\s*(Given|When|Then|And|But) /.test(l));
  assert.ok(steps.length >= 10);
  for (const s of steps) assert.doesNotMatch(s, /roundcube/i, s);
  for (const handle of ['alice', 'bob']) assert.match(feature, new RegExp(`logged in to the webmail as "${handle}"`), `${handle} logs in`);
  assert.doesNotMatch(feature, /webmaster/, 'the workspace account is never written into a test');
  assert.doesNotMatch(feature, /password "|I register|create an account/i, 'no password, and a suite never creates an account');
  assert.match(fs.readFileSync(FUNCTIONS, 'utf8'), /tests\/features\/webmail\.feature/);
});
