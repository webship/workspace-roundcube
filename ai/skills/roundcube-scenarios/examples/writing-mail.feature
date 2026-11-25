Feature: Writing mail
  As a person with a mailbox
  I want to write, answer and forward messages, and keep a draft
  So that the people I work with hear from me

  # An example of the roundcube-scenarios skill. It passes on a webmail built with --install --add-users --sample-data;
  # a message sent and a draft kept are deleted for good when a scenario ends.

  @critical
  Scenario: Alice writes to Bob, and Bob gets it
    Given I am logged in to the webmail as "alice"
    When I start a new message
    And I write to "bob"
    And I add "alice@example.com" as Cc
    And I set the subject to "Webship test hello"
    And I write the text "A test mail from the scenario."
    Then the message should go to "bob@example.com"
    When I send the message
    Then the webmail should say "Message sent successfully."
    And the message list should show "Webship test hello"
    When I open the folder "Sent"
    Then the message list should show "Webship test hello"
    When I log in to the webmail as "bob"
    Then the message list should show "Webship test hello"
    And the message "Webship test hello" should be unread

  Scenario: A reply is filled in, a response inserted, and the reply left
    Given I am logged in to the webmail as "alice"
    When I reply to the message "Webship weekly report"
    Then the subject should be "Re: Webship weekly report"
    And the message should go to "Bob Test"
    And the text should contain "Bob Test wrote:"
    When I insert the response "Thanks"
    Then the text should contain "Thank you, I will look at it today."
    When I discard the message
    Then the message list should show "Webship weekly report"

  Scenario: A reply to all and a forward are filled in
    Given I am logged in to the webmail as "alice"
    When I reply to all of the message "Lunch on Friday"
    Then the subject should be "Re: Lunch on Friday"
    And the message should go to "Bob Test"
    When I discard the message
    And I forward the message "The test plan, attached"
    Then the subject should be "Fwd: The test plan, attached"
    When I discard the message
    Then the message list should show "The test plan, attached"

  Scenario: A draft is kept
    Given I am logged in to the webmail as "alice"
    When I start a new message
    And I write to "bob@example.com"
    And I set the subject to "Webship test draft"
    And I write the text "Not finished yet."
    And I save the message as a draft
    Then the webmail should say "Message saved to Drafts."
    When I discard the message
    And I open the folder "Drafts"
    Then the message list should show "Webship test draft"
