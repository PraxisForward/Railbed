# Configuration and Credentials

Application code reads every setting and secret through `Credentials.dig` in `lib/credentials.rb`.

## Read a setting

```ruby
Credentials.dig(:payments, :api_key)
```

`Credentials.dig` returns a `String` or `nil`. It checks two sources in order:

1. An environment variable named after the key path in upper case, joined with underscores. `Credentials.dig(:payments, :api_key)` reads `PAYMENTS_API_KEY`. A blank value counts as unset.
2. The Rails credentials for the current environment.

It returns scalars only. Numbers and unquoted `true` or `false` come back as strings, such as `"true"`. A hash or a list under the key path returns `nil`, so a misindented entry reads as unset instead of leaking a structure into the caller. Parse the string where the setting is used, and write secrets as quoted strings.

## Keep ENV in one file

`Quality/NoDirectEnv` reports every `ENV` reference in `app/`, `lib/`, and `config/initializers/`. `lib/credentials.rb` is the only exclusion. Every setting therefore has one name, one override rule, and one place to stub in specs.

The rest of `config/` still reads `ENV` for process-level settings that Rails needs before the application loads, such as `config/puma.rb`, `config/database.yml`, and `RAILS_LOG_LEVEL` in `config/environments/production.rb`.

`config/application.rb` loads `lib/` with `config.autoload_lib_once`, so initializers can call `Credentials.dig` at boot. Rails cannot autoload reloadable constants during boot. The trade-off is that code under `lib/` does not reload in development. Restart the server after you change it.

## Store per-environment credentials

Each environment can have its own encrypted file, `config/credentials/<environment>.yml.enc`, and its own key, `config/credentials/<environment>.key`. Railbed ships no credentials of its own. To create or edit the file for an environment, run:

```bash
bin/rails credentials:edit --environment development
bin/rails credentials:edit --environment production
```

The first run for an environment generates its key. The production file also gets a fresh `secret_key_base`. Development and test take theirs from `tmp/local_secret.txt`.

```yaml
payments:
  api_key: "<API key>"
```

Git ignores `config/master.key` and `config/credentials/*.key`. Never commit a key. Share keys through a password manager or your deploy platform's secret store. `.worktreeinclude` lists both, so Claude Code copies the keys into each new worktree it creates.

Until `config/credentials/<environment>.yml.enc` exists, Rails reads the shared `config/credentials.yml.enc` that `rails new` created, decrypted with `config/master.key`. After you create the file for an environment, Rails ignores the shared file in that environment. Copy any value you still need from the shared file into the new one.

In production, give the server `config/credentials/production.key`, or set `RAILS_MASTER_KEY` to its contents. `config/master.key` does not decrypt the production file.

Use an environment variable override for a value that differs per server or deploy, such as a hostname, without editing the encrypted file.

## Test code that reads credentials

`spec/support/credentials_helpers.rb` gives every example empty credentials, so a developer's decrypted files never change a result. In a spec:

- `stub_credentials("payments:\n  api_key: test-key\n")` loads values from a throwaway encrypted file.
- `with_env("PAYMENTS_API_KEY" => "override") { ... }` sets environment variables for the block and restores them afterwards.
