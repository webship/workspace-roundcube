#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: a Roundcube webmail of this folder.')
parser.add_argument('-r', '--run',
                    default="_none_",
                    help='A command run in the folder of the webmail in the container: one of its own bin/ scripts, or PHP. Example: --run "bin/gc.sh" cleans its caches and old sessions')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='Add the default accounts on the mail server: alice and bob of example.com. An account that is there is kept.')
parser.add_argument('-c', '--cancel-users',
                    action='store_true',
                    default=False,
                    help='Delete the default accounts: from the mail server, and from the webmail with what it keeps of them; --add-users brings them back.')
parser.add_argument('-s', '--sample-data',
                    action='store_true',
                    default=False,
                    help='Add the mails, the folder of their own, the contacts and the group, and the response the test scenarios name (a folder with mail in it is kept as it is), and again after every start of the project.')
parser.add_argument('-t', '--tidy',
                    action='store_true',
                    default=False,
                    help='Put the webmail back as the sample data left it: the mailboxes written again, the folders, contacts, identities and responses of a run gone. From then on the sample data is written again after every start of the project.')
ARGEOF
