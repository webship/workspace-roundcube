<?php
/**
 * The webmail of the test site: the accounts' users, their mailboxes, address books and settings, and the counts.
 *
 * Run in the project's root (the folder of bin/ and config/), in the web container, once Roundcube's database is made:
 *
 *   php mail-site.php content   the users of the two accounts with the names they show and their default folders, a
 *                               folder of their own, mails in their mailboxes, contacts and a group, a response, and the
 *                               addresses they wrote to (what is there already is kept)
 *   php mail-site.php accounts  the users only (the Webship Workspace's --add-users); sample: everything content
 *                               writes, for accounts the mail server has (its --sample-data)
 *   php mail-site.php reset     put everything back as `content` left it (after a stopped run): the mailboxes written
 *                               again, the folders of a run removed, the address books, identities, responses,
 *                               collected addresses and preferences as they were
 *   php mail-site.php status    say what the accounts hold
 *   php mail-site.php counts    the counts a test run must leave as it found them (CI compares them)
 *
 * Everything goes through Roundcube's own classes: the IMAP storage (rcube_imap) for the mailboxes, rcube_user for the
 * users, their identities, responses and preferences, rcube_contacts and rcube_addresses for the address books, started
 * the way Roundcube's own bin/ scripts start (program/include/clisetup.php). The accounts themselves are the mail
 * server's (configuration): this script never makes one there.
 */

define('INSTALL_PATH', __DIR__ . '/');
require INSTALL_PATH . 'program/include/clisetup.php';

$webship_mode = $argv[1] ?? 'content';

/** The accounts of the suite on the mail server, with the names they show. */
const WEBSHIP_ACCOUNTS = [
    'alice@example.com' => 'Alice Test',
    'bob@example.com' => 'Bob Test',
];
const WEBSHIP_PASSWORD = 'dD.123123ddd';
/** The folder of its own each account has beside the default ones. */
const WEBSHIP_FOLDER = 'Projects';

$rcube = rcube::get_instance();
// The archive plugin's folder type, which the plugin registers itself in a browser's session only.
rcube_storage::$folder_types[] = 'archive';

/** The host Roundcube records a user with: the host part of imap_host. */
function webship_host(): string {
    $parts = explode(':', (string)rcube::get_instance()->config->get('imap_host'));
    return preg_replace('~^[a-z]+://~', '', $parts[0]);
}

/** The IMAP storage, connected as one account. */
function webship_imap(string $login): rcube_imap {
    $storage = webship_connect($login);
    if (!$storage) {
        fwrite(STDERR, "The mail server refused the login of {$login}.\n");
        exit(1);
    }
    return $storage;
}

/** The IMAP storage, connected as one account; null when the mail server refuses the login (no such account). */
function webship_connect(string $login): ?rcube_imap {
    $rcube = rcube::get_instance();
    $storage = $rcube->get_storage();
    if ($storage->is_connected()) {
        $storage->close();
    }
    $parts = explode(':', (string)$rcube->config->get('imap_host'));
    $port = (int)($parts[1] ?? 143);
    return $storage->connect(webship_host(), $login, WEBSHIP_PASSWORD, $port, null) ? $storage : null;
}

/** The user of an account in Roundcube's database, made the way a first login makes it. */
function webship_user(string $login): rcube_user {
    $user = rcube_user::query($login, webship_host());
    if (!$user) {
        $user = rcube_user::create($login, webship_host());
        echo "  user {$login}\n";
    }
    if (!$user) {
        fwrite(STDERR, "The user {$login} could not be made.\n");
        exit(1);
    }
    return $user;
}

