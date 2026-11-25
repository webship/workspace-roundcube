# @webship.co/workspace-roundcube

Roundcube for the [Webship Workspace](https://github.com/webship/workspace) dashboard: a builder that makes a real
webmail in a container — the latest Roundcube 1.x from the project's releases, with a mail server of its own beside it
(GreenMail, the IMAP and SMTP test server) and its database made by Roundcube's own installer script — a mailbox for
the workspace account, the default accounts (alice and bob), the sample data the tests name (mails in their mailboxes,
a folder, contacts and a group, a response), the webmail's own tool, the
[Roundcube step pack](https://github.com/webship/roundcube-steps) wired into the workspace's testing setup, and its AI
items — two agents, a skill, a command and two prompts — each listed in the workspace folder of its kind.

The workspace is container-based (DDEV by default): a webmail is a `php` project like any other, so the row menus the
core draws (start, stop, launch, backup, clone, remove, tests) work on it unchanged. The plugin claims its webmails with
a file of its own (`.ddev/config.roundcube.yaml`), so the Tests menu of the row offers the webmail's test users. A
webmail builds on DDEV for now: see [Runtimes](#runtimes).

## Use it

```bash
cd ~/workspace
bash core/scripts/plugins.sh --require @webship.co/workspace-roundcube --with-needs   # npm install into the dashboard
bash core/scripts/plugins.sh --activate roundcube --with-needs                         # plugins.roundcube in settings.yml, and what it needs
bash core/scripts/plugins.sh --install roundcube                                       # the builder, the tool, functions, args, AI items
bash core/scripts/plugins.sh --configure roundcube                                     # nothing to configure: it has no settings file
```

The same four steps are buttons on the dashboard's **Settings → Plugins** page. `--install` is
idempotent. `--uninstall` removes what it placed; an AI item you edited stays.

Everything the plugin carries lands in the folder it belongs to, when that folder is an active
workspace folder:

| What | Lands in |
| --- | --- |
| `cmd-roundcube-project.sh`, `cmd-tools-roundcube-cli.sh` | every active sites folder: `dev/`, `test/`, `sandboxes/`, `demos/` |
| The first feature of the webmail, and the script that writes the accounts' users and the sample data, a tidy-up, a status and the counts | `core/scripts/plugins/roundcube/`, beside its functions |
| The agents `roundcube-site-builder`, `roundcube-tester` | `ai-agents/` |
| The skill `roundcube-scenarios` | `ai-skills/` |
| The command `/roundcube-test` | `ai-commands/` |
| The prompts `roundcube-build-and-test`, `roundcube-mail-round` | `ai-prompts/` |

There they are listed like any other item of the folder, and installed into Claude Code from there.

## What it needs

A workspace starts empty, so the manifest says what else this plugin needs (`needs`):

- one sites folder, for the builder: `dev`, `test`, `sandboxes`, `demos` (`dev` is the one added when none is there). The folder also carries `cmd-tools-testing.sh` and the Users tools this plugin's hooks answer to.
- `ai-agents`, `ai-skills`, `ai-commands` and `ai-prompts`: the AI folders its agents, its skill, its command and its prompts are placed in.

`--require` says so, `--activate` and `--install` stop until the workspace has them, and `--with-needs` adds what is missing first:

```bash
bash core/scripts/plugins.sh --activate roundcube --with-needs   # dev and the four AI folders are required, activated and installed first
bash core/scripts/plugins.sh --install roundcube
```

Everything the builder runs for a webmail runs in the webmail's own containers, through the container tool the
workspace already needs: PHP and `curl` are in the web container, and the mail server is an image of its own
(`greenmail/standalone`, Apache-2.0). The plugin asks for no command of its own on the machine.

## What the package holds

| Path | What it is |
| --- | --- |
| `commands/cmd-roundcube-project.sh` | The builder, in the Build list as **Roundcube (webmail)**, installed into every sites folder |
| `commands/cmd-tools-roundcube-cli.sh` | The webmail's tool: what the accounts hold, a command in the webmail's folder, the default accounts, the sample data, a tidy-up |
| `scripts/functions/fun-roundcube.sh` | The bash functions behind them, sourced by bootstrap once installed; the names the core's tools look for (`set_roundcube_users`, `add_roundcube_users`, `cancel_roundcube_users`, `testing_configure_roundcube`) |
| `scripts/args/arg-roundcube.sh`, `arg-roundcube-cli.sh` | Their argparse; the Build form draws the builder's flags from the first |
| `scripts/mail-site.php` | The script the functions run in the webmail with PHP: the accounts' users, the sample data, a tidy-up, a status and the counts, each through Roundcube's own classes (the step pack's own script) |
| `testing/webmail.feature` | The first feature a webmail gets when testing is set up |
| `ai/agents/roundcube-site-builder.md` | The agent that builds and maintains webmails with these commands |
| `ai/agents/roundcube-tester.md` | The agent that writes and runs scenarios with the webmail's step pack |
| `ai/skills/roundcube-scenarios/` | The skill: the step pack's phrases by area, the traps found on a real webmail, three example features |
| `ai/commands/roundcube-test.md` | The slash command `/roundcube-test <site>`: set up, match every step, run, report |
| `ai/prompts/roundcube-build-and-test.md`, `roundcube-mail-round.md` | Two prompts: whole launch commands for a new session |
| `src/index.ts` | `register(api)`: what the assistant is told about Roundcube here |
| `features/roundcube.feature` | Scenarios for the dashboard's own browser suite |

The `workspacePlugin` block in `package.json` is the manifest the installer reads.

## The builder

Run it from a sites folder. `--help` is safe.

```bash
cd ~/workspace/dev
bash cmd-roundcube-project.sh mymail --install --add-users --sample-data
```

| Flag | What it does |
| --- | --- |
| `--install` | Install the webmail: its configuration, its database made by Roundcube's own `bin/initdb.sh`, and a mailbox for the workspace account (`account:` of `settings.yml`: its address and its password) on the mail server. Without it the release is unpacked, with the mail server and no account |
| `--add-users` | With `--install`: the default accounts on the mail server, and their users in the webmail with the names they show |
| `--sample-data` | With `--install` and `--add-users`: the mails of Alice's and Bob's mailboxes, a folder of Alice's own ("Projects"), two contacts and a group, and a response |
| `--version <x>` | The Roundcube 1.x release (`latest` by default: the newest stable 1.x of the project's releases) |
| `--php-version <x>` | The PHP of the project container: 8.3 (the default), 8.2 or 8.1 |
| `--runtime <name>` | The container runtime to build on: `ddev` only for now. See [Runtimes](#runtimes) |
| `--launch` | Open the webmail when it is ready |

The webmail answers at `https://mymail.ddev.site/`. The container tool has no project type for Roundcube, so a webmail
is a `php` project served by Apache (the release serves its styles and scripts at `static.php/<path>`, which Apache
passes on) with the release's `public_html/` as its docroot. Its configuration (`config/config.inc.php`) gives it the
container's own database (`db`), the mail server, the time zone UTC and a list of messages sorted by date (so a list
reads the same on every machine and every run), and a key of its own for each build; nothing personal is written. A
project of the same name is deleted first.

- **The mail server** is GreenMail, the IMAP and SMTP test server Roundcube's own CI runs its browser tests against: a
  service of the project (`.ddev/docker-compose.greenmail.yaml`), which the webmail reaches at `greenmail:3143` (IMAP)
  and `greenmail:3025` (SMTP). Its accounts are the list in that file (so they are there after a restart), and the
  tools give an account to the running server through its own API (so no restart is needed). It is a test server: mail
  goes to its own accounts only, and none leaves the machine.
- **It keeps its mail in memory.** Every start of the project (a restart, the row's Stop and Start, an add-on that
  restarts the project, as the testing setup's does) finds the mailboxes empty; the accounts stay. A webmail with the
  sample data gets it again after each start: a post-start hook of the plugin's claim runs the plugin's script, which
  writes what a mailbox is missing and keeps what it holds. Mail sent since the last start is gone.
- **The workspace account** is one more mailbox of the mail server: it logs in with its address and its password.
  The mail server reads its list of accounts as `login:password@domain`, so a workspace account without an address, or
  with a space, a backquote or one of `:`, `@`, `,`, `$`, `"`, `\` in its password, is said before anything is built.

Nothing paid and no account anywhere: the open-source release from the project's releases (the complete package, with
its libraries), the plugins and the skin it comes with (`archive`, `zipdownload`, Elastic), and the sample data
written by Roundcube's own classes.

### Runtimes

A webmail builds on **DDEV only, for now**: its stack is the webmail and a mail server of its own beside it, and a
service of a platform's own is something the workspace's other runtimes do not carry yet (the Workspace's
[`core/docs/plugins-on-runtimes.md`](https://github.com/webship/workspace/blob/1.0.x/core/docs/plugins-on-runtimes.md),
"What does not fit yet"; [webship/workspace#694](https://github.com/webship/workspace/issues/694)). `--runtime`
takes `ddev` only, and when the workspace's `container.runtime` names another runtime the builder says so and stops,
before anything is built:

```text
Roundcube builds on DDEV only for now: its stack (the webmail and a mail server of its own beside it) is not on the other runtimes yet (webship/workspace#694). Build with --runtime ddev.
```

| | DDEV |
| --- | --- |
| Build with `--install --add-users --sample-data` | Yes |
| A login as the workspace account and the default accounts | Yes |
| `cmd-tools-roundcube-cli.sh` (what the accounts hold, `--run "bin/gc.sh"`) | Yes |
| Test users, cancelled and added | Yes |
| Mail sent from one account and received by the other | Yes |
| The sample data back after a restart of the project (and after the testing setup's restarts) | Yes |
| The testing setup and the first feature | Yes |
| The step pack's examples, with the sample data (20 scenarios) | Yes |
| Export and import the database | Yes |
| The row in the dashboard, and remove | Yes |

"Yes" means it was run on a real webmail.

### The plugin's claim on the project

A webmail is a project of the type `php`, which says nothing of the platform. The builder leaves
`.ddev/config.roundcube.yaml` in the project: a config overlay of the container tool with one key
(`web_environment: WEBSHIP_WORKSPACE_PLATFORM=roundcube`, in the web container's environment from its next start;
nothing of the webmail reads it) and a post-start hook. The file's name is what the workspace reads: a project that
carries `config.<plugin>.yaml` takes the test users of that plugin, so the row's Tests menu offers the webmail's list
(`roundcube`). The hook runs `.ddev/roundcube/after-start.sh` when it is there: the sample data writes it, with a copy
of the plugin's script beside it, so a webmail with the sample data gets it again after every start (cancelling the
default accounts takes the folder away). For the plugin's own tools, a DDEV project whose folder holds Roundcube's `program/` and its
`public_html/` is a webmail too.

### The webmail's tool

`--run` runs a command in the webmail's folder in its container: one of Roundcube's own `bin/` scripts (`bin/gc.sh`
cleans its caches and sessions up, `bin/update.sh` updates its database after a new release) or another command of the
container.

The tool runs the plugin's `mail-site.php` with PHP in the webmail's container, which reads and writes with Roundcube's
own classes (its IMAP storage for the mailboxes, its user with the identities, responses and preferences, its contacts
and collected addresses), started the way Roundcube's own `bin/` scripts start.

```bash
bash cmd-tools-roundcube-cli.sh mymail                     # the release, the address, the accounts, what each mailbox holds
bash cmd-tools-roundcube-cli.sh mymail --run "bin/gc.sh"   # a command in the webmail's folder: here its clean-up
bash cmd-tools-roundcube-cli.sh mymail --add-users         # the default accounts; an account that is there is kept
bash cmd-tools-roundcube-cli.sh mymail --cancel-users      # delete them, from the webmail and from the mail server
bash cmd-tools-roundcube-cli.sh mymail --sample-data       # the sample mails, contacts and response, from now on after every start too
bash cmd-tools-roundcube-cli.sh mymail --tidy              # put the webmail back as the sample data left it
```

The tidy-up writes every folder of the two accounts again and removes a folder a test run made; deletes the contacts,
groups, identities and responses a run added, and for good what a run deleted (the webmail keeps a deleted row,
marked); takes the addresses a run collected away; and sets the two accounts' preferences back to the webmail's
defaults.

### The default accounts

| Account | Name it shows | In the sample data | Handle in the tests |
| --- | --- | --- | --- |
| `alice@example.com` | Alice Test | Four mails in her inbox (two unread, one flagged, one with an attachment), one in her sent folder, one in her folder "Projects"; the contacts Bob Test and Carol Test, the group "Webship team"; the response "Thanks" | `alice` |
| `bob@example.com` | Bob Test | One mail in his inbox | `bob` |

Each logs in with its address, with the password of the workspace's other default lists. They are for local webmails
and for tests; a test suite logs in as them and never creates or deletes one. The workspace account is one more
mailbox of the mail server, and it stays when the default accounts are added or cancelled.

The row's Tests menu offers **Add the test users** and **Cancel the test users** for a webmail this plugin claims: they
run the same list as

```bash
bash cmd-tools-add-users.sh mymail roundcube       # the core's tool, with the plugin's list
bash cmd-tools-cancel-users.sh mymail roundcube
```

Adding them gives the mail server each account and makes its user in the webmail the way a first login does, with the
name its identity shows. Cancelling deletes what the webmail keeps of each (Roundcube's own `bin/deluser.sh`: the
user, its identities, contacts and preferences), then takes the mailbox from the mail server.

### Test a webmail

```bash
bash cmd-tools-testing.sh mymail                 # webship-js, the step pack, the users registry, the first feature
bash cmd-tools-testing.sh mymail --run           # run the suite in the container
bash cmd-tools-testing.sh mymail --run --path tests/features/webmail.feature
bash cmd-tools-testing.sh mymail --list-steps    # the step packs the project has
```

`cmd-tools-testing.sh` is the workspace's own. For a webmail, this plugin's hook adds `@webship-js/roundcube-steps` to
`package.json` and its step definitions to `cucumber.js` after webship-js's own, the tags that keep the pack's
assertions that must fail out of a normal run, the webmail's folders by their role the steps read
(`worldParameters.mail`: the trash, the sent folder, the drafts), the handles of the default accounts in the users
registry (with the names they show; overridable with `RC_<HANDLE>_USER` and `RC_<HANDLE>_PASSWORD`), and
`tests/features/webmail.feature` (Alice's login and inbox, a message with an attachment opened, Bob's inbox, Alice's
address book); it makes sure the default accounts are on the mail server and in the webmail. It is idempotent: a
second run adds what is missing and keeps what was changed.

## The AI items

`ai/` in the package holds one folder per kind, the manifest's `ai` block names each item, and
`--install` places it in the workspace folder of that kind.

| Kind | Item | Use it to |
| --- | --- | --- |
| Agent | `roundcube-site-builder` | Build, update, maintain or remove a webmail with the builder and the webmail's tool, in containers only, with nothing paid and no account anywhere |
| Agent | `roundcube-tester` | Set the testing stack up, look at the webmail in the Playwright MCP browser first, write scenarios from the pack's steps and run them; it never creates an account in a suite and never writes a platform name into a step phrase |
| Skill | `roundcube-scenarios` | Write a scenario from phrases that exist: the pack's steps by area, the handles of the users registry, the traps found on a real webmail, and three features that pass on a fresh webmail with the sample data |
| Command | `/roundcube-test <site> [feature or @tag]` | Run the suite of a webmail from inside a session: set up when missing, match every step, run, report what failed and why |
| Prompt | `roundcube-build-and-test` | Start a session that builds a webmail, says what it holds, sets the testing stack up and runs the first feature |
| Prompt | `roundcube-mail-round` | Start a session that writes and runs the scenario of a round of mail: written, sent, received and answered |

After `--install` each is in its folder on the dashboard. **Install** there puts an agent, a skill
or a command into Claude Code (`~/.claude/agents`, `~/.claude/skills`, `~/.claude/commands`), or
from the command line:

```bash
cd ~/workspace/ai-agents   && bash cmd-tools-ai-items.sh roundcube-tester --install
cd ~/workspace/ai-skills   && bash cmd-tools-ai-items.sh roundcube-scenarios --install
cd ~/workspace/ai-commands && bash cmd-tools-ai-items.sh roundcube-test --install
```

A prompt is not installed: it is the whole `claude …` launch command of a new session, and the
dashboard's **New screen** form lists it as a template. By hand, fill the placeholders in and run
the command of the file from the folder it names.

The items are written for any AI CLI, with Claude Code as the default shape: the frontmatter and
the file layout are Claude Code's, the body of each item is plain Markdown that names no tool or
feature of one CLI, a command says in words what its arguments are, and the text between the
triple quotes of a prompt can be given to another AI CLI as it is.

Every step phrase the items show is checked against the definitions of the webmail's step pack and of webship-js
(`tests/fixtures/step-definitions.txt`), and every command and flag against the plugin's own and the workspace's.

## What is tied to the container tool

The builder and the tools call the container tool with plain verbs only (`ddev config`, `ddev start`, `ddev exec`,
`ddev describe`, `ddev launch`): no container is reached by its name. Five things are DDEV's by name: the claim file
lives in the tool's folder (`.ddev/config.roundcube.yaml`, the place the workspace looks for it), the mail server is a
service of the project in the same folder (`.ddev/docker-compose.greenmail.yaml`), the sample data comes back after a
start through a post-start hook of the claim (it runs `.ddev/roundcube/after-start.sh`, which the web container sees at
`/mnt/ddev_config/roundcube/`), the docroot is read from the project file (`.ddev/config.yaml`), and the address the
builder prints (`https://<name>.ddev.site`) is the one DDEV's router gives a project.

## Develop it

```bash
npm install     # builds dist/ (TypeScript)
npm run lint
npm test        # the manifest, the builder, the AI items, the functions against a scaffolded project
```

CI runs the same on Node.js 24 and 26, parses every shell script, and runs the plugin's `features/roundcube.feature`
against a dashboard with this plugin installed (`webship/workspace/.github/workflows/plugin-browser-suite.yml`).

When the step pack's release line changes, refresh the fixture from a project whose testing stack is
set up: `node <this plugin>/tests/fixtures/refresh-step-definitions.js > <this plugin>/tests/fixtures/step-definitions.txt`.
