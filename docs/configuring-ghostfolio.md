<!--
SPDX-FileCopyrightText: 2020 - 2024 MDAD project contributors
SPDX-FileCopyrightText: 2020 - 2024 Slavi Pantaleev
SPDX-FileCopyrightText: 2020 Aaron Raimist
SPDX-FileCopyrightText: 2020 Chris van Dijk
SPDX-FileCopyrightText: 2020 Dominik Zajac
SPDX-FileCopyrightText: 2020 Mickaël Cornière
SPDX-FileCopyrightText: 2022 François Darveau
SPDX-FileCopyrightText: 2022 Julian Foad
SPDX-FileCopyrightText: 2022 Warren Bailey
SPDX-FileCopyrightText: 2023 Antonis Christofides
SPDX-FileCopyrightText: 2023 Felix Stupp
SPDX-FileCopyrightText: 2023 Pierre 'McFly' Marty
SPDX-FileCopyrightText: 2024 - 2025 Suguru Hirahara

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Setting up Ghostfolio

This is an [Ansible](https://www.ansible.com/) role which installs [Ghostfolio](https://ghostfol.io/) to run as a [Docker](https://www.docker.com/) container wrapped in a systemd service.

Ghostfolio is a free software for wealth management to keep track of assets such as stocks, bonds, ETFs, etc.

See the project's [documentation](https://ghostfol.io/en/features) to learn what Ghostfolio does and why it might be useful to you.

## Prerequisites

To run a Ghostfolio instance it is necessary to prepare a [Postgres](https://www.postgresql.org/) database server and [Redis](https://redis.io/) server for managing cache data.

If you are looking for Ansible roles for them, you can check out [ansible-role-postgres](https://github.com/mother-of-all-self-hosting/ansible-role-postgres) and [ansible-role-redis](https://github.com/mother-of-all-self-hosting/ansible-role-redis), both of which are maintained by the [Mother-of-All-Self-Hosting (MASH)](https://github.com/mother-of-all-self-hosting) team. The roles for [KeyDB](https://keydb.dev/) ([ansible-role-keydb](https://github.com/mother-of-all-self-hosting/ansible-role-keydb)) and [Valkey](https://valkey.io/) ([ansible-role-valkey](https://github.com/mother-of-all-self-hosting/ansible-role-valkey)) are available as well.

See [this section](https://github.com/ghostfolio/ghostfolio/blob/main/README.md#technology-stack) on the official documentation to check server requirements.

## Adjusting the playbook configuration

To enable Ghostfolio with this role, add the following configuration to your `vars.yml` file.

**Note**: the path should be something like `inventory/host_vars/mash.example.com/vars.yml` if you use the [MASH Ansible playbook](https://github.com/mother-of-all-self-hosting/mash-playbook).

```yaml
########################################################################
#                                                                      #
# ghostfolio                                                           #
#                                                                      #
########################################################################

ghostfolio_enabled: true

########################################################################
#                                                                      #
# /ghostfolio                                                          #
#                                                                      #
########################################################################
```

### Set the hostname

To enable the Ghostfolio you need to set the hostname as well. To do so, add the following configuration to your `vars.yml` file. Make sure to replace `example.com` with your own value.

```yaml
ghostfolio_hostname: "example.com"
```

After adjusting the hostname, make sure to adjust your DNS records to point the domain to your server.

**Note**: hosting Ghostfolio under a subpath (by configuring the `ghostfolio_path_prefix` variable) does not seem to be possible due to Ghostfolio's technical limitations.

### Set access token salt and JWT secret key

You also need to set random strings to salt for access token and JWT secret key. They can be generated with `pwgen -s 64 1` or in another way.

```yaml
ghostfolio_environment_variable_access_token_salt: RANDOM_ACCESS_TOKEN_SALT_HERE
ghostfolio_environment_variable_jwt_secret_key: RANDOM_SECRET_KEY_HERE
```

### Set variables for connecting to a Postgres database server

To use a Postgres server, add the following configuration to your `vars.yml` file.

```yaml
ghostfolio_environment_variable_postgres_user: YOUR_POSTGRES_SERVER_USERNAME_HERE
ghostfolio_environment_variable_postgres_password: YOUR_POSTGRES_SERVER_PASSWORD_HERE
ghostfolio_database_hostname: YOUR_POSTGRES_SERVER_HOSTNAME_HERE
ghostfolio_database_port: 5432
```

Make sure to replace `YOUR_POSTGRES_SERVER_USERNAME_HERE`, `YOUR_POSTGRES_SERVER_PASSWORD_HERE`, and `YOUR_POSTGRES_SERVER_HOSTNAME_HERE` with your own values.

### Set variables for connecting to a Redis cache server

As described above, it is also necessary to set up a [Redis](https://redis.io/) server for managing a metadata database of a Ghostfolio instance. You can use either KeyDB or Valkey alternatively.

Having configured it, you need to add and adjust the following configuration to your `vars.yml` file, so that the Ghostfolio instance will connect to the server:

```yaml
ghostfolio_environment_variable_redis_host: YOUR_REDIS_SERVER_HOSTNAME_HERE
ghostfolio_environment_variable_redis_password: YOUR_REDIS_SERVER_PASSWORD_HERE
ghostfolio_environment_variable_redis_port: 6379
```

Make sure to replace `YOUR_REDIS_SERVER_HOSTNAME_HERE` and `YOUR_REDIS_SERVER_PASSWORD_HERE` with your own values.

### Set Coingecko API keys (optional)

If you have either or both of *CoinGecko* Demo API key and *CoinGecko* Pro API key, you can specify them by adding the following configuration to your `vars.yml` file:

```yaml
ghostfolio_environment_variable_api_key_coingecko_demo: YOUR_DEMO_KEY_HERE
ghostfolio_environment_variable_api_key_coingecko_pro: YOUR_PRO_KEY_HERE
```

### Extending the configuration

There are some additional things you may wish to configure about the component.

Take a look at:

- [`defaults/main.yml`](../defaults/main.yml) for some variables that you can customize via your `vars.yml` file. You can override settings (even those that don't have dedicated playbook variables) using the `ghostfolio_environment_variables_additional_variables` variable

See its [environment variables](https://ghostfol.io/docs/self-hosting/environment-variables) for a complete list of Ghostfolio's config options that you could put in `ghostfolio_environment_variables_additional_variables`.

## Installing

After configuring the playbook, run the installation command of your playbook as below:

```sh
ansible-playbook -i inventory/hosts setup.yml --tags=setup-all,start
```

If you use the MASH playbook, the shortcut commands with the [`just` program](https://github.com/mother-of-all-self-hosting/mash-playbook/blob/main/docs/just.md) are also available: `just install-all` or `just setup-all`

## Usage

After running the command for installation, Ghostfolio becomes available at the specified hostname like `https://example.com`.

To use it, go to `https://example.com/en/register` on a web browser and create a first user by clicking the "Create Account" button. **Note that the first user will be an administrator of the instance.**

After creating the user and logging in to the instance, you can add bank and brokerage accounts by following the instruction on the UI.

See "Resources" (available at `https://example.com/en/resources`) for details about how to use Ghostfolio.

### Disable signup (optional)

As **registration is open to anyone by default**, you also would probably want to disable the signup form on "Admin Control" page. You can open the page from the header of the UI; it is also available at `https://example.com/en/admin`.

## Troubleshooting

### Check the service's logs

You can find the logs in [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) by logging in to the server with SSH and running `journalctl -fu ghostfolio` (or how you/your playbook named the service, e.g. `mash-ghostfolio`).