/** A mail as the mail server keeps it. */
function webship_mail(string $from, string $to, string $subject, string $date, string $id, string $body, ?array $attachment = null, bool $html = false): string {
    $headers = "From: {$from}\r\nTo: {$to}\r\nSubject: {$subject}\r\nDate: {$date}\r\nMessage-ID: <{$id}@example.com>\r\nMIME-Version: 1.0\r\n";
    if ($attachment) {
        [$name, $content] = $attachment;
        return $headers . "Content-Type: multipart/mixed; boundary=\"webship-part\"\r\n\r\n"
            . "--webship-part\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n{$body}\r\n"
            . "--webship-part\r\nContent-Type: text/plain; charset=UTF-8; name=\"{$name}\"\r\nContent-Disposition: attachment; filename=\"{$name}\"\r\n\r\n{$content}\r\n"
            . "--webship-part--\r\n";
    }
    return $headers . 'Content-Type: text/' . ($html ? 'html' : 'plain') . "; charset=UTF-8\r\n\r\n{$body}\r\n";
}

/**
 * The mailboxes of the test content, by account and folder: [the mail, its flags].
 * Alice reads her mail in the scenarios; Bob is the one she writes to and hears from.
 */
function webship_mailboxes(): array {
    $alice = 'Alice Test <alice@example.com>';
    $bob = 'Bob Test <bob@example.com>';
    $news = 'Webship Newsletter <news@example.com>';
    return [
        'alice@example.com' => [
            'INBOX' => [
                [webship_mail($bob, $alice, 'Webship weekly report', 'Mon, 23 Nov 2026 09:00:00 +0000', 'weekly-report',
                    "Hello Alice,\r\n\r\nThe weekly report is ready: twelve scenarios passed, none failed.\r\n\r\nBob"), []],
                [webship_mail($bob, $alice, 'The test plan, attached', 'Tue, 24 Nov 2026 10:30:00 +0000', 'test-plan',
                    'Here is the test plan for the next release.', ['test-plan.txt', "1. Log in\r\n2. Read the mail\r\n3. Reply"]), []],
                [webship_mail($news, $alice, 'Webship news: November', 'Tue, 24 Nov 2026 08:15:00 +0000', 'news-november',
                    '<html><body><h1>Webship news</h1><p>Automated functional testing, <strong>recipe by recipe</strong>.</p></body></html>', null, true), ['SEEN']],
                [webship_mail($bob, $alice, 'Lunch on Friday', 'Wed, 25 Nov 2026 11:45:00 +0000', 'lunch-friday',
                    "Lunch on Friday at noon? The usual place.\r\n\r\nBob"), ['SEEN', 'FLAGGED']],
            ],
            'Sent' => [
                [webship_mail($alice, $bob, 'Notes from the meeting', 'Fri, 20 Nov 2026 16:00:00 +0000', 'meeting-notes',
                    "Hello Bob,\r\n\r\nThe notes from today's meeting: we test the webmail next.\r\n\r\nAlice"), ['SEEN']],
            ],
            WEBSHIP_FOLDER => [
                [webship_mail($bob, $alice, 'Webship project plan', 'Thu, 19 Nov 2026 14:00:00 +0000', 'project-plan',
                    "The plan: build, test, release.\r\n\r\nBob"), ['SEEN']],
            ],
        ],
        'bob@example.com' => [
            'INBOX' => [
                [webship_mail($alice, $bob, 'Notes from the meeting', 'Fri, 20 Nov 2026 16:00:00 +0000', 'meeting-notes',
                    "Hello Bob,\r\n\r\nThe notes from today's meeting: we test the webmail next.\r\n\r\nAlice"), ['SEEN']],
            ],
        ],
    ];
}

/** The users of the accounts (made the way a first login makes them), their identities' names and their default folders. */
function webship_set_users(): void {
    foreach (WEBSHIP_ACCOUNTS as $login => $name) {
        $user = webship_user($login);
        foreach ($user->list_identities('', false) as $identity) {
            if ($identity['email'] === $login && $identity['name'] !== $name) {
                $user->update_identity($identity['identity_id'], ['name' => $name, 'email' => $login]);
                echo "  {$login}: the identity {$name}\n";
            }
        }
        webship_imap($login)->create_default_folders();
    }
}

