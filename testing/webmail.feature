Feature: The webmail answers, and its accounts are in it
  As the owner of the webmail
  I want the login, the inbox and each default account to work
  So that a build that came out broken is caught before anything else is tested

  # Placed by the workspace's testing setup as a starting point: it is yours to change.
  # The accounts are the default ones (cmd-tools-roundcube-cli.sh --add-users); a scenario logs in by a handle of the
  # users registry in cucumber.js, so no password is written here. It passes on a webmail built with --install
  # --add-users --sample-data. A message it opens is marked unread again when it ends.

  @critical
  Scenario: Alice logs in and finds her inbox
    Given I am logged in to the webmail as "alice"
    Then I should be logged in to the webmail as "alice@example.com"
    And the folder "Inbox" should show 2 unread
    And the message list should show "Webship weekly report"

  Scenario: A message of the inbox is opened
    Given I am logged in to the webmail as "alice"
    When I open the message "The test plan, attached"
    Then the message should be from "Bob Test"
    And the message should list the attachment "test-plan.txt"

  Scenario: Bob logs in and finds the mail Alice sent him
    Given I am logged in to the webmail as "bob"
    Then the message list should show "Notes from the meeting"

  Scenario: Alice's address book
    Given I am logged in to the webmail as "alice"
    Then the contact list should show "Bob Test"
    And the address book should list the group "Webship team"
