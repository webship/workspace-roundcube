/**
 * Roundcube for Webship Workspace: a platform plugin.
 *
 * What the package carries is placed by the installer from the manifest: the builder and the webmail's tool in the
 * sites folders, their functions and argparse under core/scripts/plugins/roundcube/, the webmail's first feature and
 * the script that writes the accounts' users and the sample data beside them, and its AI items (ai/ in this package)
 * in the folder of their kind: the agents in AI Agents, the skill in AI Skills, the command in AI Commands, the
 * prompts in AI Prompts. The dashboard needs nothing drawn for it: the builder is in the Build list because it is a
 * cmd-*-project.sh, the row menus are the core's, the AI items are listed like any other. What register() adds is
 * what the assistant is told.
 *
 * Everything the dashboard is asked for goes through `api`; this package requires nothing from the dashboard's own
 * files, so it can be installed from npm and removed without a trace.
 */

import type { PluginApi } from '@webship.co/workspace-plugin-api';

/**
 * The plugin's name: the folder of its scripts and the name its functions carry. A webmail is a php project of the
 * container tool: the plugin claims it with .ddev/config.roundcube.yaml, and the core's tools call its functions under
 * roundcube.
 */
export const PLATFORM = 'roundcube';

/** The commands the installer places in every sites folder. */
export const COMMANDS = ['cmd-roundcube-project.sh', 'cmd-tools-roundcube-cli.sh'];

/** The agents the installer places in the AI Agents folder. */
export const AGENTS = ['roundcube-site-builder', 'roundcube-tester'];

/** The skill the installer places in the AI Skills folder (a folder each, with its SKILL.md). */
export const SKILLS = ['roundcube-scenarios'];

/** The slash command the installer places in the AI Commands folder. */
export const AI_COMMANDS = ['roundcube-test'];

/** The prompts the installer places in the AI Prompts folder: each a whole launch command for a new session. */
export const PROMPTS = ['roundcube-build-and-test', 'roundcube-mail-round'];

/** What the assistant is told about Roundcube in this workspace. */
export function assistantContext(): string {
  return [
    'Roundcube (a plugin, @webship.co/workspace-roundcube): a webmail is built with',
    '`bash cmd-roundcube-project.sh <name> --install --add-users --sample-data` from a sites folder (dev, test, sandboxes, demos):',
    'the latest Roundcube from its releases, with a mail server of its own beside it (GreenMail, the test IMAP and SMTP server), its database made by its own installer,',
    'and a mailbox for the workspace account, in a container on DDEV at https://<name>.ddev.site/ (the other runtimes do not carry its mail server yet);',
    '`--add-users` adds the default accounts (alice@example.com and bob@example.com), `--sample-data` the mails, a folder, contacts and a group, and a response the step pack\'s features name.',
    'The mail server keeps its mail in memory: every start of the project finds the mailboxes empty, and a webmail with the sample data gets it again by itself (a post-start hook of the plugin); mail sent since the last start is gone.',
    '`bash cmd-tools-roundcube-cli.sh <name>` says what the accounts hold; with `--run "<command>"` it runs a command in the webmail\'s folder (`--run "bin/gc.sh"`), and with `--add-users`, `--cancel-users`, `--sample-data` or `--tidy` it changes it.',
    '`bash cmd-tools-testing.sh <name>` sets up webship-js with the Roundcube step pack; `--run` runs the suite.',
    `For Roundcube work, hand over to the agents ${AGENTS.map((a) => `\`${a}\``).join(' and ')}.`,
    `The plugin also places the skill ${SKILLS.map((a) => `\`${a}\``).join(', ')} (the step pack's phrases, by area) in ai-skills/,`,
    `the command ${AI_COMMANDS.map((a) => `\`/${a} <site>\``).join(', ')} in ai-commands/ and the prompts ${PROMPTS.map((a) => `\`${a}\``).join(' and ')} in ai-prompts/.`,
    'Never run php or composer on the host for a project; never connect the webmail to a mail account anywhere.',
  ].join(' ');
}

export function register(api: PluginApi): void {
  api.addAssistantContext(assistantContext);
}