/**
 * The mails of the test content, in folders that hold none yet (a folder with mail in it is kept as it is), the folder of
 * its own made when it is not there.
 */
function webship_set_mail(bool $replace = false): void {
    foreach (webship_mailboxes() as $login => $folders) {
        $storage = webship_imap($login);
        foreach ($folders as $folder => $mails) {
            if (!$storage->folder_exists($folder)) {
                $storage->create_folder($folder, true);
                echo "  {$login}: the folder {$folder}\n";
            }
            if ($replace) {
                $storage->delete_message('*', $folder);
            } elseif ($storage->count($folder, 'ALL', true)) {
                continue;
            }
            foreach ($mails as [$mail, $flags]) {
                $storage->save_message($folder, $mail, '', false, $flags);
            }
            echo "  {$login}: " . count($mails) . " mail(s) in {$folder}\n";
        }
    }
}

/** Alice's address book: two contacts and a group of one, her response, and the addresses each account wrote to. */
function webship_set_addressbooks(): void {
    $db = rcube::get_instance()->get_dbh();
    $alice = webship_user('alice@example.com');
    $book = new rcube_contacts($db, $alice->ID);
    $ids = [];
    foreach ([['Bob', 'Test', 'bob@example.com'], ['Carol', 'Test', 'carol@example.com']] as [$first, $last, $email]) {
        $found = $book->search('email', $email, 1, true);
        if ($found->count) {
            $ids[$email] = $found->first()['ID'];
            continue;
        }
        $ids[$email] = $book->insert(['name' => "{$first} {$last}", 'firstname' => $first, 'surname' => $last, 'email:home' => [$email]]);
        echo "  alice@example.com: the contact {$first} {$last}\n";
    }
    $groups = array_column($book->list_groups(), 'ID', 'name');
    if (!isset($groups['Webship team'])) {
        $group = $book->create_group('Webship team');
        $book->add_to_group($group['id'], [$ids['bob@example.com']]);
        echo "  alice@example.com: the group Webship team, with Bob Test\n";
    }
    $names = array_column($alice->list_responses(), 'name');
    if (!in_array('Thanks', $names, true)) {
        $alice->insert_response(['name' => 'Thanks', 'data' => 'Thank you, I will look at it today.', 'is_html' => false]);
        echo "  alice@example.com: the response Thanks\n";
    }
    foreach (['alice@example.com' => ['Bob Test', 'bob@example.com'], 'bob@example.com' => ['Alice Test', 'alice@example.com']] as $login => [$name, $email]) {
        $collected = new rcube_addresses($db, webship_user($login)->ID, rcube_addresses::TYPE_RECIPIENT);
        if ($collected->insert(['name' => $name, 'email' => $email], true)) {
            echo "  {$login}: {$email} among the collected recipients\n";
        }
    }
}

/**
 * Put everything back as `content` left it: the mailboxes written again (the folders of a run removed, the default
 * ones and the folder of its own kept), and in the database the rows of the accounts' address books, groups,
 * identities, responses and collected addresses as they were, with what a run deleted (Roundcube keeps a deleted row,
 * marked) gone for good, and the preferences as they were.
 */
