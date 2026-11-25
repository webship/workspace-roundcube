Write and run the webship-js scenario of a round of mail on a Roundcube webmail: written, sent, received and answered.

The launch command below is for Claude Code, the default; the text between the triple quotes can be given to another AI CLI as it is.

```
claude --permission-mode bypassPermissions """
Write the scenario of a round of mail on the webmail of this site, and run it
# ~/workspace/<folder>/<site> · https://<site>.ddev.site/ · container-based (DDEV by default)
# the phrases are in the roundcube-scenarios skill; the roundcube-tester agent is the one to hand this work over to
# look at the webmail first: in the Playwright MCP browser, in a tab of your own, do the round by hand once before writing its scenario
# a feature to write or a run to read: the book Automated Functional Testing Recipes first (its README.md, then the matching chapter), from .claude/automated-functional-testing-recipes/ in the project, ~/.claude/automated-functional-testing-recipes/ or https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes

The round: <alice|bob> writes to <bob|alice> with the subject "Webship test <subject>", <with|without> a copy to herself,
sends it, finds it in the sent folder; the other one logs in, finds it unread, opens it and reads its text,
and fills in a reply (its subject "Re: …", the quoted text), <inserts the response "Thanks"|writes a line>, and discards it.

Read the installed steps first:
grep -hE '^(Given|When|Then)\(' node_modules/@webship-js/roundcube-steps/tests/step-definitions/*.steps.js

Write one feature in tests/features/<name>.feature, from phrases that exist.
Log in by the handle of the users registry (alice, bob):
no password in the feature, no account created by a scenario, no platform name in a step phrase.
The steps put back what they change when the scenario ends: the message sent goes for good (from the sent folder and the inbox), the marks of the inbox are set back.

Then, from the sites folder (cd ..):
bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature

A failing scenario is a result: tell me what the webmail did, do not loosen the scenario.
When you are done: the scenario, the result of the run, and any step you could not find in the pack
"""
```
