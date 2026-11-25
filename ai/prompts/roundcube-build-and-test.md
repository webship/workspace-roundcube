Build a Roundcube webmail in a sites folder and prove it with its first webship-js feature.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Build the Roundcube webmail named <name> in this sites folder and test it with webship-js
# ~/workspace/<dev|test|sandboxes|demos> · https://<name>.ddev.site/ · container-based (DDEV by default) · the webmail builds on DDEV
# the builder deletes a project of the same name first: stop if <name> is a webmail somebody still needs
# nothing on the host: no php or composer outside the webmail's container; nothing paid, no mail account anywhere
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

1. bash cmd-roundcube-project.sh <name> --install --add-users --sample-data
2. bash cmd-tools-roundcube-cli.sh <name>
   tell me the release, the address, the accounts of the mail server and what each mailbox holds
3. bash cmd-tools-testing.sh <name>
   webship-js, the webmail's step pack, the users registry, tests/features/webmail.feature
4. bash cmd-tools-testing.sh <name> --dry-run --path tests/features/webmail.feature
5. bash cmd-tools-testing.sh <name> --run --path tests/features/webmail.feature

If a command fails, show the line that failed and stop. Do not retry with other flags.
When the feature is green: the address, the release, how many scenarios and steps passed.
Then ask me whether to keep the webmail or remove it with: bash cmd-tools-remove.sh <name>
"""
```
