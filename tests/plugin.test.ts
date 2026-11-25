import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { register, assistantContext, PLATFORM, COMMANDS, AGENTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const manifest = JSON.parse(read('package.json')).workspacePlugin;

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  const files: string[] = JSON.parse(read('package.json')).files;
  for (const f of named) assert.ok(files.includes(f.split('/')[0]), `${f} is published with the package`);
  // The webmail builds on DDEV only for now: no site of another runtime for the features job to build.
  assert.strictEqual(manifest.featuresSite, undefined);
});

test('the machine files land beside the functions, under the names the functions read', () => {
  const functions = read('scripts/functions/fun-roundcube.sh');
  assert.deepStrictEqual(manifest.scripts.machine.map((f: string) => path.basename(f)).sort(), ['mail-site.php', 'webmail.feature']);
  for (const f of manifest.scripts.machine) {
    assert.ok(functions.includes(`\${WORKSPACE_SCRIPTS}/plugins/roundcube/${path.basename(f)}`), `the functions read ${path.basename(f)} where the installer puts it`);
  }
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/roundcube\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(read('scripts/functions/fun-roundcube.sh'), new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-roundcube-project.sh'), /^# workspace-name: Roundcube/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-roundcube-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('the help of the builder and of the tool asks for nothing and changes nothing', () => {
  const args = read('scripts/args/arg-roundcube.sh');
  for (const flag of ['--install', '--add-users', '--sample-data', '--version', '--runtime', '--launch', '--php-version']) {
    assert.match(args, new RegExp(`'${flag}'`), `the builder has ${flag}`);
  }
  const tool = read('scripts/args/arg-roundcube-cli.sh');
  for (const flag of ['--run', '--add-users', '--cancel-users', '--sample-data', '--tidy']) {
    assert.match(tool, new RegExp(`'${flag}'`), `the webmail's tool has ${flag}`);
  }
  for (const src of [args, tool]) {
    assert.strictEqual((src.match(/parser\.add_argument\(/g) || []).length, (src.match(/help=/g) || []).length, 'every option says what it does');
    // The dashboard's Build form reads a help in single quotes (core/workspace-app/builder-args.js): one in double
    // quotes is drawn without its text, and an apostrophe inside one ends it early.
    assert.doesNotMatch(src, /help="/, 'every help is in single quotes, as the Build form reads it');
    for (const m of src.matchAll(/help='([^\n]*)'\)$/gm)) assert.doesNotMatch(m[1], /'/, `no apostrophe inside a help: ${m[1]}`);
  }
  assert.match(args, /parser\.add_argument\('--runtime',\s+dest='RUNTIME',\s+default="_none_",\s+choices=\['ddev'\],/, 'the one runtime it builds on, as the runtimes guide asks of a platform with a service of its own');
});

test('every shell script parses', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args]) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
});

test('the PHP script of the webmail parses', { skip: spawnSync('php', ['-v']).status !== 0 && 'no php on this machine' }, () => {
  const r = spawnSync('php', ['-l', path.join(PKG, 'scripts', 'mail-site.php')], { encoding: 'utf8' });
  assert.strictEqual(r.status, 0, r.stdout + r.stderr);
});

test('the functions carry the names the core\'s tools look for, and give the webmail only the container\'s database', () => {
  const src = read('scripts/functions/fun-roundcube.sh');
  for (const fn of ['set_roundcube_users', 'add_roundcube_users', 'cancel_roundcube_users', 'testing_configure_roundcube', 'roundcube_build', 'roundcube_cli_tool',
    'roundcube_is_project', 'roundcube_write_claim', 'roundcube_mail_site', 'roundcube_release', 'roundcube_write_mailserver', 'roundcube_write_config']) {
    assert.match(src, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(src, /--project-type=php /, 'the container tool has no project type for Roundcube');
  assert.match(src, /--webserver-type=apache-fpm/, 'Apache passes on the static\.php\/<path> addresses the release serves its scripts at');
  assert.match(src, /\\\$config\['db_dsnw'\] = 'mysql:\/\/db:db@db\/db';/, 'the database of the container');
  assert.match(src, /bin\/initdb\.sh --dir=SQL/, 'the database made by Roundcube\'s own installer script');
  assert.match(src, /php bin\/deluser\.sh --host=/, 'an account cancelled with Roundcube\'s own script');
  assert.match(src, /--nodejs-version=\$\(ddev_nodejs_version\)/, 'the build runs the Node.js of the workspace rule');
  assert.doesNotMatch(src, /ddev stop -y/, 'ddev stop takes no -y');
});

test('the mail server is the test server beside the webmail, and a build stops on another runtime', () => {
  const src = read('scripts/functions/fun-roundcube.sh');
  assert.match(src, /^readonly ROUNDCUBE_GREENMAIL_IMAGE='greenmail\/standalone:[0-9.]+';$/m, 'a pinned release of the test mail server');
  assert.match(src, /api\/user/, 'an account given to the running server through its own API');
  assert.match(src, /Roundcube builds on DDEV only for now/, 'the builder says why it does not build on another runtime');
  assert.match(src, /api\.github\.com\/repos\/roundcube\/roundcubemail\/releases/, 'the release list is the project\'s own');
  assert.match(src, /roundcubemail-\$\{version\}-complete\.tar\.gz/, 'the complete release, with its dependencies');
});

test('every container call is a plain verb of the container tool', () => {
  const src = read('scripts/functions/fun-roundcube.sh').replace(/^\s*#.*$/gm, '');
  assert.doesNotMatch(src, /docker (exec|compose|run)|ddev-[A-Za-z${}_-]*-web/, 'no container is reached by its name');
  const verbs = new Set([...src.matchAll(/\bddev ([a-z-]+)/g)].map((m) => m[1]));
  assert.deepStrictEqual([...verbs].sort(), ['config', 'describe', 'exec', 'launch', 'start'], 'the verbs the plugin runs');
  const files = new Set([...src.matchAll(/\.ddev\/([A-Za-z0-9._-]+)/g)].map((m) => m[1]));
  assert.deepStrictEqual([...files].sort(), ['config.roundcube.yaml', 'config.yaml', 'docker-compose.greenmail.yaml', 'roundcube']);
});

test('the script of the webmail uses the webmail\'s own classes, and creates no account on the mail server', () => {
  const src = read('scripts/mail-site.php');
  for (const mode of ['content', 'accounts', 'sample', 'reset', 'status', 'counts']) assert.ok(src.includes(`case '${mode}':`), `the mode ${mode}`);
  for (const part of ["require INSTALL_PATH . 'program/include/clisetup.php';", 'rcube_user::create(', 'new rcube_contacts(', 'new rcube_addresses(', '->save_message(']) assert.ok(src.includes(part), part);
  assert.doesNotMatch(src, /api\/user|greenmail\.users/, 'the mail server\'s accounts are the plugin\'s and the build\'s, never the script\'s');
});

test('each agent is a definition the AI Agents folder can list: named after its file, described, on the fable model', () => {
  for (const f of manifest.ai.agents) {
    const src = read(f);
    const head = src.split('\n---\n')[0];
    assert.match(head, /^---\n/, `${f} opens with frontmatter`);
    assert.match(head, new RegExp(`^name: ${path.basename(f, '.md')}$`, 'm'));
    assert.match(head, /^description: .{80,}$/m, `${f} says when to use it`);
    assert.match(head, /^model: fable$/m);
    assert.match(head, /^tools:\n(  - \S+\n?)+/m);
    assert.match(src, /cmd-tools-testing\.sh|cmd-roundcube-project\.sh/, `${f} names the plugin's commands`);
  }
  const tester = read('ai/agents/roundcube-tester.md');
  assert.match(tester, /Never create an account in a suite/);
  assert.match(tester, /No platform name in a step phrase/);
  assert.match(tester, /Playwright MCP browser first/);
  assert.match(tester, /Never the workspace account/);
  assert.match(tester, /\| `alice` \| `alice@example\.com` \|/, 'the tester knows the accounts by their handles');
  const builder = read('ai/agents/roundcube-site-builder.md');
  assert.match(builder, /never on the host/);
  assert.match(builder, /keeps its mail in memory/);
});

test('register() adds the assistant context and nothing else', () => {
  const calls: string[] = [];
  const api: any = { name: 'roundcube', addAssistantContext: (fn: () => string) => calls.push(fn()) };
  register(api);
  assert.strictEqual(calls.length, 1);
  assert.strictEqual(calls[0], assistantContext());
  for (const c of COMMANDS) assert.ok(calls[0].includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(calls[0].includes(a), `the assistant is told about ${a}`);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-roundcube.sh'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
  assert.match(read('README.md'), /container-based \(DDEV by default\)/);
  assert.match(read('README.md'), /\| `bob@example\.com` \| Bob Test \|/, 'the README lists the default accounts');
});