function webship_reset(): void {
    $db = rcube::get_instance()->get_dbh();
    $keep = ['INBOX', 'Drafts', 'Sent', 'Junk', 'Trash', WEBSHIP_FOLDER];
    foreach (array_keys(WEBSHIP_ACCOUNTS) as $login) {
        $storage = webship_imap($login);
        foreach ($storage->list_folders() as $folder) {
            if (!in_array($folder, $keep, true)) {
                // GreenMail refuses to unsubscribe a folder it removed: the folder goes through the connection itself.
                $storage->conn->deleteFolder($folder);
                echo "  {$login}: the folder {$folder} removed\n";
            } else {
                $storage->delete_message('*', $folder);
            }
        }
        $storage->subscribe(array_values(array_filter($keep, fn($f) => $storage->folder_exists($f))));
        $user = webship_user($login);
        $db->query('DELETE FROM ' . $db->table_name('contactgroupmembers', true) . ' WHERE `contactgroup_id` IN (SELECT `contactgroup_id` FROM ' . $db->table_name('contactgroups', true) . ' WHERE `user_id` = ?)', $user->ID);
        foreach (['contactgroups', 'contacts', 'responses', 'collected_addresses'] as $table) {
            $db->query('DELETE FROM ' . $db->table_name($table, true) . ' WHERE `user_id` = ?', $user->ID);
        }
        // The identities a run added go; the account's own one stays (or comes back), with its name.
        $db->query('DELETE FROM ' . $db->table_name('identities', true) . ' WHERE `user_id` = ? AND (`del` = 1 OR `email` <> ?)', $user->ID, $login);
        $db->query('UPDATE ' . $db->table_name('identities', true) . ' SET `name` = ?, `standard` = 1, `organization` = \'\', `reply-to` = \'\', `bcc` = \'\', `signature` = NULL WHERE `user_id` = ?', WEBSHIP_ACCOUNTS[$login], $user->ID);
        if (!webship_n('SELECT COUNT(*) FROM identities WHERE user_id = ? AND del = 0', $user->ID)) {
            $user->insert_identity(['name' => WEBSHIP_ACCOUNTS[$login], 'email' => $login, 'standard' => 1]);
        }
        $db->query('UPDATE ' . $db->table_name('users', true) . ' SET `preferences` = NULL WHERE `user_id` = ?', $user->ID);
    }
    webship_set_mail(true);
    webship_set_addressbooks();
}

function webship_n(string $sql, ...$args): int {
    $db = rcube::get_instance()->get_dbh();
    $row = $db->fetch_array($db->query($sql, ...$args));
    return (int)($row[0] ?? 0);
}

/**
 * The preferences an account set, as a hash, but what the webmail keeps there by itself: the client_hash every login
 * writes (its own value for the session) and the fields the search box remembers for each folder it searched
 * (search_mods). A preference set back to the webmail's default counts as not set: the settings show the same.
 */
function webship_prefs_hash(?rcube_user $user): string {
    $raw = $user ? (string)$user->data['preferences'] : '';
    $prefs = $raw !== '' ? (array)unserialize($raw, ['allowed_classes' => false]) : [];
    unset($prefs['client_hash'], $prefs['search_mods']);
    $defaults = rcube::get_instance()->config->all();
    foreach ($prefs as $key => $value) {
        // The same as the default, or an empty list where there is none (a folder saved writes the folders' threading
        // as an empty list): nothing the settings show differently.
        if ((array_key_exists($key, $defaults) && $defaults[$key] == $value) || ($value === [] && empty($defaults[$key]))) {
            unset($prefs[$key]);
        }
    }
    ksort($prefs);
    return count($prefs) . ' set, ' . md5(serialize($prefs));
}

/** What each account holds, for a person. */
function webship_status(): void {
    foreach (array_keys(WEBSHIP_ACCOUNTS) as $login) {
        $storage = webship_connect($login);
        if (!$storage) {
            echo "{$login}: not an account of the mail server\n";
            continue;
        }
        $folders = [];
        foreach ($storage->list_folders() as $folder) {
            $folders[] = "{$folder} " . $storage->count($folder, 'ALL', true) . ' (' . $storage->count($folder, 'UNSEEN', true) . ' unread)';
        }
        $user = rcube_user::query($login, webship_host());
        $id = $user ? $user->ID : 0;
        echo "{$login}: " . implode(', ', $folders) . "\n";
        echo '  ' . webship_n('SELECT COUNT(*) FROM contacts WHERE user_id = ? AND del = 0', $id) . ' contact(s), '
            . webship_n('SELECT COUNT(*) FROM contactgroups WHERE user_id = ? AND del = 0', $id) . ' group(s), '
            . webship_n('SELECT COUNT(*) FROM identities WHERE user_id = ? AND del = 0', $id) . ' identity(ies), '
            . webship_n('SELECT COUNT(*) FROM responses WHERE user_id = ? AND del = 0', $id) . " response(s)\n";
    }
}

