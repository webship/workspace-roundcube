Feature: Reading the mail
  As a person with a mailbox
  I want to read my messages, mark them, put them away and find them
  So that my mail is in order

  # An example of the roundcube-scenarios skill. It passes on a webmail built with --install --add-users --sample-data;
  # the marks of a folder's messages, and a message deleted or moved, come back when a scenario ends.

  @critical
  Scenario: The inbox lists the mail, the newest first
    Given I am logged in to the webmail as "alice"
    Then the folder "Inbox" should show 2 unread
    And the message list should show "Lunch on Friday", "The test plan, attached", "Webship weekly report" in this order
    And the message "Webship weekly report" should be unread
    And the message "Lunch on Friday" should be flagged
    And the message list should not show "Notes from the meeting"

  Scenario: A message with an attachment is opened
    Given I am logged in to the webmail as "alice"
    When I open the message "The test plan, attached"
    Then the message should be from "Bob Test"
    And the message should be to "Alice Test"
    And the message should have the subject "The test plan, attached"
    And the message should say "test plan for the next release"
    And the message should list the attachment "test-plan.txt"
    And the folder "Inbox" should show 1 unread
    And the message "The test plan, attached" should be read

  Scenario: Messages are marked
    Given I am logged in to the webmail as "alice"
    When I mark the message "Webship weekly report" as flagged
    Then the message "Webship weekly report" should be flagged
    When I mark the message "Lunch on Friday" as unflagged
    Then the message "Lunch on Friday" should be not flagged
    When I mark the message "Webship news: November" as unread
    Then the message "Webship news: November" should be unread

  Scenario: A deleted message goes to the trash
    Given I am logged in to the webmail as "alice"
    When I delete the message "Webship news: November"
    Then the webmail should say "Message(s) moved to Trash successfully."
    And the message list should not show "Webship news: November"
    When I open the folder "Trash"
    Then the message list should show "Webship news: November"

  Scenario: A message is moved to a folder of its own
    Given I am logged in to the webmail as "alice"
    When I move the message "Webship weekly report" to the folder "Projects"
    And I open the folder "Projects"
    Then the message list should show "Webship weekly report"
    And the message list should show "Webship project plan"

  Scenario: The mail is searched, and the sent mail read
    Given I am logged in to the webmail as "alice"
    When I search the mail for "Lunch"
    Then the message list should show "Lunch on Friday"
    And the message list should not show "Webship weekly report"
    When I open the folder "Sent"
    Then the message list should show "Notes from the meeting"

  @critical
  Scenario: Alice logs in, and out again
    Given I am logged in to the webmail as "alice"
    Then I should be logged in to the webmail as "alice@example.com"
    When I log out of the webmail
    Then the webmail should say "You have successfully terminated the session. Goodbye!"
