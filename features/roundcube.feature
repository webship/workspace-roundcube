Feature: The Roundcube plugin on the dashboard
  Once the plugin is activated and installed, the sites folders offer the Roundcube builder, each AI folder lists the
  items of its kind the plugin ships, and the Settings page lists the plugin with its own page.

  # Settings lists every plugin that was added; the package and what the plugin ships are on its own page.
  Scenario: Settings lists the plugin, and its own page names its package and what it ships
    Given I am on "/settings"
     Then I should see "Roundcube"
     When I go to "/settings/plugin/roundcube"
     Then I should see "@webship.co/workspace-roundcube"
      And I should see "cmd-roundcube-project.sh"
      And I should see "cmd-tools-roundcube-cli.sh"
      And I should see "roundcube-site-builder"

  Scenario: A sites folder offers the Roundcube builder
    Given I am on "/dev"
     Then "option[value='cmd-roundcube-project.sh']" should be attached

  # The AI folders are searched by name: with every plugin on, a folder lists more than one page of items.
  Scenario: The AI Agents folder lists the agents the plugin ships
    Given I am on "/ai-agents?q=roundcube-"
     Then I should see "roundcube-site-builder"
      And I should see "roundcube-tester"

  Scenario: The AI Skills folder lists the skill the plugin ships
    Given I am on "/ai-skills?q=roundcube-scenarios"
     Then I should see "roundcube-scenarios"

  Scenario: The AI Commands folder lists the command the plugin ships
    Given I am on "/ai-commands?q=roundcube-test"
     Then I should see "roundcube-test"

  Scenario: The AI Prompts folder lists the prompts the plugin ships
    Given I am on "/ai-prompts?q=roundcube-"
     Then I should see "roundcube-build-and-test"
      And I should see "roundcube-mail-round"
