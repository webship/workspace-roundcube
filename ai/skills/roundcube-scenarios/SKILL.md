---
name: roundcube-scenarios
description: Write and run webship-js scenarios for a Roundcube webmail of the Webship Workspace with the Roundcube step pack (`@webship-js/roundcube-steps`) — the phrases by area (the session, the mail list and a message, writing and sending, folders, identities, responses, preferences, the address book and its groups), the accounts by handle, the traps found on a real webmail, and three example features. Use when asked to "write a scenario for the webmail", "test sending mail on <site>", or "which step checks the unread count".
argument-hint: '<site> [what to cover]'
---

# roundcube-scenarios

Scenarios for a Roundcube webmail of a Webship Workspace (`~/workspace`, container-based, DDEV by default), written from
the steps of [`@webship-js/roundcube-steps`](https://github.com/webship/roundcube-steps) and of
[webship-js](https://github.com/webship/webship-js) itself, and run in the webmail's container by the workspace's own
command. It comes with the Roundcube plugin (`@webship.co/workspace-roundcube`), like the builder
(`cmd-roundcube-project.sh`), the webmail's tool (`cmd-tools-roundcube-cli.sh`) and the agents `roundcube-site-builder`
and `roundcube-tester`.

## Where everything is

| What | Where |
| --- | --- |
| The webmail | `~/workspace/<folder>/<site>`, at `https://<site>.ddev.site/` (`<folder>` is a sites folder: `dev`, `test`, `sandboxes`, `demos`) |
| The suite's configuration | `<site>/cucumber.js`: the step definitions it loads, the webmail's folders by their role (`worldParameters.mail`), the users registry (`worldParameters.users`) |
| The features | `<site>/tests/features/*.feature` (`webmail.feature` is the first one the setup wrote) |
| The webmail's steps | `<site>/node_modules/@webship-js/roundcube-steps/tests/step-definitions/*.steps.js` |
| webship-js's steps | `<site>/node_modules/webship-js/tests/step-definitions/*.js` |
| The reports | `<site>/tests/reports/` |

## The order of work

1. **Make sure the testing stack is there.** From the sites folder:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site>
   ```
   It adds webship-js, the step pack, the webmail's folders, the users registry with the handles of the default
   accounts and `tests/features/webmail.feature`, and makes sure the default accounts are on the mail server. It is safe
   to run again: it adds what is missing and keeps what was changed.
2. **Read the installed steps before writing a phrase.** They are the source of truth: the pack moves, and a phrase
   from memory is a guess.
   ```bash
   cd ~/workspace/<folder>/<site>
   grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/roundcube-steps/tests/step-definitions/*.steps.js
   ```
   Every step carries a comment block with five examples above it; open the file when a phrase is not obvious.
3. **Look at the screen first** (the Playwright MCP browser, a tab of your own) when the scenario is about one you have
   not seen.
4. **Write the feature** in `<site>/tests/features/`, from phrases that exist (the lists below).
5. **Match every step without a browser**, then run the feature, then the suite:
   ```bash
   cd ~/workspace/<folder>
   bash cmd-tools-testing.sh <site> --dry-run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --path tests/features/<name>.feature
   bash cmd-tools-testing.sh <site> --run --tags "@critical"
   bash cmd-tools-testing.sh <site> --run
   ```
   A dry run says `Undefined` for a phrase no definition matches: fix the phrase, do not write a step for it.

## Accounts: a handle, never a password

```gherkin
Feature: Accounts
  Scenario: Bob finds the mail Alice sent him
    Given I am logged in to the webmail as "bob"
    Then the message list should show "Notes from the meeting"
```

The handles of the default accounts: `alice` (`alice@example.com`, whose mail the scenarios read and write) and `bob`
(`bob@example.com`, the one she writes to and hears from). Never create an account in a scenario, and never log in as
the workspace account.

## The phrases, by area

The session:

```gherkin
Given I am logged in to the webmail as "alice"
Then I should be logged in to the webmail as "alice@example.com"
Then the webmail should say "Message sent successfully."
When I log out of the webmail
```

A wrong password is the subject of its own scenario: `When I log in to the webmail with the address "…" and the
password "…"`, then `Then the webmail should refuse the login with "Login failed."`.

The mail:

```gherkin
When I open the folder "Sent"
Then the folder "Inbox" should show 2 unread
Then the message list should show "Webship weekly report"
Then the message list should show "Lunch on Friday", "Webship weekly report" in this order
Then the message "Lunch on Friday" should be flagged
When I open the message "The test plan, attached"
Then the message should be from "Bob Test"
Then the message should say "test plan for the next release"
Then the message should list the attachment "test-plan.txt"
When I mark the message "Webship weekly report" as flagged
When I delete the message "Webship news: November"
When I move the message "Webship weekly report" to the folder "Projects"
When I search the mail for "Lunch"
```

Writing mail:

```gherkin
When I start a new message
When I write to "bob"
When I add "alice@example.com" as Cc
When I set the subject to "Webship test hello"
When I write the text "A test mail from the scenario."
When I send the message
When I reply to the message "Webship weekly report"
Then the subject should be "Re: Webship weekly report"
Then the message should go to "Bob Test"
Then the text should contain "Bob Test wrote:"
When I insert the response "Thanks"
When I save the message as a draft
When I discard the message
```

The settings:

```gherkin
When I create the folder "Webship test folder"
When I rename the folder "Projects" to "Webship test projects"
Then the folder list should show "Webship test folder"
When I delete the folder "Webship test folder"
When I add the identity "Webship test identity" with the address "alice@example.com"
Then the identities should list "Webship test identity <alice@example.com>"
When I add the response "Webship test response" with the text "I will answer tomorrow."
Then the responses should list "Webship test response"
When I set the preference "Time format" to "07:30 AM" in "User Interface"
Then the preference "Time format" in "User Interface" should be "07:30 AM"
```

The address book:

```gherkin
Then the contact list should show "Bob Test"
When I open the contact "Carol Test"
Then the contact should show "carol@example.com"
When I add the contact "Webship Tester" with the address "tester@example.com"
When I delete the contact "Webship Tester"
When I create the group "Webship test group"
When I add the contact "Carol Test" to the group "Webship test group"
Then the group "Webship test group" should list "Carol Test"
Then the address book should list the group "Webship team"
When I delete the group "Webship test group"
```

## Three example features

`examples/` beside this file holds three features that pass on a fresh webmail built with `--install --add-users
--sample-data`; copy one into `<site>/tests/features/` to start from it:

- `examples/session-and-mail.feature`: the inbox and its order, a message with an attachment opened, messages marked,
  a message deleted to the trash and one moved to a folder, the search and the sent folder, a login and a logout.
- `examples/writing-mail.feature`: a message written to Bob with a copy, sent, found in the sent folder and in Bob's
  inbox; a reply, a reply to all and a forward filled in, a response inserted; a draft kept.
- `examples/settings-and-contacts.feature`: an identity and a response added and deleted, preferences set, folders
  made, renamed and deleted, the contacts and the group read, a contact added and deleted, a group made, given a
  contact, and deleted.

## Traps found on a real webmail

- **Opening a message marks it read**, and so does the webmail's "display next" after a delete or a move, which opens
  the next message: the steps set a folder's marks back when the scenario ends, but an assertion of the unread count
  after a message was opened reads one less.
- **A message is named by its subject.** Two messages of one folder with the same subject are one to the steps: write
  a subject of the scenario's own ("Webship test …") for what a scenario sends.
- **Mail goes to the accounts of the mail server only.** It is a test server: a message to an address it does not hold
  goes nowhere, and only an account of the users registry gets its copy taken away when the scenario ends.
- **A start of the project empties the mailboxes** (the mail server keeps its mail in memory), and a webmail with the
  sample data gets it again by itself: mail a person sent before the restart is gone, the sample mail is back. When it
  is missing, `bash cmd-tools-roundcube-cli.sh <site> --sample-data` writes it, and from then on after every start.
- **A scenario deletes what it made.** A contact, a group, a folder, an identity or a response the webmail had and a
  scenario deleted is not put back.
- **Dates and times** read the webmail's time zone and today's date ("Today", "Mon 09:00"): assert subjects, senders
  and counts, not dates.

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Roundcube.** Start with `ch06-form-testing-recipes.md` (the compose screen and the settings' forms),
  `ch07-waiting-dynamic-content.md` (the webmail's Ajax answers and its "Loading..." message),
  `ch08-modal-dialog-testing.md` (its "Are you sure..." dialogs and its menus) and
  `ch10-authentication-authorization.md` (the login of each account, and a wrong password refused).
