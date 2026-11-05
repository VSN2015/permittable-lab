# permittable-lab Plan 1: Foundation and the "Tạo đơn" vertical slice

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three thin Rails apps (7.2, 8.0, 8.1) in Docker, all running one shared RSpec suite against the `permittable` gem (local or RubyGems), with the coverage matrix seeded, and one complete flow (Tạo đơn: form, contract, request specs, system specs, gem matchers, Inspector) working end to end.

**Architecture:** `shared/` holds all business code and specs. Docker Compose bind-mounts `shared/` to `/app/shared` inside each app, so everything is physically inside `Rails.root` (no symlinks, no engine). A plain-Ruby `shared/lib/lab/boot.rb`, called by one line in each app's `config/application.rb`, adds the shared directories to that app's autoload, view, locale, migration, route, initializer and seed paths. The gem comes from a `Gemfile` fragment chosen by `PERMITTABLE_SOURCE`. Plain-Ruby tooling (`Lab::GemSource`, `Lab::Since`, `Lab::ReportBuilder`, `Lab::MatrixReport`, `Lab::CoverageMatrix`) lives in `shared/lib/lab/`, is stdlib-only, and is unit-tested.

**Tech Stack:** Ruby 3.3 (Docker image `ruby:3.3-slim-bookworm`), Rails 7.2 / 8.0 / 8.1, PostgreSQL 16 (Compose service `db`, `pg` gem), rspec-rails, Capybara + Cuprite + Chromium (headless, in the image), Docker Compose.

**Spec:** `docs/superpowers/specs/2026-11-05-permittable-lab-design.md` (source of truth). Gem under test: `~/Projects/individual-projects/permittable` (0.13.1 at planning time; its README is the source of truth for expected results; never modify the gem).

## Global Constraints

- Rails versions: **7.2, 8.0, 8.1**. Each is its own app made by `rails new` of that version: `apps/rails-7_2`, `apps/rails-8_0`, `apps/rails-8_1`. Each keeps what `rails new` generates (`config.load_defaults` and the default files).
- Ports: **7.2 -> 3072, 8.0 -> 3080, 8.1 -> 3081**. `docker compose up` opens all three.
- Business code, specs, migrations, routes, locales are written once in `shared/` and loaded **as the app's own code**: Zeitwerk autoload/eager_load, view paths, locale, migration, route. `shared/` must NOT be packaged as an engine.
- Code in `shared/` must sit **inside `Rails.root`** at runtime (bind mount; symlink is not used). Otherwise audit/generate/OpenAPI would treat it as "outside the app root".
- Gem source: `PERMITTABLE_SOURCE=local` (default) or `rubygems`; `PERMITTABLE_VERSION` pins a RubyGems version. Local gem host path comes from `PERMITTABLE_PATH`, default `~/Projects/individual-projects/permittable`, mounted into the container.
- The lab prints the gem source and version at the **top of test output** and in the **navbar**. Changing the source must not dirty git (lockfile handling).
- Ruby in the image must satisfy the gem's `>= 3.2` and all three Rails versions.
- RSpec lives in `shared/spec/`; all three apps run the same suite. `bin/test [7.2|8.0|8.1]` (default **8.1**) runs in Docker. `bin/matrix` runs all three, prints a table (Rails version x gem source/version x green/red/not-applicable) and exits non-zero if any version is red or failed to run.
- `since:` tags: a spec tagged `since: "X"` is not run only when the gem is pinned from RubyGems to a version older than X, and then the report must say "N cases not applicable to version V" with a list. The tag is never used to skip a red case. With the local gem every spec runs. An untagged spec applies to every version.
- **README is the truth.** If the gem differs from the README, the spec stays red. No `pending`, `skip`, "known bug" list, or any mechanism that keeps a spec green while the gem is wrong.
- A spec must really go through what it claims: system specs fill and submit the real rendered form with the headless browser, never a hand-built payload.
- A Rails version must never be silently skipped in the matrix.
- When the README is ambiguous, do not write an expected result: record a matrix row as "chờ tác giả" with the question.
- Inspector is enabled in development and test only, never in production, and must not change the behaviour of the permittable code it observes.
- Database: **PostgreSQL only**, for all three apps (one Compose service `db`, health-checked; each app has its own databases). SQLite is not used anywhere.
- Matrix `status` values: a spec path, `chưa phủ`, `chờ tác giả`, or `ngoài phạm vi` (README claims that spec section 2 puts out of scope; the row carries a `reason`).
- Out of scope: CI, Rails below 7.2, API-only app, login/authorization, styling, production deploy.

## Review Focus

Inputs the spec implies but no spec example names, most likely first. Each has a test in the task that owns the code.

1. **Bad `?locale=`** (`xx`, empty, `locale[]=vi`): fall back to `vi`, never a 500 from `I18n::InvalidLocale`. Test in Task 8.
2. **Missing or malformed `order` root** (empty POST, `order=bob`): a 400 and the form re-rendered, never a 500. Test in Task 8.
3. **Mass assignment** (`order[status]`, `order[code]`, `order[customer][admin]` sent by a client): 422 `unknown`, no rows created. Test in Task 8.
4. **Impossible date from `date_select`** (30 February) and a blank part left on its prompt: 422 `invalid_type` / `missing` with the form re-rendered, never a 500. Tests in Tasks 8 and 11.
5. **Hostile input shown by the Inspector** (`<script>` in a param, a 10,000-character value, an invalid UTF-8 byte): escaped, truncated, and the request's own status passes through unchanged. Test in Task 10.

## Planner decisions

These fill gaps the spec left to the builder (spec section 9) or did not address. Questions that need the author are listed at the end of the hand-off message, not decided here.

