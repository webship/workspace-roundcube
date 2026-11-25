#!/usr/bin/env bash

argparse "$@" <<ARGEOF || exit 1
parser.add_argument('PROJECT_NAME',
                    help='The name of the project: its folder, and its name on the container runtime (its host name too).')
parser.add_argument('--runtime',
                    dest='RUNTIME',
                    default="_none_",
                    choices=['ddev'],
                    help='The container runtime to build on: ddev. The webmail needs a mail server of its own beside it, a service the other runtimes of the workspace do not carry yet.')
parser.add_argument('-v', '--version',
                    default="${site_version}",
                    help='The Roundcube release to download: latest (of the 1.x line), or a version number. Example: --version 1.7.7 [default %(default)s]')
parser.add_argument('-i', '--install',
                    action='store_true',
                    default=False,
                    help='Install the webmail: its configuration, its database made by its own bin/initdb.sh, and a mailbox for the workspace account on the mail server.')
parser.add_argument('-a', '--add-users',
                    action='store_true',
                    default=False,
                    help='With --install, add the default accounts on the mail server: alice and bob of example.com, the ones the test scenarios log in as.')
parser.add_argument('-s', '--sample-data',
                    action='store_true',
                    default=False,
                    help='With --install and --add-users, add what the test scenarios name: mails in the accounts mailboxes, a folder of their own, contacts and a group, a response; the mail comes back after every start of the project.')
parser.add_argument('-l', '--launch',
                    action='store_true',
                    default=False,
                    help='Open the webmail in a browser when it is ready.')
parser.add_argument('--php-version',
                    default="8.3",
                    choices=['8.3', '8.2', '8.1'],
                    help='PHP version for the project container: Roundcube 1.7 was proven on 8.3 and 8.1. Example: --php-version 8.1 [default %(default)s]')
ARGEOF
