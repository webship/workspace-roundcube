Feature: The identities, the responses and the preferences
  As a person with a mailbox
  I want to write as more than one identity, keep texts I write often, and set the webmail the way I like it
  So that writing mail is quick

  # An example of the roundcube-scenarios skill. It passes on a webmail built with --install --add-users --sample-data;
  # a folder, an identity, a response, a contact or a group a scenario makes is deleted when it ends, and a preference is set back.

  Scenario: An identity is added and deleted
    Given I am logged in to the webmail as "alice"
    Then the identities should list "Alice Test <alice@example.com>"
    When I add the identity "Webship test identity" with the address "alice@example.com"
    Then the identities should list "Webship test identity <alice@example.com>"
    When I delete the identity "Webship test identity"
    Then the identities should not list "Webship test identity"

  Scenario: A response is added and deleted
    Given I am logged in to the webmail as "alice"
    Then the responses should list "Thanks"
    When I add the response "Webship test response" with the text "I will answer tomorrow."
    Then the responses should list "Webship test response"
    When I delete the response "Webship test response"
    Then the responses should not list "Webship test response"

  Scenario: Preferences are set
    Given I am logged in to the webmail as "alice"
    Then the preference "Time format" in "User Interface" should be "07:30"
    When I set the preference "Time format" to "07:30 AM" in "User Interface"
    Then the webmail should say "Successfully saved."
    And the preference "Time format" in "User Interface" should be "07:30 AM"
    When I set the preference "Pretty dates" to "off" in "User Interface"
    Then the preference "Pretty dates" in "User Interface" should be "off"

  Scenario: A folder is made, given a folder of its own, and that one deleted
    Given I am logged in to the webmail as "alice"
    When I create the folder "Webship test folder"
    Then the webmail should say "Folder created successfully."
    And the folder list should show "Webship test folder"
    When I create the folder "Webship test archive" in "Webship test folder"
    And I delete the folder "Webship test archive"
    Then the folder list should not show "Webship test archive"

  Scenario: A folder is renamed
    Given I am logged in to the webmail as "alice"
    When I rename the folder "Projects" to "Webship test projects"
    Then the folder list should show "Webship test projects"
    And the folder list should not show "Projects"

  Scenario: The address book lists the contacts and their group
    Given I am logged in to the webmail as "alice"
    Then the contact list should show "Bob Test"
    And the contact list should show "Carol Test"
    When I open the contact "Carol Test"
    Then the contact should show "carol@example.com"
    And the address book should list the group "Webship team"
    And the group "Webship team" should list "Bob Test"
    And the group "Webship team" should not list "Carol Test"

  Scenario: A contact is added and deleted
    Given I am logged in to the webmail as "alice"
    When I add the contact "Webship Tester" with the address "tester@example.com"
    Then the webmail should say "Successfully saved."
    And the contact list should show "Webship Tester"
    When I delete the contact "Webship Tester"
    Then the contact list should not show "Webship Tester"

  Scenario: A group is made, given a contact, and deleted
    Given I am logged in to the webmail as "alice"
    When I create the group "Webship test group"
    Then the address book should list the group "Webship test group"
    When I add the contact "Carol Test" to the group "Webship test group"
    Then the group "Webship test group" should list "Carol Test"
    When I delete the group "Webship test group"
    Then the address book should not list the group "Webship test group"