- Ruby 3.3. **PostgreSQL is the only database** (planner/main-session decision, replacing an earlier SQLite choice): Compose service `db` (`postgres:16`, named volume `pgdata`, `healthcheck: pg_isready -U lab`), app services `depends_on: db: condition: service_healthy`, apps generated with `rails new --database=postgresql` (the `pg` gem), and `config/database.yml` reads `DB_HOST` (default `db`), `DB_USER`/`DB_PASSWORD` (default `lab`). Databases are named from the app directory (`rails_8_1_development`, `rails_8_1_test`, ...), so the three apps share one server without clashing. This makes the PostgreSQL array-column rows testable in Plan 6.
- Wiring is a Compose bind mount `./shared:/app/shared` plus the gem mount `PERMITTABLE_PATH:/permittable:ro`. A guard spec proves the shared code is in `Rails.root` and not reached through a symlink.
- `shared` base controller is `BaseController` (not `ApplicationController`, which `rails new` already generates and which Zeitwerk would shadow). The generated `ApplicationController` stays untouched and unused.
- Layout is `shared/app/views/layouts/lab.html.erb` with inline CSS (no asset pipeline differences between 7.2/8.x).
- Gems are installed into one named Docker volume per Rails version (`/bundle`). `Gemfile.lock`, `db/schema.rb`, `.lab-source` are git-ignored; a marker file makes the entrypoint delete the lockfile when the gem source/version changes.
- `PERMITTABLE_VERSION` with `PERMITTABLE_SOURCE=local`, an unknown source value, or a non-version string is an `ArgumentError` at Gemfile time (a mislabelled run would break the "print the source" promise). An empty `PERMITTABLE_VERSION` (what Compose passes when unset) means "not set".
- `since:` is compared with `Gem::Version` against the loaded `Permittable::VERSION` when the source is `rubygems`; with `local` nothing is ever excluded.
- **Author's decision:** pinning a RubyGems version too old for the shared DSL (for example one without `format: :email`, 0.9.0) fails when the controller loads, and that version is reported red or "failed to run"; no feature guards are added to shared code.
- **Author's decision:** the Inspector shows raw params verbatim, `sensitive:` values included. It is development/test only. (The log line in the panel is still the filtered Rails log.)
- **Author's expected results for two README gaps:** a `nullable:` field with `normalize: :squish` that receives `"   "` gives `nil`; a scalar array that receives only `[""]` gives `[]`. Both are covered in Plan 1 (Tasks 8 and 9).
- **Main-session decision:** the matrix gains a fourth status `ngoài phạm vi` for the out-of-scope README claims.
- Open question for the author (not answered yet): the `commit`/`button`/CSRF exemptions apply only to a rootless contract, while Tạo đơn is `root:`. Until answered, those rows are assigned to Plan 5 (a rootless HTML form).
- Matrix file is YAML at `docs/coverage-matrix.yml`. Spec files tie to rows with `covers: %w[row-id ...]` metadata and a `# README: <section>` comment.
- `Tạo đơn` uses `enforce: true` (exercises the `before_action` path and the README's `prepend_around_action` locale rule); `Sửa đơn` in Plan 2 uses the lazy path.
- Status codes are passed as integers (`render :new, status: status`), not symbols, because `:unprocessable_entity` / `:unprocessable_content` differ across Rack versions.
- The error re-render does not repopulate fields (YAGNI; the request is rejected, the form shows violations). `TrackingEvent` is created in Plan 3 where it is first needed.

## File Structure

```
.gitignore                       root ignore rules (apps/*/ generated files)
compose.yml                      3 services, volumes, env, ports
docker/Dockerfile                ruby 3.3 + build deps + chromium
bin/test  bin/matrix  bin/new-app  bin/coverage-report      host scripts (stdlib Ruby 2.7+ or bash)
docs/coverage-matrix.yml         the feature matrix
README.md                        how to use the lab
apps/rails-{7_2,8_0,8_1}/        generated by rails new, then patched by shared/bin/patch_app.rb
shared/bin/{entrypoint.sh,patch_app.rb}
shared/gemfile.rb                gem source + test gems, eval'd by each app Gemfile
shared/lib/lab/{gem_source,boot,since,report_builder,report_formatter,hygiene,matrix_report,coverage_matrix}.rb
shared/app/{controllers,models,views,helpers,contracts,field_groups,inspector}/
shared/config/{routes.rb,locales/{vi,en}.yml,initializers/}
shared/db/{migrate/,seeds.rb}
shared/spec/{spec_helper.rb,support/,lab/,models/,requests/,controllers/,system/}
```

---

### Task 1: Docker image, Compose, and the Rails 8.1 skeleton

**Files:**
- Create: `.gitignore` (append to existing), `docker/Dockerfile`, `compose.yml`, `shared/bin/entrypoint.sh`, `bin/new-app`
- Create (generated): `apps/rails-8_1/**`

**Interfaces:**
- Produces: image `permittable-lab/ruby:3.3`; Compose service `rails-8_1` (port 3081, working dir `/app`, `BUNDLE_PATH=/bundle`, `BROWSER_PATH=/usr/bin/chromium`); `bin/new-app <7.2|8.0|8.1>`; `shared/bin/entrypoint.sh` (runs `bundle check || bundle install`, removes `tmp/pids/server.pid`, then `exec "$@"`).
- Consumes: nothing.

- [ ] **Step 1: Write the acceptance checks (they fail first)**

Run: `docker compose build rails-8_1`
Expected: FAIL, `no configuration file provided`.

- [ ] **Step 2: Create `docker/Dockerfile`**

Base `ruby:3.3-slim-bookworm`; apt: `build-essential git pkg-config libyaml-dev libpq-dev curl chromium fonts-liberation`; `ENV BUNDLE_PATH=/bundle BROWSER_PATH=/usr/bin/chromium`; `WORKDIR /app`; `ENTRYPOINT ["/app/shared/bin/entrypoint.sh"]`. No app code is baked in.

- [ ] **Step 3: Create `compose.yml` with `db` and `rails-8_1`**

Use a YAML anchor (`x-lab-app`) holding image/build (`context: docker`), `working_dir: /app`, env (`PERMITTABLE_SOURCE: ${PERMITTABLE_SOURCE:-local}`, `PERMITTABLE_VERSION: ${PERMITTABLE_VERSION:-}`), and volumes. Service volumes: `./apps/rails-8_1:/app`, `./shared:/app/shared`, named `bundle-8_1:/bundle`, and the gem as long syntax `type: bind, source: ${PERMITTABLE_PATH:-${HOME}/Projects/individual-projects/permittable}, target: /permittable, read_only: true, bind: {create_host_path: false}`. Env also `DB_HOST: db`, `DB_USER: lab`, `DB_PASSWORD: lab`; `depends_on: db: condition: service_healthy`. Service `db`: `image: postgres:16`, `POSTGRES_USER`/`POSTGRES_PASSWORD` `lab`, volume `pgdata:/var/lib/postgresql/data`, healthcheck `pg_isready -U lab -d postgres` (interval 2s, retries 30), no published port. Default app command: `sh -c "bin/rails db:create db:migrate db:seed && bin/rails server -b 0.0.0.0 -p 3081"`. Ports `3081:3081`.

- [ ] **Step 4: Write `shared/bin/entrypoint.sh` and `bin/new-app`**

`bin/new-app VERSION` (bash): validates VERSION against `7.2|8.0|8.1`; refuses to overwrite an existing `apps/rails-X_Y`; in a one-off container of the image (`--entrypoint ""`, because `/app` does not exist yet; same `bundle-X_Y` volume as the service) runs `gem install rails -v "~> VERSION.0" --no-document` then `rails new rails-X_Y` with `--skip-git --skip-test --skip-docker --skip-kamal --skip-thruster` (check `rails new --help` and drop flags that version does not know; write the exact command used into `apps/README.md`). Add `--database=postgresql`; JS stays at the default (importmap). After generation the script edits `config/database.yml`'s `default:` section to add `host: <%= ENV.fetch("DB_HOST", "db") %>`, `username: <%= ENV.fetch("DB_USER", "lab") %>`, `password: <%= ENV.fetch("DB_PASSWORD", "lab") %>` (the only edit to a generated default file; record it in `apps/README.md`).

- [ ] **Step 5: Extend root `.gitignore`** and `chmod +x bin/new-app shared/bin/entrypoint.sh`

Add: `apps/*/log/*`, `apps/*/tmp/*`, `apps/*/storage/*` (each with a `!.../.keep` line), `apps/*/.bundle/`, `apps/*/Gemfile.lock`, `apps/*/.lab-source`, `apps/*/shared/`, `apps/*/db/schema.rb`, `apps/*/node_modules/`, `tmp/`.

- [ ] **Step 6: Generate and verify the app**

Run: `docker compose build rails-8_1 && bin/new-app 8.1`
Then: `docker compose run --rm rails-8_1 bin/rails -v` -> `Rails 8.1.`; `docker compose run --rm rails-8_1 ruby -v` -> starts with `ruby 3.3.`; `docker compose run --rm rails-8_1 chromium --version` -> prints a Chromium version; `docker compose run --rm rails-8_1 bin/rails db:create runner 'puts ActiveRecord::Base.connection.adapter_name'` -> `PostgreSQL` (Compose waits for `db` to be healthy first).

- [ ] **Step 7: Commit**

```bash
git add .gitignore docker compose.yml bin/new-app shared/bin/entrypoint.sh apps
git commit -m "feat: docker image, compose service and generated rails 8.1 app"
```

---

### Task 2: Gem source selection, lockfile handling, `bin/test`

**Files:**
- Create: `shared/lib/lab/gem_source.rb`, `shared/gemfile.rb`, `shared/spec/spec_helper.rb`, `shared/spec/lab/gem_source_spec.rb`, `shared/bin/patch_app.rb`, `bin/test`
- Modify: `shared/bin/entrypoint.sh`, `apps/rails-8_1/Gemfile` (via the patcher)

**Interfaces:**
- Produces:
  - `Lab::GemSource.from_env(env = ENV) -> Lab::GemSource`; raises `ArgumentError` (see tests).
  - `Lab::GemSource.current -> Lab::GemSource` (memoized from `ENV`).
  - `#source -> :local | :rubygems`, `#requested_version -> String | nil`, `#gem_args -> Array` to splat into `gem(...)`, `#label(gem_version) -> String`, `#lock_key -> String`.
  - `shared/bin/patch_app.rb APP_DIR` (idempotent, plain Ruby): appends `eval_gemfile File.expand_path("shared/gemfile.rb", __dir__)` to the app `Gemfile`; writes `.rspec` (`--default-path shared/spec`, `--require spec_helper`, `--format progress`; Task 4 adds the report formatter line and re-runs the patcher).
  - `bin/test [VERSION] [rspec args...]`: VERSION in `7.2|8.0|8.1`, default `8.1`; maps to service `rails-X_Y`; first deletes `apps/rails-X_Y/tmp/lab-report.json`; runs `docker compose run --rm -T rails-X_Y bundle exec rspec <args>`; exits with rspec's status; exit 2 with usage on a bad version or a missing `apps/rails-X_Y`.
- Consumes: Task 1 service and image.

- [ ] **Step 1: Write the failing unit spec `shared/spec/lab/gem_source_spec.rb`** (`# README: Compatibility`; no Rails needed)

```ruby
RSpec.describe Lab::GemSource do
  it "defaults to local" do
    s = described_class.from_env({})
    expect([s.source, s.requested_version, s.gem_args]).to eq [:local, nil, ["permittable", { path: "/permittable" }]]
  end
  it "treats an empty PERMITTABLE_VERSION as unset" do   # Compose passes "" when unset
    expect(described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "").gem_args).to eq ["permittable"]
  end
  it "pins an exact RubyGems version" do
    s = described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => "0.12.0")
    expect(s.gem_args).to eq ["permittable", "= 0.12.0"]
    expect(s.label("0.12.0")).to eq "permittable 0.12.0 (rubygems, pinned)"
    expect(s.lock_key).to eq "rubygems@0.12.0"
  end
  it "labels the local and unpinned cases" do
    expect(described_class.from_env({}).label("0.13.1")).to eq "permittable 0.13.1 (local)"
    expect(described_class.from_env("PERMITTABLE_SOURCE" => "rubygems").label("0.13.1")).to eq "permittable 0.13.1 (rubygems, latest)"
  end
  it "rejects a typo in the source" do
    expect { described_class.from_env("PERMITTABLE_SOURCE" => "rubygem") }.to raise_error(ArgumentError, /local, rubygems/)
  end
  it "rejects a version with the local source" do
    expect { described_class.from_env("PERMITTABLE_VERSION" => "0.12.0") }.to raise_error(ArgumentError, /only applies/)
  end
  it "rejects a non-version and a range" do
    %w[latest ~>0.12 >=0.1].each do |v|
      expect { described_class.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => v) }.to raise_error(ArgumentError)
    end
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `docker compose run --rm rails-8_1 ruby -I/app/shared/lib -e 'require "lab/gem_source"'`
Expected: FAIL, `cannot load such file -- lab/gem_source`. (`bin/test` does not exist yet; the spec runs under it from Step 5.)

- [ ] **Step 3: Implement `bin/test`, `patch_app.rb`, `Lab::GemSource`, `shared/gemfile.rb`, and the minimal `shared/spec/spec_helper.rb`**

The spec_helper at this point only puts `shared/lib` on `$LOAD_PATH` and requires `lab/gem_source`. `chmod +x bin/test`.

`shared/gemfile.rb`: `gem(*Lab::GemSource.from_env.gem_args)`; groups: `rspec-rails`, `capybara`, `cuprite` (development+test). `Lab::GemSource` is plain Ruby (no ActiveSupport), usable at Gemfile time. Edge to honour: `Gem::Version.correct?` decides validity; only an exact version is accepted.

- [ ] **Step 4: Make the entrypoint source-aware**

In `shared/bin/entrypoint.sh`: compute `lock_key` (call `ruby -I/app/shared/lib -rlab/gem_source -e 'puts Lab::GemSource.from_env.lock_key'`); if `/app/.lab-source` differs, `rm -f Gemfile.lock`; run `bundle install`; write the new key to `.lab-source`.

- [ ] **Step 5: Patch the app and run the spec**

Run: `ruby shared/bin/patch_app.rb apps/rails-8_1 && bin/test 8.1 shared/spec/lab/gem_source_spec.rb`
Expected: `7 examples, 0 failures` (the source/version banner at the top of the output arrives in Task 4).

- [ ] **Step 6: Verify source switching keeps git clean and reaches the right gem**

Run, in order:
`git status --porcelain > $TMPDIR/before.txt`
`bin/test 8.1 shared/spec/lab/gem_source_spec.rb`
`PERMITTABLE_SOURCE=rubygems PERMITTABLE_VERSION=0.13.1 bin/test 8.1 shared/spec/lab/gem_source_spec.rb`
`bin/test 8.1 shared/spec/lab/gem_source_spec.rb`
`git status --porcelain | diff - $TMPDIR/before.txt`
Expected: all three runs end `0 failures` (the second needs network for the first install); the `diff` prints nothing (the switch dirtied no tracked file). Also `docker compose run --rm rails-8_1 bundle exec ruby -e 'require "permittable/version"; puts Permittable::VERSION; puts $LOADED_FEATURES.grep(/permittable\/version/)'` prints a path under `/permittable/` for local and under `/bundle/` for rubygems.

- [ ] **Step 7: Commit**

```bash
git add bin/test shared apps/rails-8_1/Gemfile apps/rails-8_1/.rspec
git commit -m "feat: gem source selection (local or rubygems), lockfile marker, bin/test"
```

---

### Task 3: Wire `shared/` into the app, layout, navbar label

**Files:**
- Create: `shared/lib/lab/boot.rb`, `shared/app/controllers/base_controller.rb`, `shared/app/controllers/home_controller.rb`, `shared/app/views/layouts/lab.html.erb`, `shared/app/views/home/show.html.erb`, `shared/app/helpers/lab_helper.rb`, `shared/config/routes.rb`, `shared/config/locales/{vi,en}.yml`, `shared/spec/lab/wiring_spec.rb`, `shared/spec/requests/home_spec.rb`
- Modify: `shared/spec/spec_helper.rb` (boots the Rails app), `shared/bin/patch_app.rb` (adds the hook lines)

**Interfaces:**
- Produces:
  - `Lab::Boot.configure(config, root:)` (plain Ruby): adds, relative to `root/shared`: every dir under `app/` to autoload and eager_load paths; `app/views`; `app/helpers`; `config/locales`; `config/initializers`; `config/routes.rb`; `db/migrate`; `db/seeds.rb` (replacing the app's); sets `config.i18n.available_locales = %i[vi en]`, `config.i18n.default_locale = :vi`, `config.active_record.dump_schema_after_migration = false`.
  - `patch_app.rb` inserts `require_relative "../shared/lib/lab/boot"` after `Bundler.require(...)` and `Lab::Boot.configure(config, root: Pathname.new(File.expand_path("..", __dir__)))` right after the `config.load_defaults` line in `config/application.rb`.
  - `BaseController < ActionController::Base`: `include Permittable`, `layout "lab"`. Later tasks add the locale switch and Inspector hooks.
  - Helper `lab_gem_label -> String` (`"#{Lab::GemSource.current.label(Permittable::VERSION)}, Rails #{Rails.version}"`); layout renders it inside `#lab-gem-label`.
  - Routes: `root "home#show"`.
- Consumes: `Lab::GemSource` (Task 2).

- [ ] **Step 1: Write the failing specs**

`wiring_spec.rb` (`# README: Compatibility`, `covers: %w[]`):
```ruby
RSpec.describe "shared code is loaded as the app's own code" do
  %w[BaseController HomeController].each do |name|
    it "#{name} is defined by a real path inside Rails.root, not via a symlink" do
      path = Object.const_source_location(name).first
      expect(path).to start_with(Rails.root.join("shared").to_s + "/")
      expect(File.realpath(path)).to eq path
    end
  end
  it "registers shared dirs with the app" do
    cfg = Rails.application.config
    expect(cfg.paths["db/migrate"].expanded).to include(Rails.root.join("shared/db/migrate").to_s)
    expect(I18n.load_path.map(&:to_s)).to include(Rails.root.join("shared/config/locales/vi.yml").to_s)
    expect(ApplicationController.view_paths.map(&:to_s)).to include(Rails.root.join("shared/app/views").to_s)
  end
  it "eager loads without error" do
    expect { Rails.application.eager_load! }.not_to raise_error
  end
end
```
`home_spec.rb`: `GET /` -> status 200; `css("#lab-gem-label").text` equals `"#{Lab::GemSource.current.label(Permittable::VERSION)}, Rails #{Rails.version}"`; the page contains links to `/orders` and `/orders/new` with locale param.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/wiring_spec.rb shared/spec/requests/home_spec.rb`
Expected: FAIL (`uninitialized constant BaseController` / routing error).

- [ ] **Step 3: Implement Boot, controllers, layout, routes, locales, patcher; re-run the patcher**

`vi.yml` / `en.yml` start with `lab.nav.*` keys (home, orders, new_order, locale names). Locale files must exist so `config/locales` is a real path. The migrate path may be empty until Task 7 (keep a `.keep`).

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/lab shared/spec/requests/home_spec.rb && docker compose run --rm rails-8_1 bin/rails zeitwerk:check`
Expected: `0 failures`; Zeitwerk prints `All is good!`.

- [ ] **Step 5: Commit**

```bash
git add shared apps/rails-8_1/config/application.rb
git commit -m "feat: load shared/ as app code inside Rails.root, layout with gem label"
```

---

### Task 4: `since:` tagging, JSON report, hygiene guard

**Files:**
- Create: `shared/lib/lab/since.rb`, `shared/lib/lab/report_builder.rb`, `shared/lib/lab/report_formatter.rb`, `shared/lib/lab/hygiene.rb`, `shared/spec/lab/since_spec.rb`, `shared/spec/lab/report_builder_spec.rb`, `shared/spec/lab/hygiene_spec.rb`
- Modify: `shared/spec/spec_helper.rb`, `shared/bin/patch_app.rb` (add `--format Lab::ReportFormatter` to the generated `.rspec`; re-run it on `apps/rails-8_1`)

**Interfaces:**
- Produces:
  - `Lab::Since.applies?(since, source: Lab::GemSource.current, gem_version: Permittable::VERSION) -> Boolean`. `nil` since -> true; `:local` source -> true for any since; `:rubygems` -> `Gem::Version.new(gem_version) >= Gem::Version.new(since)`; a malformed since raises `ArgumentError`.
  - spec_helper config: `config.filter_run_excluding since: ->(v) { !Lab::Since.applies?(v) }`; prints `Lab::GemSource.current.label(Permittable::VERSION)` plus Rails/Ruby versions as the **first lines** of output (`puts` at load time).
  - `Lab::ReportBuilder.build(rails_version:, ruby_version:, gem_source:, gem_version:, requested_version:, examples:, not_applicable:, errors_outside_examples:) -> Hash`. Example entries are `{description:, location:, status: :passed|:failed|:pending, since:}`; result keys: `rails_version, ruby_version, gem: {source, requested_version, version}, examples, green, failures, pending, errors_outside_examples, failed: [{location, description}], not_applicable: [{description, location, since}]`. `green = examples - failures - pending`.
  - `Lab::ReportFormatter` (RSpec formatter): at `dump_summary`/`close`, writes `Rails.root/tmp/lab-report.json` with that Hash; `not_applicable` is computed from `RSpec.world.all_examples` whose `metadata[:since]` fails `Lab::Since.applies?`; also prints `"N cases not applicable to permittable V: ..."` with one line per case when N > 0.
  - `Lab::Hygiene.violations(source, path) -> Array<String>`: flags `skip`/`pending`/`xit`/`xdescribe`/`xcontext`/`xspecify`/`fit`/`fdescribe`/`fcontext`/`focus: true`/`:skip`/`:pending`/`RSpec::Core::Pending`/`filter_run_excluding` (outside `shared/lib/lab` and `spec_helper.rb`)/`known_bug`; text after a `#` on a line is ignored, and keywords match as whole words in code positions only; in `shared/spec/system/**` also flags `driver.post`, `driver.submit`, `fetch(`, `XMLHttpRequest`, `requestSubmit`, `.submit(`.
- Consumes: `Lab::GemSource` (Task 2).

- [ ] **Step 1: Write failing specs**

`since_spec.rb` (assert exactly):
```ruby
local = Lab::GemSource.from_env({})
pinned = ->(v) { Lab::GemSource.from_env("PERMITTABLE_SOURCE" => "rubygems", "PERMITTABLE_VERSION" => v) }
it("never excludes with the local gem") { expect(Lab::Since.applies?("9.9.9", source: local, gem_version: "0.1.0")).to be true }
it("excludes when the pinned version is older") { expect(Lab::Since.applies?("0.13.0", source: pinned.("0.12.0"), gem_version: "0.12.0")).to be false }
it("includes at exactly the tagged version") { expect(Lab::Since.applies?("0.12.0", source: pinned.("0.12.0"), gem_version: "0.12.0")).to be true }
it("compares numerically, not as strings") { expect(Lab::Since.applies?("0.13.0", source: pinned.("0.9.0"), gem_version: "0.9.0")).to be false }
it("treats an untagged spec as applicable") { expect(Lab::Since.applies?(nil, source: pinned.("0.1.0"), gem_version: "0.1.0")).to be true }
it("raises on a malformed tag") { expect { Lab::Since.applies?("soon", source: local, gem_version: "0.13.1") }.to raise_error(ArgumentError) }
```
`report_builder_spec.rb`: green/red arithmetic; `pending` counted and not green; `not_applicable` carried through; keys exactly as listed.
`hygiene_spec.rb`: unit cases build banned words by string concatenation (so the spec file itself stays clean), assert each is reported with the file name; then `it "the real spec tree is clean"` runs `Lab::Hygiene.violations` over every file in `shared/spec/**/*.rb` and expects `[]`; a system-spec sample containing `page.driver.post` is flagged while the same text under `requests/` is not.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/since_spec.rb shared/spec/lab/report_builder_spec.rb shared/spec/lab/hygiene_spec.rb`
Expected: FAIL (`uninitialized constant Lab::Since`).

- [ ] **Step 3: Implement the four lib files and spec_helper changes**

Tagged-example output must be honest: the excluded examples are listed by the formatter, never silently dropped. `ReportFormatter` must write the file even when 0 examples ran and when a spec file failed to load (`errors_outside_examples` from `notification.errors_outside_of_examples_count`).

- [ ] **Step 4: Run to verify pass and look at the artifacts**

Run: `bin/test 8.1 shared/spec/lab`
Expected: `0 failures`; first output lines show `permittable <version> (local)`, `Rails 8.1.x`, `ruby 3.3.x`; `apps/rails-8_1/tmp/lab-report.json` exists and `ruby -rjson -e 'p JSON.parse(File.read("apps/rails-8_1/tmp/lab-report.json")).keys'` lists the keys above.

- [ ] **Step 5: Commit**

```bash
git add shared
git commit -m "feat: since tagging, JSON run report, hygiene guard against skip/pending"
```

---

### Task 5: `bin/matrix`

**Files:**
- Create: `shared/lib/lab/matrix_report.rb`, `shared/spec/lab/matrix_report_spec.rb`, `bin/matrix`

**Interfaces:**
- Produces:
  - `Lab::MatrixReport.row(version:, report:, exit_status:, log_path: nil) -> Lab::MatrixReport::Row` (Struct: `version, rails, ruby, gem_label, green, red, not_applicable, status, failed, na_list`), `status` in `:pass | :red | :failed_to_run`. `report` is the parsed JSON Hash or `nil`.
  - `Lab::MatrixReport.render(rows) -> String` (table header `Rails | Ruby | Gem | Green | Red | N/A | Result`, followed by one block per row listing failed example locations and the not-applicable cases with their `since`).
  - `Lab::MatrixReport.exit_code(rows) -> 0 | 1`.
  - `bin/matrix [VERSION...]` (stdlib Ruby, works on Ruby >= 2.7): for each version (default all three, in order 7.2, 8.0, 8.1) runs `bin/test VERSION`, streams output to `tmp/matrix/VERSION.log`, reads `apps/rails-X_Y/tmp/lab-report.json`, prints the table, exits `exit_code`.
- Consumes: report JSON keys from Task 4.

- [ ] **Step 1: Write the failing spec** (`# README: Development`)

Cases, each asserting `status`: all green and exit 0 -> `:pass`; any `failures` -> `:red`; any `pending` -> `:red`; `errors_outside_examples > 0` -> `:red`; `report: nil` -> `:failed_to_run`; `examples == 0` -> `:failed_to_run` (nothing ran is never green); `exit_status != 0` with a report that claims 0 failures -> `:failed_to_run` (the two disagree). `render` includes the string `"3 cases not applicable to permittable 0.12.0"` and each case description when `not_applicable` has three entries, and the text `FAILED TO RUN` for a nil report. `exit_code([pass, pass])` is 0; `exit_code([pass, failed_to_run])` is 1.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/matrix_report_spec.rb`
Expected: FAIL (`uninitialized constant Lab::MatrixReport`).

- [ ] **Step 3: Implement `matrix_report.rb` and `bin/matrix`**

- [ ] **Step 4: Run to verify pass, then try the script**

Run: `bin/test 8.1 shared/spec/lab/matrix_report_spec.rb`
Expected: `0 failures`.
Run: `bin/matrix 8.1; echo "exit=$?"`
Expected: a one-row table with `PASS`, `exit=0`.
Run: `bin/matrix 7.2 8.1; echo "exit=$?"`
Expected: the 7.2 row says `FAILED TO RUN` (app not generated yet) and `exit=1`.

- [ ] **Step 5: Commit**

```bash
git add bin/matrix shared/lib/lab/matrix_report.rb shared/spec/lab/matrix_report_spec.rb
git commit -m "feat: bin/matrix table and exit code, failed-to-run never green"
```

---

### Task 6: Coverage matrix file, checker, seeded rows

**Files:**
- Create: `docs/coverage-matrix.yml`, `shared/lib/lab/coverage_matrix.rb`, `shared/spec/lab/coverage_matrix_spec.rb`, `bin/coverage-report`

**Interfaces:**
- Produces:
  - Row format (YAML list), all keys required except the optional ones:
    ```yaml
    - id: opt-nullable          # kebab-case, unique
      area: field-option        # out-of-scope|declaring|field-kind|field-option|preset|type|absence|error|i18n|problem|unknown-params|reuse|reshape|drift|logging|events|monitor|rake|beyond-controller|config|classload|changelog
      feature: "nullable: explicit null clears the column"
      readme: "Explicit nulls (nullable:)"     # README heading or table row
      since: "0.6.0"            # first version whose CHANGELOG lists it
      plan: 1                   # which lab plan covers it (1..6)
      status: "chưa phủ"        # a spec path, "chưa phủ", "chờ tác giả", or "ngoài phạm vi"
      question: null            # required when status is "chờ tác giả"
      reason: null              # required when status is "ngoài phạm vi" (plan may then be omitted)
      also: []                  # optional extra spec paths
      changelog: []             # optional: versions in 0.11.0..0.13.1 whose entries this row covers
    ```
  - `Lab::CoverageMatrix.load(path) -> Array<Hash>`; `.problems(rows, spec_root:, spec_files:) -> Array<String>`; `.summary(rows) -> {total:, covered:, uncovered:, awaiting_author:, out_of_scope:}`; `bin/coverage-report [--strict]` prints the summary and the uncovered rows grouped by `plan`; `--strict` exits 1 if any row is `chưa phủ`.
  - Spec tie-in: a spec file declares `covers: %w[row-id ...]` (metadata on a group or example) and a `# README: <section>` comment; `problems` checks a path-status row's file really contains `covers:` with that id.
- Consumes: nothing from earlier tasks except `spec_helper`.

- [ ] **Step 1: Write failing specs** (`# README: Contents`)

Unit cases for `problems` (each returns a message mentioning the row id): duplicate id; unknown `area`; `plan` not 1..6 (nil is allowed only for `ngoài phạm vi`); `status` is a path that does not exist; `status` is an existing file with no `covers:` for that id; `status: "chờ tác giả"` with no `question`; `status: "ngoài phạm vi"` with no `reason`; a status outside the four allowed forms; `since` not a `Gem::Version`; a `covers:` id in some spec with no matching row (orphan). Then `it "the real matrix is consistent"`: `Lab::CoverageMatrix.problems(real_rows, ...)` is `[]`, and `it "has the seeded anchor rows"` asserts every id in the **Anchor ids** list below is present.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb`
Expected: FAIL (`uninitialized constant Lab::CoverageMatrix`).

- [ ] **Step 3: Implement `coverage_matrix.rb` (stdlib only, Ruby 2.7 compatible) and `bin/coverage-report`**

- [ ] **Step 4: Seed `docs/coverage-matrix.yml`**

Rules: (a) one row per item below; (b) also one row per user-visible bullet of CHANGELOG `0.11.0`, `0.11.1`, `0.12.0`, `0.13.0`, `0.13.1`, and per bullet of the README list "Errors caught at class load" (ids `classload-*`); when a bullet's behaviour is already an anchor row, add its version to that row's `changelog:` list instead of a new row (ids for new ones: `cl-<version with underscores>-<n>`); (c) one row per rake task option and per config setter in README "Reference > API"; (d) `since` is the first CHANGELOG version that introduced the behaviour (`0.1.0` for baseline); (e) `status` starts `chưa phủ` everywhere, flipped to a spec path by the task that writes the spec; (f) `plan` follows the mapping at the end of this task; (g) rows the README cannot settle are `chờ tác giả` with a `question` (none at seed time). README claims outside spec section 2 get rows with `area: out-of-scope`, status `ngoài phạm vi` and a `reason`: `scope-rails-below-7-2` (Compatibility: Rails 6.1-7.1), `scope-ruby-ci-matrix` (Ruby 3.2-4.0 and ActiveSupport 6.1-8.1 CI), `scope-activesupport-only-install`, `scope-benchmark`, `scope-docs-comparison`, `scope-development-section`.

**Anchor ids** (must all exist):
- declaring: `pp-root pp-model pp-model-true-infer pp-unknown pp-enforce-true pp-enforce-lazy pp-mode-monitor pp-desc pp-catch-all pp-last-rule-wins pp-subclass-override`
- field kinds: `kind-scalar kind-nested kind-array-scalar kind-array-hash kind-array-fields-for-hash kind-array-length-short-circuit kind-json`
- options: `opt-in-range opt-in-list opt-in-live-include opt-in-enum-hash opt-format-regexp opt-length-string opt-length-array opt-length-integer-exact opt-normalize-squish opt-normalize-strip opt-normalize-downcase opt-normalize-upcase opt-normalize-email opt-normalize-proc opt-default-cast opt-default-as-authored-with-transform opt-validate-falsy opt-validate-symbol-code opt-transform opt-virtual opt-sensitive opt-sensitive-cascade opt-sensitive-false-opt-out opt-message-string opt-message-hash opt-of opt-max-depth opt-required-array opt-desc opt-example opt-nullable opt-nullable-required opt-nullable-default-nil opt-nullable-array-nested opt-check-order`
- presets: `preset-email preset-uuid preset-url preset-slug preset-hostname`
- types: `type-string type-integer type-float type-decimal type-boolean type-date type-datetime type-json type-confusion-array-for-scalar type-string-encoding`
- absence: `absent-nullable-normalize-blank absent-blank-array-only-result absent-nil-and-empty absent-normalize-first absent-optional-omitted absent-required-missing absent-default absent-blank-array-element absent-false-is-present`
- errors: `err-code-missing err-code-invalid-type err-code-inclusion err-code-format err-code-length err-code-unknown err-code-invalid err-code-custom-symbol err-status-400-root-missing err-status-400-root-wrong-shape err-status-422-field err-path-dotted-indexed err-details-complete-message-bounded err-envelope-json err-render-error-custom err-render-error-private err-render-error-three-keyword err-rescue-from-order`
- i18n/messages: `i18n-default-messages i18n-fallback-order i18n-per-request-locale msg-string msg-hash msg-violate-keyword`
- problem+json: `problem-format problem-title-by-status problem-base-uri problem-instance problem-opts-out-render-error`
- unknown params: `unknown-ignore unknown-log unknown-error unknown-every-level unknown-exempt-router-keys unknown-exempt-csrf unknown-exempt-csrf-renamed unknown-exempt-form-keys unknown-exempt-commit unknown-exempt-button unknown-exempt-image-submit unknown-exempt-path-params unknown-wrapper-key date-select-parts datetime-select-parts time-select-parts date-parts-blank date-parts-invalid date-parts-own-key-wins date-parts-time-zone-recipe`
- reuse/reshape: `use-group use-compose use-optional use-only-except use-contract use-refuses-finalize use-override-duplicate transform-field transform-default-authored finalize-basic finalize-violate finalize-bare-runner`
- drift: `drift-missing-column drift-migration-hint drift-ignored-columns drift-virtual drift-nested-implicit-virtual drift-schema-unreachable drift-check-types drift-type-groups drift-enum drift-pg-array-column`
- logging/events/monitor: `log-filter-params log-filter-non-string log-filter-sql-bind log-registry-swap log-assign-heals event-payload event-mode event-once-per-request monitor-pass-through monitor-violations monitor-env monitor-rule-beats-global monitor-eager monitor-uncheckable-logged`
- rake: `rake-audit-table rake-audit-strict rake-audit-stale rake-audit-ignore rake-audit-outside-root rake-audit-engines rake-audit-metal rake-audit-routes-order rake-openapi-stdout rake-openapi-file rake-openapi-engines rake-openapi-metal rake-openapi-path-params rake-openapi-problem rake-openapi-monitor-extension rake-generate-all rake-generate-one rake-generate-expect-permit rake-generate-monitor-draft rake-generate-ignore rake-generate-pg-array`
- beyond controller: `matcher-permit-param matcher-accept-reject matcher-negated matcher-preset contract-call contract-call-bang contract-json-schema contract-always-enforces contract-no-router-exemption contract-no-memo contract-input-errors contract-unknown-log audit-entries-plain generator-draft-plain registry-swap alias-concerns-on-rails`
- config: `cfg-mode cfg-error-format cfg-problem-base-uri cfg-check-column-types cfg-audit-ignore cfg-audit-ignore-outside-root`

Rows with a stated expectation (author's answers, status `chưa phủ` at seed, plan 1, flipped by Tasks 8 and 9): `absent-nullable-normalize-blank` (a `nullable:` + `normalize: :squish` field receiving `"   "` gives `nil`) and `absent-blank-array-only-result` (a scalar array receiving only `[""]` gives `[]`). `drift-pg-array-column` and `rake-generate-pg-array` are `chưa phủ`, plan 6 (PostgreSQL is the lab database).

Plan mapping: Plan 1 = declaring/kinds/options/presets/types/absence/errors/i18n/date-select rows that the Tạo đơn form exercises (see flips in Tasks 8-11); Plan 2 = `pp-enforce-lazy`, `opt-in-*` on status, `use-*`, `finalize-*`, `absent-*` partial-update rows, path params; Plan 3 = `type-float/boolean`, `kind-json`, `opt-max-depth`, `opt-in-live-include`, `opt-validate-*`, `opt-transform`, `opt-virtual`, `problem-*`, `cfg-error-format`, `cfg-problem-base-uri`, `unknown-wrapper-key`, Metal rows; Plan 4 = engine rows, `cfg-audit-ignore-outside-root`, `rake-*-engines`, `rake-*-metal` (route side); Plan 5 = `contract-*`, `monitor-*`, `unknown-log`/`ignore`, `unknown-exempt-*` (a rootless HTML form: see the author question on exemptions), `rake-generate-*` (legacy controller side); Plan 6 = `rake-audit-*`, `rake-openapi-*`, `rake-generate-*`, `drift-*`, `log-*`, `matcher` details not done in Plan 1, `audit-entries-plain`, `generator-draft-plain`, `registry-swap`, `alias-concerns-on-rails`, `cfg-*`, `classload-*`, `event-*` not done in Plan 1, `err-rescue-from-order`.

- [ ] **Step 5: Run to verify pass**

Run: `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb && ruby bin/coverage-report`
Expected: `0 failures`; the report prints `total`, `covered 0`, `awaiting_author 0`, `out_of_scope 6` and the uncovered rows grouped by plan; exit 0. `ruby bin/coverage-report --strict` exits 1 (rows still `chưa phủ`).

- [ ] **Step 6: Commit**

```bash
git add docs/coverage-matrix.yml shared/lib/lab/coverage_matrix.rb shared/spec/lab/coverage_matrix_spec.rb bin/coverage-report
git commit -m "feat: coverage matrix format, checker and README/CHANGELOG-derived rows"
```

---

### Task 7: Domain models, migrations, seeds

**Files:**
- Create: `shared/db/migrate/*_create_customers.rb`, `*_create_orders.rb`, `*_create_order_items.rb`, `shared/app/models/{customer,order,order_item}.rb`, `shared/db/seeds.rb`, `shared/spec/models/{customer,order,order_item}_spec.rb`, `shared/spec/lab/seeds_spec.rb`
- Modify: `bin/test` (runs `RAILS_ENV=test bin/rails db:create db:migrate` before rspec, e.g. `bash -c 'RAILS_ENV=test bin/rails db:create db:migrate && exec bundle exec rspec "$@"' --`), `shared/spec/spec_helper.rb` (`ActiveRecord::Migration.check_all_pending!`)

**Interfaces:**
- Produces schema (migrations written once, plain Rails column types; `json` columns, PostgreSQL):
  - `customers`: `name` string null:false, `email` string null:false, `phone` string, timestamps.
  - `orders`: `customer_id` references null:false; `code` string null:false, unique index; `status` string null:false default `"pending"`; `priority` string null:false default `"standard"`; `delivery_on` date null:false; `pickup_at` datetime; `delivery_slot` time; `coupon_code` string; `note` string; `services` json null:false default `[]`; `shipping_address` json null:false default `{}`; timestamps.
  - `order_items`: `order_id` references null:false; `sku` string null:false; `quantity` integer null:false; `unit_price` decimal(10,2) null:false; timestamps.
- Models: `Customer has_many :orders`; `Order belongs_to :customer; has_many :items, class_name: "OrderItem", inverse_of: :order, dependent: :destroy; accepts_nested_attributes_for :items` (not for `customer`); `enum :status, { pending: "pending", confirmed: "confirmed", shipped: "shipped", delivered: "delivered", cancelled: "cancelled" }`; constants `Order::PRIORITIES = %w[standard express].freeze`, `Order::SERVICES = %w[gift_wrap insurance signature].freeze`; `code` assigned before validation as `"ORD-" + SecureRandom.hex(4).upcase`; `Order#total -> BigDecimal` (sum of `quantity * unit_price`); `Order.build_from_contract(attrs) -> Order` (unsaved; `attrs` is the permitted hash: builds `Customer.new(attrs["customer"])`, passes the rest including `items_attributes`, never `customer_attributes`).
- Consumes: `Lab::Boot` migration/seeds paths (Task 3).

- [ ] **Step 1: Write failing specs**

`order_spec.rb`: a valid order saves; `code` matches `/\AORD-[0-9A-F]{8}\z/` and is unique across two orders; `status` defaults to `"pending"` and `pending?` is true; an order with no items is invalid; `total` of items (2 x 10.50, 1 x 3.00) is `BigDecimal("24.00")`; `build_from_contract` with an inline hash (`"customer"` with name/email/phone, `"shipping_address"`, `"delivery_on"` a `Date`, `"services"`, `"items_attributes"` with two rows) builds an unsaved order with a customer, two items, and never touches `customer_attributes`. `order_item_spec.rb`: quantity must be an integer >= 1. `customer_spec.rb`: name and email required. `seeds_spec.rb`: `Rails.application.load_seed` twice leaves `Customer.count == 3`, `Order.count == 6`, and all five statuses present.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/models shared/spec/lab/seeds_spec.rb`
Expected: FAIL (`uninitialized constant Order`).

- [ ] **Step 3: Implement migrations, models, seeds**

Seeds are idempotent (`find_or_create_by!` on customer email and order code, using fixed codes such as `ORD-SEED0001`). Seed orders cover pending, confirmed, shipped, delivered, cancelled plus one extra express order, each with 1-3 items.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/models shared/spec/lab/seeds_spec.rb`
Expected: `0 failures`. Also `docker compose run --rm rails-8_1 bin/rails db:create db:migrate db:seed && git status --porcelain` prints nothing (no `schema.rb`).

- [ ] **Step 5: Commit**

```bash
git add shared
git commit -m "feat: customer, order, order item models with migrations and seeds"
```

---

### Task 8: Tạo đơn: contract, controller, view, i18n, request specs

**Files:**
- Create: `shared/app/controllers/orders_controller.rb`, `shared/app/field_groups/shipping_address_fields.rb`, `shared/app/views/orders/{index,show,new,_violations}.html.erb`, `shared/spec/support/order_payloads.rb`, `shared/spec/requests/orders_create_spec.rb`
- Modify: `shared/app/controllers/base_controller.rb`, `shared/app/views/layouts/lab.html.erb`, `shared/config/routes.rb`, `shared/config/locales/{vi,en}.yml`, `docs/coverage-matrix.yml`

**Interfaces:**
- Produces:
  - Routes: `resources :orders, only: %i[index show new create]`; `BaseController` gets `prepend_around_action :switch_locale` (locale from `params[:locale]` if it is a `String` in `I18n.available_locales`, else `I18n.default_locale`) and `default_url_options -> { locale: I18n.locale }`; the navbar gets two links to the current page with `locale=vi` (text `Tiếng Việt`, `id="locale-vi"`) and `locale=en` (text `English`, `id="locale-en"`), the same text in both locales.
  - `ShippingAddressFields = Permittable.fields { required :line1, :string, length: 1..100, normalize: :squish; required :city, :string, length: 1..80, normalize: :squish; required :postcode, :string, length: 3..10, normalize: :upcase }`.
  - Contract on `OrdersController` (exact):
    ```ruby
    permit_params :create, root: :order, model: Order, unknown: :error, enforce: true, desc: "Tạo đơn" do
      required :customer do
        required :name,  :string, length: 1..80, normalize: :squish
        required :email, :string, format: :email, normalize: :email
        optional :phone, :string, length: 6..20, sensitive: true
      end
      required :shipping_address do
        use ShippingAddressFields
      end
      required :delivery_on, :date
      optional :pickup_at, :datetime
      optional :delivery_slot, :datetime
      optional :priority, :string, in: Order::PRIORITIES, default: "standard"
      optional :coupon_code, :string, format: /\A[A-Z]{3}\d{3}\z/
      optional :note, :string, length: 1..200, normalize: :squish, nullable: true
      array :services, of: :string, length: 0..3
      array :items_attributes, required: true, length: 1..20 do
        required :sku, :string, length: 1..40
        required :quantity, :integer, in: 1..99
        required :unit_price, :decimal, in: BigDecimal("0")..BigDecimal("9999.99")
      end
    end
    ```
  - `OrdersController#create`: `Order.build_from_contract(permitted_params).save!`, `redirect_to order_path(order), status: :see_other`. Private `render_error(message:, code:, status:, errors: [])`: sets `@violations = errors`, `@order = Order.new`, `render :new, status: status` (integer status passed through: 400 for a bad root, 422 for fields).
  - `new.html.erb`: `form_with model: @order, url: orders_path` with: `fields_for :customer` (names `order[customer][name|email|phone]`), `fields_for :shipping_address` (`order[shipping_address][line1|city|postcode]`), `date_select :delivery_on, prompt: true` (year range current year to +2), `datetime_select :pickup_at, include_blank: true`, `time_select :delivery_slot, include_blank: true`, `select :priority`, `text_field :coupon_code`, `text_area :note`, `collection_check_boxes :services, Order::SERVICES, :to_s, :to_s`, `fields_for :items` with exactly one blank `OrderItem` row (names `order[items_attributes][0][sku|quantity|unit_price]`), `f.submit` and a second submit `button_tag`. `_violations.html.erb` renders each violation as `<li data-param="order.customer.email" data-code="format">` with the resolved message, or the code when none.
  - `OrderPayloads` (spec support): `OrderPayloads.form_params(overrides = {}) -> {"order" => Hash}` exactly as a browser posts it (string keys, `delivery_on(1i)/(2i)/(3i)`, `note` as `""`, `services` as `["", "gift_wrap"]`, `items_attributes` as a hash keyed `"0"`); `overrides` is deep-merged into the `order` hash and a `nil` value deletes that key. `OrderPayloads.contract_output -> Hash` is the expected `permitted_params`, **written by hand from the README rules** (date parts assembled to a `Date`, `note` nil, `services` without the `""`, `priority` defaulted, absent optionals omitted), never copied from a run.
  - Locale copy (authored here, used verbatim by the specs). vi `permittable.errors`: `missing: "là bắt buộc"`, `invalid_type: "sai kiểu dữ liệu"`, `inclusion: "không thuộc danh sách cho phép"`, `format: "sai định dạng"`, `length: "sai độ dài"`, `unknown: "không phải tham số hợp lệ"`, `invalid: "không hợp lệ"`. en: `"is required"`, `"is the wrong type"`, `"is not an allowed value"`, `"has an invalid format"`, `"has the wrong length"`, `"is not a recognized parameter"`, `"is invalid"`. Also all form labels, headings and the two submit captions (`Tạo đơn` / `Create order`; the `button_tag` caption `Tạo đơn (nút)` / `Create order (button)`).
- Consumes: models and `build_from_contract` (Task 7); `BaseController`, layout (Task 3).

- [ ] **Step 1: Write the failing request spec** (`# README: Declaring a contract; Unknown parameters; Violations and error responses; Localizing default messages (I18n)`)

`since: "0.12.0"` on the top-level `describe` (the form needs `date_select` support and blank-element dropping from 0.12.0, and private `render_error` delegation from 0.12.0). `covers: %w[pp-root pp-model pp-unknown pp-enforce-true kind-nested kind-array-hash kind-array-fields-for-hash kind-array-scalar kind-scalar opt-in-range opt-in-list opt-format-regexp opt-length-string opt-length-array opt-default-cast opt-normalize-squish opt-normalize-email opt-nullable preset-email type-integer type-decimal type-date type-datetime absent-blank-array-element absent-nullable-normalize-blank absent-optional-omitted absent-required-missing absent-default err-code-missing err-code-invalid-type err-code-inclusion err-code-format err-code-length err-code-unknown err-status-400-root-missing err-status-400-root-wrong-shape err-status-422-field err-path-dotted-indexed err-render-error-custom err-render-error-private i18n-default-messages i18n-per-request-locale unknown-error unknown-every-level date-select-parts datetime-select-parts time-select-parts date-parts-blank date-parts-invalid use-group]`. Examples (all `post orders_path, params: ...`):
1. **Valid form post** with `name: "  Nguyễn   Văn A "`, `email: " Ana@Example.COM "`, items hash `{"0"=>{sku:"SKU1",quantity:"2",unit_price:"199.5"}}`, `services: ["", "gift_wrap"]`, `note: ""`: `response` is 303 to `order_path(Order.last)`; `Order.last` has customer name `"Nguyễn Văn A"`, email `"ana@example.com"`, `priority == "standard"`, `status == "pending"`, `note == nil`, `services == ["gift_wrap"]`, `delivery_on` a `Date`, item `quantity == 2` (Integer), `unit_price == BigDecimal("199.5")`.
1a. **Blank-ish values (author's expectations)**: valid params with `note: "   "` and `services: [""]` give 303 and `Order.last.note == nil` (`nullable:` + `normalize: :squish` on whitespace yields nil, not omitted); the all-unchecked `services` post is accepted. (`services == []` as a `permitted_params` value is asserted in Task 9.)
2. **Form-added top-level keys do not break the post**: the valid params plus `"commit" => "Tạo đơn"`, and again with `"button" => ""`, both give 303. This is *not* coverage of the `commit`/`button`/CSRF exemptions: with `root: :order` those keys sit outside the root and are never checked (see the author question).
3. **Violations table** (422, body contains `li[data-param=P][data-code=C]`, `Order.count` unchanged), P/C: `order.customer.email`/`format` (`"not-an-email"`), `order.customer.name`/`missing` (`""`), `order.customer.phone`/`length` (`"12"`), `order.items_attributes[0].quantity`/`inclusion` (`"0"`) and `invalid_type` (`"abc"`), `order.items_attributes[0].unit_price`/`inclusion` (`"-1"`), `order.coupon_code`/`format` (`"abc"`), `order.priority`/`inclusion` (`"overnight"`), `order.note`/`length` (201 chars), `order.services`/`length` (four boxes plus the hidden `""`), `order.shipping_address.city`/`missing`, `order.delivery_on`/`missing` (month blank, as `prompt: true` sends) and `invalid_type` (`(2i)=2`, `(3i)=30`).
4. **Mass assignment** (Review Focus 3): each of `order[status]=delivered`, `order[code]=X`, `order[customer_id]=1`, `order[customer][admin]=1` gives 422, the matching `unknown` violation (`order.status`, `order.code`, `order.customer_id`, `order.customer.admin`), and no new rows.
5. **Bad root** (Review Focus 2): `post orders_path` (no params) -> 400, form re-rendered (`form[action]` present), violation `order`/`missing`; `order=bob` -> 400, `order`/`invalid_type`; neither is a 500.
6. **Oversized collection**: 21 item rows -> 422 with exactly one violation `order.items_attributes` / `length` (no per-element violations); the same items as a JSON-style array under `items_attributes[]` is not asserted here.
7. **Locale** (Review Focus 1): `?locale=vi` with missing name -> body includes `"là bắt buộc"`; `?locale=en` -> `"is required"`; `locale=xx`, `locale=`, `locale[]=vi` -> 200/422 in Vietnamese, never 500; the enforce path and `prepend_around_action` together give the request's locale (README rule), checked by the English case above.
8. **CSRF for real**: with `ActionController::Base.allow_forgery_protection = true` for the example (restored in `ensure`), `get new_order_path`, read the hidden `authenticity_token` and `post` it back with valid params -> 303 (the post works with a real token in the body); posting without the token creates no order.
9. **Pages**: `get orders_path` lists seeded orders with `code` and `total`; `get order_path(order)` shows items; unknown id -> 404.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/requests/orders_create_spec.rb`
Expected: FAIL (`uninitialized constant OrdersController` / routing error).

- [ ] **Step 3: Implement routes, `BaseController` locale switch, contract, controller, views, field group, locale files**

The controller's `render_error` must be `private` and take `errors:` (README: delegated to). The views must produce the field names listed in Interfaces; assert the names in a small example (`input[name="order[items_attributes][0][quantity]"]`, `select[name="order[delivery_on(1i)]"]`, `input[type=checkbox][name="order[services][]"]`, hidden `order[services][]` value `""`).

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/requests/orders_create_spec.rb`
Expected: `0 failures`. Any failure that is the gem differing from the README stays red and goes in the hand-off report; do not adjust the expected value.

- [ ] **Step 5: Flip matrix rows**

In `docs/coverage-matrix.yml` set `status: shared/spec/requests/orders_create_spec.rb` for every id in the `covers:` list above, then run `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb` -> `0 failures`.

- [ ] **Step 6: Commit**

```bash
git add shared docs/coverage-matrix.yml
git commit -m "feat: Tạo đơn form, contract with render_error, i18n and request specs"
```

---

### Task 9: Gem matcher specs for the Tạo đơn contract

**Files:**
- Create: `shared/spec/controllers/orders_contract_spec.rb`
- Modify: `docs/coverage-matrix.yml`

**Interfaces:**
- Consumes: `OrdersController` contract (Task 8), `OrderPayloads` (Task 8), `require "permittable/rspec"` (gem).
- Produces: nothing for later tasks.

- [ ] **Step 1: Write the failing spec** (`# README: Testing contracts (RSpec matchers)`, `since: "0.12.0"` on the top-level `describe` (the raising chains and the `matching(:email)` spelling need 0.12.0), `covers: %w[matcher-permit-param matcher-accept-reject matcher-negated matcher-preset absent-blank-array-only-result]`)

Assertions:
```ruby
require "permittable/rspec"
RSpec.describe OrdersController do
  it "declares the create contract" do
    expect(described_class).to permit_param("customer.email").for_action(:create).as(:string).matching(:email).required
    expect(described_class).to permit_param("customer.phone").for_action(:create).sensitive
    expect(described_class).to permit_param(:delivery_on).for_action(:create).as(:date).required
    expect(described_class).to permit_param(:priority).for_action(:create).within(%w[standard express]).with_default("standard")
    expect(described_class).to permit_param(:note).for_action(:create).nullable.optional.with_length(1..200)
    expect(described_class).to permit_param(:services).for_action(:create).as_array(of: :string)
    expect(described_class).to permit_param("items_attributes.quantity").for_action(:create).as(:integer).within(1..99)
    expect(described_class).to permit_param("shipping_address.city").for_action(:create).as(:string).required
  end
  it "does not declare the server-owned columns" do
    %i[status code customer_id].each { |f| expect(described_class).not_to permit_param(f).for_action(:create) }
  end
  it "accepts the browser payload and returns the cast output" do
    expect(described_class).to accept_params(OrderPayloads.form_params).for_action(:create).returning(OrderPayloads.contract_output)   # payload is { "order" => ... }
  end
  it "reads a scalar array holding only the hidden blank as an empty array" do   # author's answer
    expect(described_class).to accept_params(OrderPayloads.form_params("services" => [""])).for_action(:create)
      .returning(OrderPayloads.contract_output.merge("services" => []))
  end
  it "reads whitespace in a nullable squished field as nil" do
    expect(described_class).to accept_params(OrderPayloads.form_params("note" => "   ")).for_action(:create)
      .returning(OrderPayloads.contract_output.merge("note" => nil))
  end
  it "rejects named violations" do
    expect(described_class).to reject_params(OrderPayloads.form_params("customer" => { "name" => "", "email" => "x" })).for_action(:create)
      .with_violation("order.customer.name", :missing).with_violation("order.customer.email", :format)
  end
  it "negated forms" do
    expect(described_class).not_to accept_params(order: {}).for_action(:create)
    expect(described_class).not_to reject_params(OrderPayloads.form_params).for_action(:create)
  end
end
```
Also one example per chain that the README lists as raising: `not_to permit_param(:status).for_action(:create).required` raises `ArgumentError`; chaining `.returning` onto `reject_params` raises `ArgumentError`. The payload carries only the `order` root (the matchers run without a request, so no `authenticity_token`/`commit`).

- [ ] **Step 2: Run to verify failure/pass boundary**

Run: `bin/test 8.1 shared/spec/controllers/orders_contract_spec.rb`
Expected: either `0 failures` (contract already satisfies the README) or failures that are real findings. Do not edit expectations to match; report findings. If red because a helper is missing, add it in `OrderPayloads` only.

- [ ] **Step 3: Flip matrix rows and commit**

Set the five `covers` ids to `shared/spec/controllers/orders_contract_spec.rb`; run `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb` -> `0 failures`.

```bash
git add shared docs/coverage-matrix.yml
git commit -m "test: gem matcher specs for the Tạo đơn contract"
```

---

### Task 10: Inspector (development and test only)

**Files:**
- Create: `shared/app/inspector/inspector.rb`, `shared/app/inspector/inspector/{entry,store,current,middleware,controller_observer,log_tap}.rb`, `shared/app/controllers/inspector_controller.rb`, `shared/app/views/inspector/{show,_entry}.html.erb`, `shared/config/initializers/inspector.rb`, `shared/spec/inspector/{middleware_spec,store_spec}.rb`, `shared/spec/requests/inspector_spec.rb`, `shared/spec/lab/inspector_production_spec.rb`
- Modify: `shared/config/routes.rb`, `shared/app/controllers/base_controller.rb`, `shared/app/views/layouts/lab.html.erb`, `docs/coverage-matrix.yml`

**Interfaces:**
- Produces:
  - `Inspector.enabled?(env = Rails.env) -> Boolean`, true only for `development` and `test`.
  - `Inspector::Entry` (Struct): `request_id, method, path, status, raw_params, permitted, rejected, violations, response_body, content_type, log_lines, events, config`. `raw_params` is an `Array` of `[key, value]` pairs in the order sent, decoded from the query string and a urlencoded body with `URI.decode_www_form` (verbatim, `sensitive:` values included: author's decision, dev/test only; so keys such as `order[delivery_on(1i)]`, `order[items_attributes][0][sku]` and the hidden `order[services][]` = `""` appear literally; a non-urlencoded body appears as `[["(body)", text]]`); `permitted` is the Hash the action received or `nil`; `rejected` is true when `permitted_params` raised `Permittable::InvalidParameters`; `violations` is `[{param:, code:, message:}]`; `config` is `{error_format:, mode:}` read from `Permittable`.
  - `Inspector::Store`: `record(entry)`, `latest -> Entry | nil` (latest **tracked** entry: method is not GET, or the action read `permitted_params`), `recent(n = 10)`, `find(request_id)`, `clear`; thread-safe, capped at 50.
  - `Inspector::Middleware` (Rack): installed only when `Inspector.enabled?`; skips paths under `/inspector`; captures status, headers, body, a thread-local log buffer and notification events; returns the original status, headers and body bytes untouched, calls `close` on the original body, and re-raises app exceptions; if parsing the raw params raises (invalid UTF-8), it records `raw_params: [["(unparseable)", "..."]]` and still passes the response through. It rewinds `rack.input` after reading it. It does not buffer bodies of `text/event-stream` or hijacked responses.
  - `Inspector::ControllerObserver`, prepended into `BaseController`: wraps `permitted_params(*args)`: calls `super`, stores the result or flags `rejected`, re-raises the same exception object, never calls `permitted_params` itself.
  - `Inspector::LogTap`: attached with `Rails.logger.broadcast_to(...)`, copies lines into the current request's buffer only.
  - Subscriber on `invalid_parameters.permittable` appends the payload to the current entry's `events`.
  - `GET /inspector/last` (and `?entry=<request_id>`): HTML panel, drawn only when `Inspector.enabled?`. The layout shows it in `<iframe id="inspector-frame" src="/inspector/last">` beside the page (two-column CSS grid). ERB auto-escape everywhere; values longer than 1,000 characters are cut with `"... (N more characters)"`; the body is cut at 20,000 characters.
  - Panel sections (each with a stable id): `#inspector-status`, `#inspector-raw-params`, `#inspector-permitted` (shows `Bị từ chối` / `Rejected` when rejected), `#inspector-violations`, `#inspector-response`, `#inspector-log`, `#inspector-events`, `#inspector-config`.
- Consumes: `OrdersController`, `OrderPayloads` (Task 8); `Permittable.error_format`, `Permittable.mode`.

- [ ] **Step 1: Write failing specs**

`middleware_spec.rb` (stub Rack apps, no Rails request): a 200 `["abc"]` app returns identical status, headers and body through the middleware; `close` is called on the original body; an app that raises re-raises the same exception class; a request with an invalid UTF-8 query (`"/x?a=%FF"` via `Rack::MockRequest`) returns the app's own status and the entry's `raw_params` is `[["(unparseable)", ...]]`; a path under `/inspector/` is not recorded.
`store_spec.rb`: cap of 50 (oldest dropped); `latest` skips an untracked GET and returns the earlier tracked POST; `find` by request id; concurrent `record` from 10 threads loses nothing up to the cap.
`inspector_spec.rb` (request specs; `# README: Instrumentation; Sensitive parameters and log redaction`; `since: "0.12.0"` (it drives the Tạo đơn form); `covers: %w[opt-sensitive event-payload event-once-per-request]`):
1. After a valid `post orders_path, params: OrderPayloads.form_params`, `get "/inspector/last"` -> `#inspector-status` text includes `303`; `Inspector::Store.latest.raw_params` includes `["order[delivery_on(1i)]", "<year>"]` and `["order[services][]", ""]`, and `#inspector-raw-params` shows both literally; `#inspector-permitted` includes `"delivery_on"`.
2. After an invalid post (`email: "nope"`): status `422`; `#inspector-permitted` shows `Bị từ chối`; `#inspector-violations` has a row with `order.customer.email`, `format`, and the vi message `sai định dạng`; `#inspector-events` shows `enforce`; `#inspector-config` shows `envelope` and `enforce`.
3. Non-intrusion: an `ActiveSupport::Notifications` subscriber counts `invalid_parameters.permittable` during the invalid post and sees **1** event; `permitted_params` raised the same `InvalidParameters` the browser saw (response is the same 422 form).
4. `#inspector-log` contains a `Parameters:` line where the phone is redacted: it matches `/"phone"\s*=>\s*"\[FILTERED\]"/` (tolerates Ruby 3.4 `Hash#inspect` spacing) and does not contain the phone number sent.
5. Hostile input (Review Focus 5): `order[note]=<script>alert(1)</script>` shows as `&lt;script&gt;` and the page has no live `script` element inside the panel; a 10,000-character note is cut to 1,000 characters plus the "more characters" marker; `post` with body `order[note]=%FF` (invalid UTF-8) returns the same 400 as the app alone and `/inspector/last` still renders 200.
6. `get new_order_path` alone does not replace the last tracked POST.
`inspector_production_spec.rb`: `Inspector.enabled?("production")` is false and `enabled?("development")`/`("test")` true; and a subprocess `SECRET_KEY_BASE_DUMMY=1 RAILS_ENV=production bin/rails runner 'puts Rails.application.middleware.map(&:inspect).grep(/Inspector/).empty?; puts Rails.application.routes.routes.map { |r| r.path.spec.to_s }.grep(/inspector/).empty?'` prints `true` twice. If booting in production needs more environment than `SECRET_KEY_BASE_DUMMY`, set exactly what is needed in the subprocess env; do not weaken the assertion.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/inspector shared/spec/requests/inspector_spec.rb shared/spec/lab/inspector_production_spec.rb`
Expected: FAIL (`uninitialized constant Inspector`).

- [ ] **Step 3: Implement the Inspector and layout**

Initializer `shared/config/initializers/inspector.rb`: `if Inspector.enabled?` insert the middleware (`app.config.middleware.insert_before` the router-adjacent `ActionDispatch::ShowExceptions` so it sees the final response), subscribe, attach the log tap. The `ControllerObserver` prepend is also gated on `Inspector.enabled?`.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/inspector shared/spec/requests shared/spec/lab/inspector_production_spec.rb`
Expected: `0 failures`.

- [ ] **Step 5: Flip matrix rows and commit**

Set `opt-sensitive`, `event-payload`, `event-once-per-request` to `shared/spec/requests/inspector_spec.rb`; run the coverage spec -> `0 failures`.

```bash
git add shared docs/coverage-matrix.yml
git commit -m "feat: Inspector panel (dev/test only) with non-intrusive capture"
```

---

### Task 11: System specs through the real form (headless browser)

**Files:**
- Create: `shared/spec/support/capybara.rb`, `shared/spec/system/orders_create_spec.rb`
- Modify: `shared/spec/spec_helper.rb` (require support files; `config.include` system helpers), `docs/coverage-matrix.yml`

**Interfaces:**
- Produces: Capybara driver `:lab_cuprite` (`Capybara::Cuprite::Driver`, `browser_path: ENV["BROWSER_PATH"]`, `window_size: [1280, 900]`, `browser_options: { "no-sandbox" => nil, "disable-gpu" => nil }`, `process_timeout: 30`), set as the system-spec driver.
- Consumes: the real Tạo đơn form (Task 8), Inspector iframe (Task 10), hygiene rules (Task 4: no hand-built payloads in `system/`).

- [ ] **Step 1: Write the failing system spec** (`# README: Unknown parameters; Localizing default messages (I18n)`; `since: "0.12.0"` on the top-level `describe`; `covers: %w[date-select-parts datetime-select-parts time-select-parts date-parts-blank date-parts-invalid absent-blank-array-element i18n-per-request-locale]` on the examples that exercise them; these ids already point to the request spec, so system specs are listed in `also:` for them)

Every example uses only `visit`, `fill_in`, `select`, `check`, `click_button`, `click_link`, `within_frame` and `have_css`/`have_text`; none posts a payload or runs a script that submits. Each example sets `ActionController::Base.allow_forgery_protection = true` in `before` and restores it in `after`.
1. **Happy path via `f.submit`**: `visit new_order_path(locale: :vi)`; fill customer name `"  Nguyễn   Văn B "`, email `" Ben@Example.COM "`, phone, address, select delivery date day/month/year (year `Date.current.year + 1`), choose a pickup datetime and a time slot `09:30`, check two service boxes, fill the item row, leave note empty, `click_button "Tạo đơn"`. Expect the order page for the new `Order.last` (`current_path == order_path(Order.last)`), customer email `ben@example.com`, `services` has the two checked values, `delivery_slot.strftime("%H:%M") == "09:30"`. Then `within_frame("inspector-frame")`: `#inspector-status` shows `303`, `#inspector-raw-params` shows `(1i)` and the hidden `""` for `services`, `#inspector-permitted` is not rejected.
2. **Through `button_tag`**: same fill, `click_button "Tạo đơn (nút)"` -> order created (the real browser sends `button=`; with `root:` it is outside the contract, so this proves the submit works, not the exemption).
3. **Errors re-rendered, Turbo style**: fill an invalid email `"nope"`, select delivery date 30 February, leave the quantity at `0`; submit -> still on the form (`current_path == orders_path`, form present), `li[data-param="order.customer.email"]` shows `sai định dạng`, `li[data-param="order.delivery_on"]` is `invalid_type`, `li[data-param="order.items_attributes[0].quantity"]` is `inclusion`; the inspector frame shows `422` and `Bị từ chối`; no `Order` was created. Then leave one date part on its prompt -> `order.delivery_on` is `missing`.
4. **Locale switch**: `click_link "English"` on the navbar -> labels are English; submit with an empty name -> `li[data-param="order.customer.name"]` says `is required`.
5. **Untouched `time_select`** (README sentence "a `time_select` left on its prompts ... gives `0001-01-01T00:00:00`"): submit a valid form leaving the slot on its blanks -> the order page shows `delivery_slot` `00:00`.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/system`
Expected: FAIL (`Capybara::DriverNotFoundError` / missing support file).

- [ ] **Step 3: Implement `support/capybara.rb` and hook it in `spec_helper.rb`**

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/system && bin/test 8.1 shared/spec/lab/hygiene_spec.rb`
Expected: `0 failures` for both. A system example that fails because the gem differs from the README stays red and goes in the report.

- [ ] **Step 5: Add `also:` paths, run the full 8.1 suite, commit**

Add `also: [shared/spec/system/orders_create_spec.rb]` to the ids above in the matrix; run `bin/test 8.1` -> `0 failures` unless findings exist.

```bash
git add shared docs/coverage-matrix.yml
git commit -m "test: system specs fill and submit the real Tạo đơn form in headless Chromium"
```

---

### Task 12: Rails 7.2 and 8.0 apps, full matrix, README

**Files:**
- Create: `apps/rails-7_2/**`, `apps/rails-8_0/**` (generated), `apps/README.md` (append), `README.md`
- Modify: `compose.yml` (two services), `docs/coverage-matrix.yml` (no change expected)

**Interfaces:**
- Produces: Compose services `rails-7_2` (port 3072, volume `bundle-7_2`) and `rails-8_0` (port 3080, volume `bundle-8_0`), identical to `rails-8_1` except version, port, volume and the port in the default command. `bin/new-app 7.2`, `bin/new-app 8.0` outputs patched by `shared/bin/patch_app.rb` (same script, no per-version forks).
- Consumes: everything above.

- [ ] **Step 1: State the acceptance (fails first)**

Run: `bin/matrix; echo "exit=$?"`
Expected: FAIL: rows for 7.2 and 8.0 say `FAILED TO RUN`, `exit=1`.

- [ ] **Step 2: Generate and patch the apps**

Run: `bin/new-app 7.2 && bin/new-app 8.0 && ruby shared/bin/patch_app.rb apps/rails-7_2 && ruby shared/bin/patch_app.rb apps/rails-8_0`
Add the two Compose services.

- [ ] **Step 3: Run the suite per version and fix version differences in `shared/` only**

Run: `bin/test 7.2` then `bin/test 8.0`.
Expected: `0 failures` on each. Differences found (asset helpers, `config.load_defaults`, Rack status handling, Cuprite) are fixed once in `shared/` in a way that works on all three; record each in a "Per-version notes" section of `README.md`. The `rails new` default files are not edited beyond what `patch_app.rb` does.

- [ ] **Step 4: Run the full matrix, with both sources**

Run: `bin/matrix; echo "exit=$?"`
Expected: three rows (`7.2.x`, `8.0.x`, `8.1.x`), each `PASS`, `exit=0`.
Run: `PERMITTABLE_SOURCE=rubygems PERMITTABLE_VERSION=0.13.1 bin/matrix; echo "exit=$?"`
Expected: three `PASS` rows labelled `permittable 0.13.1 (rubygems, pinned)`, `exit=0`; then `git status --porcelain` is the same as before the rubygems run.
Run: `PERMITTABLE_SOURCE=rubygems PERMITTABLE_VERSION=0.12.0 bin/matrix; echo "exit=$?"`
Expected: either `PASS` or red/failed rows with a clear cause; any `since:`-excluded cases are listed under "cases not applicable to permittable 0.12.0"; never a silent skip. Record what this shows in the hand-off.

- [ ] **Step 5: Smoke the browser side**

Run: `docker compose up -d` then for `p in 3072 3080 3081`: `curl -s localhost:$p/ | grep -o 'Rails [0-9.]*'` prints `Rails 7.2.x`, `Rails 8.0.x`, `Rails 8.1.x`; `curl -s localhost:$p/orders | grep -c ORD-SEED` is at least 6; `curl -s -o /dev/null -w '%{http_code}' localhost:$p/inspector/last` is `200`. Then `docker compose down`.

- [ ] **Step 6: Write `README.md`**

Sections: what the lab is; one-line usage (`docker compose up`, `bin/test [7.2|8.0|8.1] [rspec args]`, `bin/matrix`, `bin/coverage-report [--strict]`); env vars `PERMITTABLE_PATH`, `PERMITTABLE_SOURCE`, `PERMITTABLE_VERSION`; ports; how to add a spec (`covers:`, `# README:`, `since:` rules, flip the matrix row); the anti-goals; per-version notes; "Findings policy" (a red spec because the gem differs from the README is a finding, listed in the hand-off, never fixed by editing the expectation).

- [ ] **Step 7: Final check and commit**

Run: `ruby bin/coverage-report` (prints Plan 1 rows covered, remaining rows per plan) and `bin/matrix`.
Expected: summary shows 0 `chờ tác giả` rows, 6 `ngoài phạm vi` rows, the Plan 1 rows covered, and the rest of the non-Plan-1 rows `chưa phủ`; matrix `exit=0`.

```bash
git add apps compose.yml README.md
git commit -m "feat: rails 7.2 and 8.0 apps, full matrix, lab README"
```

---

## Next plans

Each follows this plan's conventions and flips its matrix rows as it goes.

- **02 Sửa đơn / đổi trạng thái / finalize:** `PATCH /orders/:id`; rows `pp-enforce-lazy`, `pp-last-rule-wins`, `use-optional`, `use-only-except`, `use-override-duplicate`, `opt-in-enum-hash` (status), `finalize-basic`, `finalize-violate`, `msg-violate-keyword`, `finalize-bare-runner`, `opt-default-as-authored-with-transform`, `absent-optional-omitted` (PATCH), `unknown-exempt-path-params`, `absent-blank-array-only-result` (after the author answers).
- **03 Webhook API, problem+json, Metal:** `POST /api/carriers/:carrier/tracking_events` (`ActionController::API`, `TrackingEvent` model), `GET /track/:code` (Metal), error-format and mode toggles; rows `kind-json`, `opt-max-depth`, `type-float`, `type-boolean`, `opt-in-live-include`, `opt-validate-falsy`, `opt-validate-symbol-code`, `opt-transform`, `opt-virtual`, `unknown-wrapper-key`, `problem-*`, `cfg-error-format`, `cfg-problem-base-uri`, `err-envelope-json`, `err-code-invalid`, `err-code-custom-symbol`, `msg-string`, `msg-hash`.
- **04 Engines: Shipping (in-app) and CarrierGateway (gem):** `shared/engines/shipping`, `gems/carrier_gateway`; rows `cfg-audit-ignore-outside-root`, `rake-audit-engines`, `rake-audit-outside-root`, `rake-openapi-engines`, `rake-audit-metal`, `rake-openapi-metal`, plus the 0.13.0 changelog rows.
- **05 CSV Contract, legacy endpoint, monitor, generator input:** `Permittable::Contract` import form, legacy controller with `params.require.permit`, monitor mode and `PERMITTABLE_MODE`; rows `contract-call`, `contract-call-bang`, `contract-json-schema`, `contract-always-enforces`, `contract-no-router-exemption`, `contract-no-memo`, `contract-input-errors`, `contract-unknown-log`, `monitor-*`, `unknown-log`, `unknown-ignore`, `pp-mode-monitor`, `rake-generate-expect-permit`, and (pending the author's answer on where exemptions are tested) `unknown-exempt-csrf`, `unknown-exempt-csrf-renamed`, `unknown-exempt-form-keys`, `unknown-exempt-commit`, `unknown-exempt-button`, `unknown-exempt-image-submit`, `unknown-exempt-router-keys`, which need a rootless HTML form such as the CSV import upload.
- **06 Rake tasks, drift guard, logging, non-controller features:** adds a PostgreSQL array column migration (for example `orders.tags`, `string array: true`) so `drift-pg-array-column` and `rake-generate-pg-array` can be tested; rake audit/openapi/generate specs on the real app, drift-guard subprocess specs, `check_column_types`, log and SQL bind redaction, `Audit.entries`, `Generator`, registry swap, `ConcernsOnRails` alias, config setters, class-load errors, remaining `event-*`, `err-rescue-from-order`, `err-details-complete-message-bounded`; rows `rake-*`, `drift-*`, `log-*`, `audit-entries-plain`, `generator-draft-plain`, `registry-swap`, `alias-concerns-on-rails`, `cfg-*`, `classload-*`.