/**
 * What a run must leave as it found it, one count a line, the same on every run of the same site: per account the
 * folders and their subscriptions, and per folder its mails, the unread ones and the flagged ones; the users; per
 * account its contacts, groups and their members, identities, responses (Roundcube keeps a deleted row, marked: only
 * the rows a person sees are counted), the collected addresses by kind, and its preferences (but what the webmail keeps
 * there by itself: webship_prefs_hash). Not counted: the sessions, the caches, the saved searches. CI compares it before
 * and after the suite.
 */
function webship_counts(): void {
    $lines = ['users: ' . webship_n('SELECT COUNT(*) FROM users')];
    foreach (array_keys(WEBSHIP_ACCOUNTS) as $login) {
        $storage = webship_imap($login);
        $folders = $storage->list_folders('', '*', null, null, true);
        sort($folders);
        $subscribed = $storage->list_folders_subscribed('', '*', null, null, true);
        sort($subscribed);
        $parts = [];
        foreach ($folders as $folder) {
            $parts[] = "{$folder} " . $storage->count($folder, 'ALL', true) . '/' . $storage->count($folder, 'UNSEEN', true)
                . '/' . $storage->search_once($folder, 'FLAGGED')->count();
        }
        $lines[] = "{$login} folders (all/unread/flagged): " . implode(', ', $parts);
        $lines[] = "{$login} subscribed: " . implode(', ', $subscribed);
        $user = rcube_user::query($login, webship_host());
        $id = $user ? $user->ID : 0;
        $lines[] = "{$login} address book: "
            . webship_n('SELECT COUNT(*) FROM contacts WHERE user_id = ? AND del = 0', $id) . ' contacts, '
            . webship_n('SELECT COUNT(*) FROM contactgroups WHERE user_id = ? AND del = 0', $id) . ' groups, '
            . webship_n('SELECT COUNT(*) FROM contactgroupmembers m JOIN contactgroups g ON g.contactgroup_id = m.contactgroup_id JOIN contacts c ON c.contact_id = m.contact_id WHERE g.user_id = ? AND g.del = 0 AND c.del = 0', $id) . ' members, '
            . 'collected ' . webship_n('SELECT COUNT(*) FROM collected_addresses WHERE user_id = ? AND type = 1', $id) . ' recipients and '
            . webship_n('SELECT COUNT(*) FROM collected_addresses WHERE user_id = ? AND type = 2', $id) . ' trusted senders';
        $lines[] = "{$login} settings: "
            . webship_n('SELECT COUNT(*) FROM identities WHERE user_id = ? AND del = 0', $id) . ' identities, '
            . webship_n('SELECT COUNT(*) FROM responses WHERE user_id = ? AND del = 0', $id) . ' responses, preferences '
            . webship_prefs_hash($user);
    }
    echo implode("\n", $lines) . "\n";
}

switch ($webship_mode) {
    case 'content':
        webship_set_users();
        webship_set_mail();
        webship_set_addressbooks();
        break;
    case 'accounts':
        webship_set_users();
        break;
    case 'sample':
        webship_set_users();
        webship_set_mail();
        webship_set_addressbooks();
        break;
    case 'reset':
        webship_reset();
        break;
    case 'status':
        webship_status();
        break;
    case 'counts':
        webship_counts();
        break;
    default:
        fwrite(STDERR, "Unknown mode {$webship_mode}: content, accounts, sample, reset, status or counts.\n");
        exit(1);
}
