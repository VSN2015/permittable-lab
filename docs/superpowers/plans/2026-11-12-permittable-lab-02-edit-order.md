# permittable-lab Plan 2: Sửa đơn / đổi trạng thái (lazy contracts, field groups, finalize)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two lazy-contract flows on `OrdersController`, `PATCH /orders/:id` (edit fields) and `PATCH /orders/:id/status` (change status, a rootless contract), with request specs, gem-matcher specs and headless system specs on the real forms, so that the 17 matrix rows with `plan: 2` are covered by examples that fail when the gem is wrong; plus the housekeeping Plan 1 deferred and the 0.14.0 / 0.15.0 CHANGELOG rows.

**Architecture:** The create contract is refactored, with no behaviour change, to `use` two new field groups (`OrderScheduleFields`, `OrderExtrasFields`). The edit contract reuses them with `optional: true` (root `order`, `model: Order`). The status contract is rootless: it `use`s a standalone `StatusChange` contract, adds the `locale` query key, and runs a `finalize` with `violate!`. Edit and status actions are lazy (no `enforce:`): closed orders are refused by a guard that never reads params, and an audit-trail hook reads `permitted_params` and swallows a rejection so the action reads it a second time. Class-load rules (`use` options, `finalize` refusal, duplicates, last-rule-wins, bare runner) are specified on anonymous controllers, because only a class body can show them.

**Tech Stack:** as Plan 1 (Ruby 3.3, Rails 7.2/8.0/8.1, PostgreSQL 16, RSpec, Capybara + Cuprite, Docker Compose). Gem under test: `~/Projects/individual-projects/permittable`, **0.15.0** at planning time (see Planner decisions: it was 0.14.0 when this plan was commissioned).

**Spec:** `docs/superpowers/specs/2026-11-05-permittable-lab-design.md` (section 6 row "Sửa đơn / đổi trạng thái" is this plan's subject; section 2 lists the anti-goals). Plan 1 (`docs/superpowers/plans/2026-11-05-permittable-lab-01-foundation.md`) is done; its conventions apply.

## Global Constraints

- Rails versions **7.2, 8.0, 8.1**; every new spec runs unchanged on all three through `bin/matrix`. No per-version forks of shared code, no version guard hiding a red case.
- **README of the gem is the truth.** Gem differs from README: the spec stays red and goes in README "Findings". No `pending`, `skip`, `focus`, `if:`/`unless:` example metadata, `Rails.version`, `filter_run*` in specs (`Lab::Hygiene` enforces it; do not write the banned words even in comments).
- A spec must go through what it claims. System specs fill and submit the real rendered form; never a hand-built payload, `fetch`, `.submit(` or `driver.post`.
- Where the README is ambiguous: no guess. Record a matrix row `chờ tác giả` with the question.
- Every spec file starts with a `# README: <section>` comment and declares `covers: %w[row-id ...]` on its describe block. A spec file never contains the text `covers:` inside a string or comment other than as that metadata (the matrix scanner reads source text); build such strings as `"cov" + "ers"`.
- `since:` tags are gem versions only, never used to skip a red case. Plan 1's baseline for orders specs is `since: "0.12.0"`; use a newer tag only where the behaviour arrived later (0.14.0, 0.15.0).
- Matrix `status` values: a spec path, `chưa phủ`, `chờ tác giả`, `ngoài phạm vi`. A row is flipped by the task that writes its spec; `also:` lists extra spec paths and each must contain `covers:` for that row id.
- Status codes are integers (`render :edit, status: status`). Inspector stays observation-only: no spec or code of this plan may make it call `permitted_params`.
- Shared code lives in `shared/` (bind-mounted, inside `Rails.root`). Run specs with `bin/test 8.1 <path>` (migrations run automatically); the last task runs `bin/matrix`.
- Out of scope for this plan: webhook/JSON API, Metal, engines, CSV import, rake tasks, drift-guard subprocess specs, problem+json (Plans 3 to 6).

## Review Focus

Inputs the spec implies but no row example names, most likely first. Each has a test in the owning task.

1. **Unknown id** on `GET /orders/:id/edit`, `PATCH /orders/:id`, `PATCH /orders/:id/status`: 404, never 500, no `invalid_parameters.permittable` event. Tests in Tasks 5 and 6.
2. **Missing or malformed `order` root** on PATCH (`{}`, `order=bob`): 400 and the edit form re-rendered (not the new-order form), never 500, though a guard reads the params first. Test in Task 5.
3. **Closed orders (delivered, cancelled) are terminal**: a valid PATCH or status change on one changes nothing and says so; an invalid one is not validated at all (lazy). Tests in Tasks 5 and 6.
4. **Hostile status input**: `status[]=shipped`, missing `status`, `status=lost`, `cancel_reason` as a Hash *value* (`"1"`) instead of a key, `cancel_reason` sent with a non-cancelled status, `remind_after=99999` or `-5`: each a 422 with the right code, order untouched, never 500. Test in Task 6.
5. **`?locale=` on the rootless status route**, where `locale` is a real top-level key: `locale=xx` is processed in Vietnamese (303), `locale[]=vi` is a 422 `invalid_type` on `locale` rendered in Vietnamese, never a 500. Test in Task 6.

## Planner decisions

These fill gaps the spec or the brief left open. Questions for the author are in the hand-off message.

- **The gem checkout changed during planning.** The brief said 0.14.0; `lib/permittable/version.rb`, `CHANGELOG.md` and the tag now say **0.15.0** (released 2026-11-12). Expected values below come from the README of gem branch `docs/readme-changelog-gaps` (commit a9dfdf6: master 0.15.0 plus README sentences for the verified CHANGELOG gaps; research brief `docs/agent-work/research/2026-11-12-changelog-readme-gaps.md`). Task 2 adds rows for both the 0.14.0 and the 0.15.0 CHANGELOG sections. The author decided that CHANGELOG claims are tested once the README states them.
- **Where the rootless contract lives:** a separate "change status" form on the order page, `PATCH /orders/:id/status` (`patch "orders/:id/status", to: "orders#change_status", as: :order_status`). The action is `change_status`, not `status`, because `ActionController::Metal#status` is the response status and must not be overridden. `PATCH /orders/:id` stays a `root: :order` contract (there `id` is outside the root and nothing exempts or flags it, so `unknown-exempt-path-params` could never fail there).
- **Status is not editable through `PATCH /orders/:id`.** `order[status]`, `order[cancel_reason]`, `order[code]`, `order[id]`, `order[customer]` are undeclared and give 422 `unknown` (mass-assignment guard, as Plan 1 did for create).
- **Cross-field rule** (needs only submitted fields, so `finalize` can see it): a cancelled order needs a cancel reason, and a cancel reason is only valid on a cancelled order. Rules that need DB state (closed orders) live in a guard, not in `finalize`, because `finalize` runs on a bare runner.
- **Discriminating enum for `opt-in-enum-hash`:** `Order.statuses` maps strings to the same strings, so a gem reading values instead of keys would pass. A new integer-backed enum `Order.cancel_reasons` (`changed_mind: 0, wrong_address: 1, out_of_stock: 2, other: 3`, column `orders.cancel_reason integer`, `prefix: :cancelled_for`) is used with `in: Order.cancel_reasons`; a request sending the Hash *value* `"1"` must be refused.
- **Field with `transform:` and `default:`** (`opt-default-as-authored-with-transform`): `remind_after` (customer reminder lead time), form input in minutes, stored in seconds: `optional :remind_after, :string, format: /\A\d{1,4}\z/, transform: ->(minutes) { minutes.to_i * 60 }, default: 1800`. The default is written in the final shape (Integer seconds). A gem that casts the default gives `"1800"`, a gem that transforms it gives `108000`; both fail the example. Column `orders.remind_after integer`. If this contract fails to load because the gem rejects the default, that is the finding: stop and report, do not drop `format:`.
- **Two reads for `event-once-per-request`:** `record_attempted_fields` (before_action, update only) reads `permitted_params` to list the fields a request tries to change for the flash notice, and on an invalid payload swallows `Permittable::InvalidParameters` so that `update` reports it. The spec counts the reads (at least 2) before asserting one event.
- **`pp-last-rule-wins` in the real flow:** `OrdersController` declares a catch-all first (`permit_params(unknown: :error) { optional :locale, :string }`), then `:create`, `:update`, `:change_status`. A gem that picked the first match would answer every update with 422 `unknown order`. Both orders are pinned on anonymous classes in Task 4.
- **`finalize-bare-runner` and the class-load rows are tested on anonymous `Class.new(BaseController)` classes with the gem's matchers**, because only a `finalize` block that probes `self`, or a class body that raises, can show them; the real contracts carry no test probes. If `accept_params(...).returning(...)` does not run `finalize`, that contradicts README "Testing contracts" ("`returning` asserts the cast, defaulted, transformed output"): stop and report it as a finding or an author question.
- **`locale` on the rootless contract** is declared (`optional :locale, :string`) because the app adds `?locale=` to every URL and `unknown: :error` flags it; `finalize` drops it (`p.except(:locale)`), README "drop scaffolding keys". No `model:` on the status contract (`locale` is not a column; `virtual:` belongs to Plan 3).
- **Exempt keys move to Plan 2.** The status form is a real rootless HTML form under `unknown: :error`, so `unknown-exempt-form-keys` (`_method`, `utf8`), `unknown-exempt-csrf` (`authenticity_token`), `unknown-exempt-commit` and `unknown-exempt-button` become `plan: 2` rows (Task 2). The form carries both a `submit_tag` (`commit`) and a `button_tag` (`button`), as Plan 1's create form does. Each key is tested alone against an undeclared non-exempt key (`not_exempt`) in the same request: the exempt key is accepted, the control is rejected as `unknown` and is the only violation. Without that control the examples could not fail. `unknown-exempt-csrf-renamed`, `unknown-exempt-image-submit` and `unknown-exempt-router-keys` stay Plan 5.
- **Blank default on a nullable field** (`cl-0_14_0-9`, README "Explicit nulls" now states it): tested on anonymous controllers with matchers in Task 7. A `:json` field with `transform:` and a blank default stays undocumented: not tested, and `cl-0_15_0-5` (nullable `:json` blank default) stays `chưa phủ`, plan 3.
- **CHANGELOG wording the code does not match** (author's notes, not tests, the README is correct on both): 0.12.0 #123 says a `:json` default reaches the action "frozen" (the stored default is frozen, the action's copy is not); 0.15.0 #176 says the Metal audit applies to a rule whose effective mode is "enforce or monitor" (the note text and scope differ). Task 9 records both in the lab README.
- **Anchor rows touched by 0.14.0/0.15.0** (`type-date`, `type-datetime`, `matcher-accept-reject`) get the version in their `changelog:` list and an `also:` path, in the task that writes the covering example (Tasks 5 and 7), per Plan 1 Task 6 rule (b). New rows are only for behaviour no anchor holds.
- Closed order = `delivered` or `cancelled`. The edit form's year range for `date_select :delivery_on` must include the order's own year (the new-order form's range would drop an order dated 2030 and silently send a blank date, which reads as absent).
- vi and en copy added by this plan is listed in Task 5 and Task 6 ("Copy"); every key exists in both locales.

## Row coverage: how each example fails

Every example below is written to go red if the gem gets the row wrong. "Spec" is the primary file; (also) files are listed in the matrix `also:`.

| Row | Example (spec) | Fails when the gem |
|---|---|---|
| pp-enforce-lazy | Invalid payload to a closed order gives 303 and zero events, same payload to an open order gives 422 and one event (orders_update_spec) | validates before the action reads params (an `enforce`-style before_action would 422 the closed order first) |
| pp-last-rule-wins | Valid PATCH under a first-declared catch-all with `unknown: :error` succeeds (orders_update_spec); catch-all declared after a specific rule wins, declared before loses (use_dsl_spec, primary) | takes the first match or merges rules |
| opt-in-enum-hash | `cancel_reason` accepts each key of `Order.cancel_reasons`, refuses the Hash value `"1"` and `"lost"` as status (orders_status_spec; matcher `within` in orders_edit_contract_spec) | cannot take a Hash, or reads values instead of keys |
| opt-default-as-authored-with-transform | Omitted `remind_after` is Integer `1800` in `permitted` and in the DB; sent `"45"` gives `2700` (orders_status_spec; `returning` in matcher spec) | casts the default (`"1800"`), transforms it (`108000`), or skips the transform on a sent value |
| absent-optional-omitted | PATCH `{note}` on an express order leaves priority, delivery date, coupon untouched and `permitted` is exactly `{"note"=>...}`; `coupon_code: ""` leaves the coupon, `note: ""` clears it (orders_update_spec) | fills absent optionals or nils columns |
| msg-violate-keyword | `cancel_reason` violation text equals the literal copy in vi and in en (orders_status_spec) | ignores `message:` (the page would show the code) |
| unknown-exempt-path-params | Status change under `unknown: :error` succeeds while `id` is a param; `bogus=1` gives exactly one violation, `bogus`, never `id` (orders_status_spec); matcher blindness to `id` (orders_edit_contract_spec) | flags `id` as unknown |
| unknown-exempt-form-keys | The status change is accepted with `_method=patch` and, separately, with `utf8=✓`, while `not_exempt=1` in the same request gives exactly one violation, `not_exempt` (orders_status_spec; the real form posts `_method` in orders_edit_spec) | flags `_method` or `utf8` |
| unknown-exempt-csrf | Accepted with `authenticity_token=x` (request); the real token posted by the browser form with forgery protection on (system) | flags the token |
| unknown-exempt-commit | Accepted with `commit=...` (request); the real `submit_tag` click (system) | flags `commit` |
| unknown-exempt-button | Accepted with `button=` (request); the real `button_tag` click (system) | flags `button` |
| cl-0_14_0-9 | Anonymous controllers: omitted nullable `note` with `default: ""` is `nil`; `"   "` with `normalize: :strip` is `nil`; `in:`, `format:` and `:integer` fields with a nullable blank default load and give `nil`; a non-nullable `default: ""` stays `""`; a nullable field with `transform:` keeps `""` as authored; `permit_param(:note).with_default("")` passes (orders_edit_contract_spec) | keeps `""`, nils the transform field's default, or changes a non-nullable blank default |
| use-compose | One PATCH changes fields from both groups and the nested address; each group's own bounds reject (orders_update_spec) | drops or half-applies a group |
| use-optional | PATCH without `delivery_on`/`priority` succeeds, `permitted` has no `priority` (default dropped); bounds stay (`priority=bogus` is 422 inclusion); sent address with one key is 422 missing the other two (orders_update_spec) | keeps required or default, or relaxes nested sub-fields |
| use-only-except | `only:` and `except:` declare the right subset (`permit_param` and negated); a typo in `only:` raises naming the field (use_dsl_spec) | ignores the selector or silently drops a typo |
| use-contract | Every status field and rule works through `use StatusChange`; the controller declares them (`permit_param`) and a standalone call agrees (orders_status_spec, orders_edit_contract_spec) | does not splice a Contract's fields |
| use-refuses-finalize | `use` of a Contract with `finalize` raises naming `finalize`, at top level, nested and with `only:`; a Contract without one loads (use_dsl_spec) | silently drops the finalize |
| use-override-duplicate | `use G` then `required :city` raises naming `city`; `use G, except: %i[city]` then own `city` loads and its own stricter `length:` rejects (use_dsl_spec) | allows a duplicate, or keeps the group's field over the own one |
| finalize-basic | `locale` sent, absent from `permitted` (finalize's return value is the result); with another violation present, finalize is not run (orders_status_spec) | ignores the returned hash, or runs finalize despite violations |
| finalize-violate | Cancelled without reason is 422 `cancel_reason`/`required_when_cancelled`; reason on a non-cancelled status is 422 `only_when_cancelled`; code after `violate!` never runs (orders_status_spec; use_dsl_spec for the halt) | does not raise, or continues after `violate!` |
| finalize-bare-runner | A finalize block that probes `self` sees a non-controller with no `params` (use_dsl_spec) | runs the block on the controller |
| event-once-per-request | Invalid PATCH whose `permitted_params` is read at least twice yields exactly one event with controller `orders`, action `update`, mode `:enforce` (orders_update_spec) | re-instruments on each read |

Anchor rows extended: `type-date`, `type-datetime` (0.14.0, 0.15.0): README string cases through `PATCH order[delivery_on]` / `order[pickup_at]`; `matcher-accept-reject` (0.14.0 deep munge, 0.15.0 Symbol values): matcher examples plus a JSON request with a `nil` array element.

## File Structure

```
shared/lib/lab/boot.rb                          Task 1: app/*/concerns roots
shared/lib/lab/coverage_matrix.rb               Task 1: covers: ignores comments
shared/spec/lab/{boot_spec,coverage_matrix_spec}.rb   Task 1 (+ Task 2 anchors)
docs/coverage-matrix.yml                        Tasks 2, 4-8: 0.14.0/0.15.0 rows, flips
shared/db/migrate/20260101000004_add_cancel_reason_and_remind_after_to_orders.rb   Task 3
shared/app/models/order.rb                      Task 3: enum cancel_reason, closed?
shared/app/field_groups/{order_schedule_fields,order_extras_fields}.rb   Task 3
shared/app/contracts/status_change.rb           Task 3 (new dir, autoloaded)
shared/app/controllers/orders_controller.rb     Tasks 3, 5, 6
shared/config/routes.rb                         Tasks 5, 6
shared/app/views/orders/{edit,show}.html.erb, shared/app/views/layouts/lab.html.erb   Tasks 5, 6
shared/config/locales/{vi,en}.yml, shared/db/seeds.rb   Tasks 3, 5, 6
shared/spec/support/order_payloads.rb           Task 5: create_order
shared/spec/{models/order_spec.rb,contracts/status_change_spec.rb}   Task 3
shared/spec/controllers/{use_dsl_spec,orders_edit_contract_spec}.rb  Tasks 4, 7
shared/spec/requests/{orders_update_spec,orders_status_spec}.rb      Tasks 5, 6
shared/spec/system/orders_edit_spec.rb          Task 8
README.md                                       Task 9
```

---

### Task 1: Lab housekeeping deferred from Plan 1

**Files:**
- Modify: `shared/lib/lab/boot.rb`, `shared/lib/lab/coverage_matrix.rb`, `shared/spec/lab/coverage_matrix_spec.rb`
- Create: `shared/spec/lab/boot_spec.rb`

**Interfaces:**
- Produces: `Lab::Boot.configure(config, root:)` additionally registers every existing `shared/app/*/concerns` directory (not under `views`) in `config.autoload_paths` and `config.eager_load_paths`. `Lab::CoverageMatrix.covers_in(source)` ignores `covers:` text inside comments (`#` line or trailing comments, `=begin/=end`). `coverage_matrix_spec.rb` defines no top-level constants.
- Consumes: nothing.

- [ ] **Step 1: Write the failing specs**

`shared/spec/lab/boot_spec.rb` (`# README: Compatibility`): build `cfg` as an `OpenStruct` with `autoload_paths`, `eager_load_paths`, `autoload_once_paths` as `[]`, `paths` as `Hash.new { |h, k| h[k] = [] }`, `i18n` and `active_record` as `OpenStruct`. In a `Dir.mktmpdir` root create `shared/app/controllers/concerns`, `shared/app/models/concerns`, `shared/app/views/orders`, `shared/app/inspector`. Examples:
  - `"registers app/*/concerns as roots beside their parent"`: after `Lab::Boot.configure(cfg, root: root)`, both `autoload_paths` and `eager_load_paths` include `"#{root}/shared/app/controllers/concerns"`, `".../models/concerns"` and their parents `".../controllers"`, `".../models"`.
  - `"registers no concerns root that does not exist"`: a root with only `shared/app/controllers` yields no path ending in `/concerns`.
  - `"keeps views out of the autoload paths"`: no path ends in `/views`, even with `shared/app/views/concerns` present.

In `coverage_matrix_spec.rb` add (build the metadata word as `kw = "cov" + "ers"` so this file does not declare phantom ids):
  - `"covers_in ignores comments"`: source with a `# #{kw}: %w[ghost]` line, a real `RSpec.describe 'x', #{kw}: %w[real] do ... end # #{kw}: %w[tail]` line, and an `=begin ... #{kw}: %w[block] ... =end` block; `expect(Lab::CoverageMatrix.covers_in(src)).to eq %w[real]`.
  - `"covers_in still reads %w[] and quoted arrays"` for `%w[a b]`, `%i[a b]`, `["a", "b"]`: each gives `%w[a b]`.
  - `"defines no top-level constants"`: `%i[ROOT UNCOVERED AWAITING OUT ANCHOR_IDS].select { |c| Object.const_defined?(c, false) }` is `[]`.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/boot_spec.rb shared/spec/lab/coverage_matrix_spec.rb`
Expected: FAIL (concerns not registered; `ghost`/`tail`/`block` returned; the five constants leaked).

- [ ] **Step 3: Implement**

  - `boot.rb`: after the `app/*` loop, `Dir[shared.join("app/*/concerns")]` (skip a parent named `views`) appended to both path lists.
  - `coverage_matrix.rb` `covers_in(source)`: remove comments before scanning, using `Ripper.lex` (stdlib, Ruby 2.7 compatible, `require "ripper"`): drop tokens of type `:on_comment` and `:on_embdoc*`, join the rest, then apply the existing `COVERS` scan. A comment whose `#` sits inside a string is not a comment token, so strings keep working.
  - `coverage_matrix_spec.rb`: delete `ROOT`, `UNCOVERED`, `AWAITING`, `OUT`, `ANCHOR_IDS` constants; use `let(:root)` (`File.expand_path("../../..", __dir__)`), `Lab::CoverageMatrix::UNCOVERED`/`AWAITING`/`OUT_OF_SCOPE` directly, and `let(:anchor_ids) { %w[...] }` with the same list; update every reference.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/lab && ruby bin/coverage-report`
Expected: 0 failures; coverage report exit 0, no `problems` block.

- [ ] **Step 5: Commit**

```bash
git add shared/lib/lab/boot.rb shared/lib/lab/coverage_matrix.rb shared/spec/lab/boot_spec.rb shared/spec/lab/coverage_matrix_spec.rb
git commit -m "chore: register app/*/concerns roots, ignore comments in covers:, no top-level constants in matrix spec"
```

---

### Task 2: Matrix rows for CHANGELOG 0.14.0 and 0.15.0

**Files:**
- Modify: `docs/coverage-matrix.yml`, `shared/spec/lab/coverage_matrix_spec.rb`

**Interfaces:**
- Produces: 13 new rows (area `changelog`, `changelog: ["<version>"]`, status `chưa phủ`), and four existing rows move from `plan: 5` to `plan: 2`: `unknown-exempt-form-keys`, `unknown-exempt-csrf`, `unknown-exempt-commit`, `unknown-exempt-button`. Id rule from Plan 1 Task 6: `cl-<version with underscores>-<n>`, `n` = the bullet's position in that CHANGELOG section (Added bullets first, then Changed); a bullet that is already an anchor row's behaviour gets no new row (Tasks 5 and 7 add the version to that anchor). Total rows 269 to 282.

| id | feature | readme | since | plan | status |
|---|---|---|---|---|---|
| cl-0_14_0-1 | `:file` field type and `of: :file` accept uploads, refuse a String | The field DSL | 0.14.0 | 5 | chưa phủ |
| cl-0_14_0-2 | an operation with a `:file` field is exported as `multipart/form-data` | Exporting OpenAPI (docs that cannot drift) | 0.14.0 | 6 | chưa phủ |
| cl-0_14_0-3 | `OpenAPI.rails_routes` descriptors carry an optional `defaults:` key | Exporting OpenAPI (docs that cannot drift) | 0.14.0 | 6 | chưa phủ |
| cl-0_14_0-7 | a bare Metal controller enforces its rules whichever include order, or raises at class load | How a request flows | 0.14.0 | 3 | chưa phủ |
| cl-0_14_0-8 | a name the route fills from `defaults:` leaves the OpenAPI request body | Unknown parameters | 0.14.0 | 6 | chưa phủ |
| cl-0_14_0-9 | a blank default on a nullable field reads as `nil`; a field with `transform:` keeps its default as authored | Explicit nulls (nullable:) | 0.14.0 | 2 | chưa phủ |
| cl-0_15_0-1 | the audit lists controllers a route names that nothing has loaded | Auditing coverage (permittable:audit) | 0.15.0 | 6 | chưa phủ |
| cl-0_15_0-2 | matchers print hashes with sensitive values redacted and name `differs at:` paths | Testing contracts (RSpec matchers) | 0.15.0 | 6 | chưa phủ |
| cl-0_15_0-4 | an authored `:json` default the export cannot carry fails at class load; a `:date` `in:` member is published as `YYYY-MM-DD` | Exporting OpenAPI (docs that cannot drift) | 0.15.0 | 6 | chưa phủ |
| cl-0_15_0-5 | a blank default on a nullable `:json` field reads as `nil` | Explicit nulls (nullable:) | 0.15.0 | 3 | chưa phủ |
| cl-0_15_0-7 | a bare Metal rule that cannot run is audited as uncovered | Auditing coverage (permittable:audit) | 0.15.0 | 4 | chưa phủ |
| cl-0_15_0-8 | the exported body of a rootless `unknown: :error` contract lists Rails' form keys | Exporting OpenAPI (docs that cannot drift) | 0.15.0 | 6 | chưa phủ |
| cl-0_15_0-9 | `alias_attribute` and `store_accessor` fields are checked against the column behind them | The schema-drift guard | 0.15.0 | 6 | chưa phủ |

No row is `chờ tác giả` after the README additions; the `:json` plus `transform:` blank default is undocumented and gets no row.

- [ ] **Step 1: Write the failing spec**

In `coverage_matrix_spec.rb`, context "with the real matrix": `it "has the 0.14.0 and 0.15.0 rows with their owning plan"` holding a literal Hash id to plan for the 13 ids above (plans 2, 3, 4, 5, 6 as in the table) and asserting `rows.find { |r| r["id"] == id }` exists, `r["plan"] == plan`, `r["changelog"] == [version]` and `r["since"] == version`. A second example asserts the four exemption rows have `plan` 2. Add the 13 ids to the anchor list (`anchor_ids`).

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb`
Expected: FAIL (rows missing).

- [ ] **Step 3: Add the 13 rows** to the end of `docs/coverage-matrix.yml`, same key layout as the `cl-0_13_1-*` rows (`question`/`reason` null, `also: []`), and set `plan: 2` on the four exemption rows.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/lab/coverage_matrix_spec.rb && ruby bin/coverage-report`
Expected: 0 failures; report `total 282`, `awaiting_author 0`, no `problems`.

- [ ] **Step 5: Commit**

```bash
git add docs/coverage-matrix.yml shared/spec/lab/coverage_matrix_spec.rb
git commit -m "docs: matrix rows for CHANGELOG 0.14.0 and 0.15.0; exemption rows move to plan 2"
```

---

### Task 3: Schema, model, field groups, `StatusChange`; create uses the groups

**Files:**
- Create: `shared/db/migrate/20260101000004_add_cancel_reason_and_remind_after_to_orders.rb`, `shared/app/field_groups/order_schedule_fields.rb`, `shared/app/field_groups/order_extras_fields.rb`, `shared/app/contracts/status_change.rb`, `shared/spec/contracts/status_change_spec.rb`
- Modify: `shared/app/models/order.rb`, `shared/app/controllers/orders_controller.rb` (create contract only), `shared/db/seeds.rb`, `shared/spec/models/order_spec.rb`

**Interfaces:**
- Produces:
  - Migration: `add_column :orders, :cancel_reason, :integer` and `add_column :orders, :remind_after, :integer` (both nullable), `ActiveRecord::Migration[7.2]`.
  - `Order`: `enum :cancel_reason, { changed_mind: 0, wrong_address: 1, out_of_stock: 2, other: 3 }, prefix: :cancelled_for`; `Order.cancel_reasons` (HashWithIndifferentAccess); `Order#closed? -> Boolean` (`delivered? || cancelled?`).
  - `OrderScheduleFields = Permittable.fields do required :delivery_on, :date; optional :pickup_at, :datetime; optional :delivery_slot, :datetime; optional :priority, :string, in: Order::PRIORITIES, default: "standard" end`.
  - `OrderExtrasFields = Permittable.fields do optional :coupon_code, :string, format: /\A[A-Z]{3}\d{3}\z/; optional :note, :string, length: 1..200, normalize: :squish, nullable: true; array :services, of: :string, length: 0..3 end`.
  - `StatusChange = Permittable::Contract.define do required :status, :string, in: Order.statuses; optional :cancel_reason, :string, normalize: :squish, in: Order.cancel_reasons; optional :remind_after, :string, format: /\A\d{1,4}\z/, transform: ->(minutes) { minutes.to_i * 60 }, default: 1800 end` (no `finalize`, no `root:`).
  - `OrdersController` create contract: same fields in the same order, now `customer`, `shipping_address`, `use OrderScheduleFields`, `use OrderExtrasFields`, `items_attributes`.
- Consumes: `ShippingAddressFields`, `Order::PRIORITIES` (Plan 1).

- [ ] **Step 1: Write the failing specs**

`order_spec.rb` additions (`# README: Field options (in: takes a Hash)`): `"maps cancel reasons to integers"`: `Order.cancel_reasons` eq `{"changed_mind"=>0,"wrong_address"=>1,"out_of_stock"=>2,"other"=>3}` and `.keys` not eq `.values`; `"closed? is true for delivered and cancelled only"` over the five statuses; `"stores a cancel reason by key"`: `update!(status: "cancelled", cancel_reason: "wrong_address")`, `read_attribute_before_type_cast("cancel_reason")` eq `1`.

`contracts/status_change_spec.rb` (`# README: Standalone contracts (no controller)`), using `StatusChange.call(hash)`: valid `{"status"=>"shipped"}` has `params` eq `{"status"=>"shipped","remind_after"=>1800}` (Integer, as authored); `"remind_after"=>"45"` gives `2700`; `{"status"=>"lost"}` violations map to `[["status","inclusion"]]` (`[v[:param], v[:code].to_s]`); `"cancel_reason"=>"1"` is `[["cancel_reason","inclusion"]]` (Hash value refused, keys only); `"remind_after"=>"99999"` is `[["remind_after","format"]]`.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/models/order_spec.rb shared/spec/contracts/status_change_spec.rb`
Expected: FAIL (no column / no `StatusChange`).

- [ ] **Step 3: Implement**

Migration, model enum and `closed?`, the two groups, `StatusChange`, create contract refactor (move the existing fields verbatim into the groups). Seeds: give the cancelled seed order `cancel_reason = "changed_mind"` and the shipped one a `remind_after` of 1800 (one line each inside the existing `find_or_create_by!` block).

- [ ] **Step 4: Run to verify pass, including all of Plan 1**

Run: `bin/test 8.1`
Expected: 0 failures (the Plan 1 create, matcher and system specs prove the refactor changed no behaviour: violation order, defaults, `permit_param(:priority)...with_default("standard")`).

- [ ] **Step 5: Commit**

```bash
git add shared/db shared/app shared/spec docs
git commit -m "feat: cancel_reason enum, remind_after, order field groups and StatusChange contract"
```

---

### Task 4: Class-load and DSL rows on anonymous controllers

**Files:**
- Create: `shared/spec/controllers/use_dsl_spec.rb`
- Modify: `docs/coverage-matrix.yml`

**Interfaces:**
- Consumes: `OrderScheduleFields`, `ShippingAddressFields`, `BaseController`, `Permittable::Contract.define`, gem matchers (`require "permittable/rspec"`).
- Produces: nothing for later tasks except matrix flips: primary status for `use-only-except`, `use-override-duplicate`, `use-refuses-finalize`, `finalize-bare-runner`, `pp-last-rule-wins`, `finalize-violate`.

All classes are `Class.new(BaseController) { permit_params(...) { ... } }`. Class-load failures are asserted by message (`raise_error(/city/)`), as Plan 1's drift test does; every failing case has a loading control.

- [ ] **Step 1: Write the failing spec** (`# README: Reusing fields (Permittable.fields and use); Output reshaping (transform: and finalize); Declaring a contract`, `since: "0.12.0"`, `covers: %w[use-only-except use-override-duplicate use-refuses-finalize finalize-bare-runner pp-last-rule-wins finalize-violate]`)

  - `use only:`: `use OrderScheduleFields, only: %i[delivery_on priority]` gives `permit_param(:delivery_on)` and `permit_param(:priority)` for `:create`, and `not_to permit_param(:pickup_at).for_action(:create)`.
  - `use except:`: `except: %i[priority]` gives `not_to permit_param(:priority)` and `to permit_param(:delivery_on).required`.
  - `only:` typo: `use OrderScheduleFields, only: %i[colour]` raises `/colour/`; the same call with `only: %i[priority]` loads.
  - duplicate: `use ShippingAddressFields` followed by `required :city, :string` raises `/city/`; control: `use ShippingAddressFields, except: %i[city]` then `required :city, :string, length: 1..5` loads, accepts `{"line1"=>"1 Le Loi","city"=>"Hue","postcode"=>"700000"}` and rejects `"city"=>"Hanoi!"` with `.with_violation("city", :length)` (the group's own `1..80` would accept it).
  - refuses finalize: `with_finalize = Permittable::Contract.define { required :a; finalize { |p| p } }`; `use with_finalize` raises `/finalize/` at top level, inside `optional(:b) { use with_finalize }`, and with `only: %i[a]`; `without = Permittable::Contract.define { required :a }` loads.
  - bare runner: `finalize { |p| p.merge("on_controller" => is_a?(ActionController::Base), "has_params" => respond_to?(:params, true)) }`; `accept_params("a"=>"x").for_action(:show).returning("a"=>"x","on_controller"=>false,"has_params"=>false)`.
  - `violate!` halts: `finalize { |p| violate!("a", :boom); raise "ran after violate!" }`; `reject_params("a"=>"x").for_action(:show).with_violation("a", :boom)`.
  - last rule wins, both orders (see Planner decisions): rule `:create { required :a }` then catch-all `{ required :b }`: `accept_params("b"=>"1")` and `reject_params("a"=>"1").with_violation("b", :missing)` for `:create`; reverse declaration order: `accept_params("a"=>"1")` for `:create`, and `accept_params("b"=>"1")` for `:show` (the catch-all still serves other actions).

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/controllers/use_dsl_spec.rb`
Expected: PASS, because the spec exercises existing gem behaviour. A spec that has never been red proves nothing, so mutate it once: temporarily expect `"has_params"=>true` and confirm RED, then revert. Never commit the mutation.

- [ ] **Step 3: Flip the matrix**

Set `status: "shared/spec/controllers/use_dsl_spec.rb"` on the six rows above.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/controllers/use_dsl_spec.rb && ruby bin/coverage-report`
Expected: 0 failures; report `covered 60`, no `problems`.

- [ ] **Step 5: Commit**

```bash
git add shared/spec/controllers/use_dsl_spec.rb docs/coverage-matrix.yml
git commit -m "test: use, finalize and last-rule-wins on anonymous controllers; flip six rows"
```

---

### Task 5: Edit order (`GET /orders/:id/edit`, `PATCH /orders/:id`), lazy

**Files:**
- Modify: `shared/app/controllers/orders_controller.rb`, `shared/config/routes.rb`, `shared/app/views/orders/show.html.erb` (edit link, `@violations ||= []` render), `shared/app/views/layouts/lab.html.erb` (flash notice and alert), `shared/config/locales/vi.yml`, `shared/config/locales/en.yml`, `shared/spec/support/order_payloads.rb`, `docs/coverage-matrix.yml`
- Create: `shared/app/views/orders/edit.html.erb`, `shared/spec/requests/orders_update_spec.rb`

**Interfaces:**
- Produces:
  - Routes: `resources :orders, only: %i[index show new create edit update]`.
  - `OrdersController`: catch-all `permit_params(unknown: :error) { optional :locale, :string }` declared first; then the unchanged `:create`; then
    `permit_params :update, root: :order, model: Order, unknown: :error, desc: "Sửa đơn" do use OrderScheduleFields, optional: true; use OrderExtrasFields, optional: true; optional :shipping_address do use ShippingAddressFields end end`.
    Filters: `before_action :set_order, only: %i[show edit update change_status]` (`@order = Order.includes(:customer, :items).find(params[:id])`), `before_action :guard_closed_order, only: %i[edit update change_status]` (closed: `redirect_to order_path(@order), status: :see_other, alert: t("lab.orders.closed")`, never reads params), `before_action :record_attempted_fields, only: :update` (`@attempted = permitted_params.keys`, `rescue Permittable::InvalidParameters` sets `@attempted = []`). Actions: `edit` (`@violations = []`), `update` (`@order.update!(permitted_params.to_h)`, then `redirect_to order_path(@order), status: :see_other, notice: t("lab.orders.updated", fields: @attempted.join(", "))`). `render_error(message:, code:, status:, errors: [])` branches on `action_name`: `"update"` renders `:edit`, `"change_status"` renders `:show` (Task 6), otherwise the existing `:new` with `Order.new`.
  - `OrderPayloads.create_order(**attrs) -> Order`: `Order.build_from_contract(contract_output.merge(attrs.stringify_keys)).tap(&:save!)` (model-level setup, not through the gem; `attrs` may set `status:`, `priority:`, `note:`, `coupon_code:`, `services:`, `delivery_on:`).
  - Edit form: `form_with model: @order, url: order_path(@order), method: :patch`; inputs named like the new form's, minus `customer`: `order[delivery_on(1i..3i)]` (date_select, year range including the order's year), `order[priority]` (select), `order[coupon_code]`, `order[note]`, `order[services][]` checkboxes (checked from `@order.services`), `order[shipping_address][line1|city|postcode]` prefilled; no `pickup_at`/`delivery_slot` inputs. Same labels as the new form.
  - Copy (vi / en): `lab.orders.edit.heading` "Sửa đơn" / "Edit order"; `lab.orders.submit_edit` "Lưu thay đổi" / "Save changes"; `lab.orders.edit_link` "Sửa đơn" / "Edit order"; `lab.orders.updated` "Đã cập nhật: %{fields}" / "Updated: %{fields}"; `lab.orders.closed` "Đơn đã đóng, không thể thay đổi" / "This order is closed and cannot be changed". Flash renders as `<p id="flash-notice">` / `<p id="flash-alert">`.

- [ ] **Step 1: Write the failing request spec**

`orders_update_spec.rb`: `# README: How a request flows; Absence, defaults, and partial updates; Reusing fields; Instrumentation; Types and strict coercion`, `type: :request`, `since: "0.12.0"`, `covers: %w[pp-enforce-lazy pp-last-rule-wins use-compose use-optional absent-optional-omitted event-once-per-request type-date type-datetime matcher-accept-reject]`. `before { Inspector::Store.clear }`. Helpers: `patch_order(order, hash, locale: "vi")` = `patch order_path(order, locale: locale), params: { "order" => hash }`; `doc` as in Plan 1's spec; `violation(param, code)`; `events` collects `invalid_parameters.permittable` payloads with `ActiveSupport::Notifications.subscribed`.

Examples (all `since: "0.12.0"` unless stated):
  - `"renders the edit form prefilled"`: GET `edit_order_path(order, locale: "vi")` for `create_order(priority: "express", note: "keep", services: %w[gift_wrap], delivery_on: Date.new(2030,1,15))`: 200; hidden `_method` is `patch`; `order[note]` value `keep`; `order[priority]` selected `express`; the `gift_wrap` checkbox checked; `select[name="order[delivery_on(1i)]"] option[selected]` value `2030` (year outside the new-order range); address inputs hold `1 Le Loi`, `Ho Chi Minh`, `700000`; no `translation missing` in vi and en.
  - `"updates only what is sent"` [absent-optional-omitted, use-optional]: order with `priority: "express"`, coupon `"ABC123"`, note `"keep"`, `delivery_on` 2030-01-15; `patch_order(order, "note" => "new")` is 303 to `order_path`; reload: note `new`, priority `express`, coupon `ABC123`, `delivery_on` unchanged; `Inspector::Store.latest.permitted` eq `{"note"=>"new"}` (no `priority`: default dropped; no `delivery_on`: not required).
  - `"an empty optional never clears a column, an empty nullable one does"`: `"coupon_code"=>""` leaves `ABC123` and `permitted` has no `coupon_code`; `"note"=>""` makes `note` nil and `permitted` eq `{"note"=>nil}`.
  - `"keeps bounds and the address's own requirements"` [use-optional]: `"priority"=>"bogus"` is 422 with `violation("order.priority","inclusion")`; `"shipping_address"=>{"city"=>"Hue"}` is 422 with `order.shipping_address.line1` and `order.shipping_address.postcode` both `missing`; order unchanged.
  - `"composes the groups"` [use-compose]: one PATCH with `"priority"=>"express"`, `"coupon_code"=>"XYZ123"`, `"note"=>"  hi   there "`, `"services"=>["", "insurance"]`, full valid address: 303, all stored (`note` `hi there`, `services` `["insurance"]`). Then three rejections: `coupon_code "abc"` is `order.coupon_code`/`format`, four services is `order.services`/`length`, `postcode "1"` is `order.shipping_address.postcode`/`length`.
  - `"mass assignment is refused"`: each of `"status"`, `"cancel_reason"`, `"code"`, `"id"`, `"customer"=>{"name"=>"x"}` alone is 422 with `violation("order.<key>","unknown")` and the order is unchanged.
  - `"the last matching rule wins over a catch-all"` [pp-last-rule-wins]: a valid PATCH succeeds (303). A first-match gem would answer 422 `unknown` on `order`.
  - `"is lazy"` [pp-enforce-lazy], with a payload `{"coupon_code"=>"abc"}`: to a `delivered` order it is 303 to `order_path`, alert present (`#flash-alert`), zero events, `Inspector::Store.latest.rejected` is not `true` and `permitted` is nil; to a `pending` order it is 422 with exactly one event. A valid payload to the delivered order also changes nothing (Review Focus 3).
  - `"instruments a rejection once however often the params are read"` [event-once-per-request]: `reads = 0; allow_any_instance_of(OrdersController).to receive(:permitted_params).and_wrap_original { |m, *a| reads += 1; m.call(*a) }`; invalid payload `{"coupon_code"=>"abc"}` to a pending order; `expect(reads).to be >= 2`; the collected events size is 1, with `controller` `"orders"`, `action` `"update"`, `mode` `:enforce`, and a detail `param` `"order.coupon_code"` with `code.to_s` `"format"`; `Inspector::Store.latest.events.size` is 1; response 422.
  - `"bad root"` (Review Focus 2): `patch order_path(order, locale: "vi"), params: {}` is 400 and the response shows the edit form (`form input[name="_method"][value="patch"]`, not the new-order form); `params: { "order" => "bob" }` is 400, same page.
  - `"unknown id"` (Review Focus 1): `get edit_order_path(0)` and `patch order_path(0), params: { "order" => { "note" => "x" } }` are 404, zero events.
  - `"a nil array element sent as JSON is dropped by Rails before the contract"` [matcher-accept-reject, `since: "0.14.0"`]: `patch order_path(order, locale: "vi"), params: { order: { services: ["gift_wrap", nil] } }, as: :json` is 303 and `services` is `["gift_wrap"]` (the real request the Task 7 matcher examples claim to mirror).
  - `describe "dates, 0.14.0 rules", since: "0.14.0"` [type-date, type-datetime]. For `order[delivery_on]` (a `:date`), generated one example per literal: accepted `"2026-09-05"`, `"2026-09-05T00:00:00Z"`, `"2026-09-05+00:00"` (stored `Date.new(2026,9,5)`); refused as 422 `order.delivery_on`/`invalid_type`: `"2026-09-05T10:00:00Z"`, `"2026-09-05T00:00:00-05:00"`, `"2026-09-05 -05:00"`, `"2026-09-05 +05:00"`, `"Sep 5 2026 -05:00"`. For `order[pickup_at]` (a `:datetime`): `"2026-09-05 -05:00"` stores `Time.utc(2026,9,5,5,0,0)`; refused `invalid_type` on `order.pickup_at`: `"Sep 5 2026 -05:00"`, `"2026-09-05T"`. (README "Types and strict coercion", `:date` and `:datetime` rows.)
  - `describe "dates, 0.15.0 rules", since: "0.15.0"`: `order[pickup_at]` `"2026-09-05 EST"` stores `Time.utc(2026,9,5,5,0,0)`; refused `invalid_type`: `order[pickup_at]` `"2026-09-05 XYZ"` and `"2026-09-05 noon"`, and `order[delivery_on]` `"2026-09-05 EST"`.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/requests/orders_update_spec.rb`
Expected: FAIL (`No route matches` / `AbstractController::ActionNotFound`).

- [ ] **Step 3: Implement** routes, controller, views, locale keys, layout flash, `OrderPayloads.create_order` as in Interfaces. The update action never rescues the gem's error itself; `render_error` is reached through the gem.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/requests/orders_update_spec.rb && bin/test 8.1`
Expected: 0 failures (Plan 1 specs unaffected by the new catch-all rule).

- [ ] **Step 5: Flip the matrix**

`pp-enforce-lazy`, `use-compose`, `use-optional`, `absent-optional-omitted`, `event-once-per-request`: `status: "shared/spec/requests/orders_update_spec.rb"`. `pp-last-rule-wins`: add `also: [shared/spec/requests/orders_update_spec.rb]`. `type-date` and `type-datetime`: add `"0.14.0"` and `"0.15.0"` to `changelog:` and the spec to `also:`. `matcher-accept-reject`: add `"0.14.0"` to `changelog:` and the spec to `also:`.
Run: `ruby bin/coverage-report` (no `problems`).

- [ ] **Step 6: Commit**

```bash
git add shared docs
git commit -m "feat: edit order with lazy contract, field groups and request specs; flip five rows"
```

---

### Task 6: Change status (`PATCH /orders/:id/status`), rootless contract

**Files:**
- Modify: `shared/app/controllers/orders_controller.rb`, `shared/config/routes.rb`, `shared/app/views/orders/show.html.erb`, `shared/config/locales/vi.yml`, `shared/config/locales/en.yml`, `docs/coverage-matrix.yml`
- Create: `shared/spec/requests/orders_status_spec.rb`

**Interfaces:**
- Consumes: `StatusChange`, `set_order`, `guard_closed_order`, `render_error` (Tasks 3 and 5), `OrderPayloads.create_order`.
- Produces:
  - Route: `patch "orders/:id/status", to: "orders#change_status", as: :order_status` (helper `order_status_path(order)`).
  - Contract (declared after `:update`): `permit_params :change_status, unknown: :error, desc: "Đổi trạng thái" do use StatusChange; optional :locale, :string; finalize { |p| ... } end`. The finalize block: `cancelling = p[:status] == "cancelled"`; `violate!("cancel_reason", :required_when_cancelled, message: <required copy>)` when cancelling without a reason; `violate!("cancel_reason", :only_when_cancelled, message: <only copy>)` when not cancelling and a reason is present; returns `p.except(:locale)`. The message copy is read with `I18n.t` inside the block (global, per-request locale).
  - Action `change_status`: `@order.update!(permitted_params.to_h)`, `redirect_to order_path(@order), status: :see_other`.
  - Show page: below the totals, a status form `form_with url: order_status_path(@order), method: :patch` with rootless fields `status` (select, option labels from copy), `cancel_reason` (select, blank allowed), `remind_after` (text, minutes), a `submit_tag` (sends `commit`) and a `button_tag` (sends `button`); the page prints `<p id="cancel-reason">` and `<p id="remind-after">` when set; it renders `orders/violations` with `@violations ||= []`.
  - Copy (vi / en): `lab.orders.status_form.heading` "Đổi trạng thái" / "Change status"; `lab.orders.status_form.submit` "Cập nhật trạng thái" / "Update status"; `lab.orders.status_form.submit_button` "Cập nhật trạng thái (nút)" / "Update status (button)"; `lab.orders.statuses.{pending,confirmed,shipped,delivered,cancelled}` = "Chờ xử lý","Đã xác nhận","Đang giao","Đã giao","Đã huỷ" / "Pending","Confirmed","Shipped","Delivered","Cancelled"; `lab.orders.cancel_reasons.{changed_mind,wrong_address,out_of_stock,other}` = "Đổi ý","Sai địa chỉ","Hết hàng","Khác" / "Changed mind","Wrong address","Out of stock","Other"; `lab.orders.fields.cancel_reason` "Lý do huỷ" / "Cancel reason"; `lab.orders.fields.remind_after` "Nhắc khách sau (phút)" / "Remind customer after (minutes)"; show lines `lab.orders.cancel_reason_line` "Lý do huỷ: %{reason}" / "Cancel reason: %{reason}" and `lab.orders.remind_after_line` "Nhắc khách sau: %{seconds} giây" / "Remind customer after: %{seconds} seconds"; `lab.orders.errors.cancel_reason_required` "bắt buộc khi trạng thái là Đã huỷ" / "is required when the status is cancelled"; `lab.orders.errors.cancel_reason_only_when_cancelled` "chỉ dùng khi trạng thái là Đã huỷ" / "is only allowed when the status is cancelled".

- [ ] **Step 1: Write the failing request spec**

`orders_status_spec.rb`: `# README: Field options (in:, default:, transform:); Output reshaping (transform: and finalize); Custom error messages (message:); Unknown parameters (path parameters); Reusing fields`, `type: :request`, `since: "0.12.0"`, `covers: %w[opt-in-enum-hash opt-default-as-authored-with-transform finalize-basic finalize-violate msg-violate-keyword unknown-exempt-path-params use-contract unknown-exempt-form-keys unknown-exempt-csrf unknown-exempt-commit unknown-exempt-button]`. Helper `change(order, hash, locale: "vi")` = `patch order_status_path(order, locale: locale), params: hash`.

  - `"accepts a status change"` [use-contract, unknown-exempt-path-params, finalize-basic]: pending order, `change(order, {"status"=>"shipped"})` is 303; reload `status` `shipped`, `remind_after` `1800`; `Inspector::Store.latest.permitted` eq `{"status"=>"shipped","remind_after"=>1800}` (Integer 1800; no `locale`, though `request.query_parameters["locale"]` is `"vi"`). It succeeds under `unknown: :error` while `id` is a param.
  - `"tolerates the keys Rails adds to a form post"` [unknown-exempt-form-keys, unknown-exempt-csrf, unknown-exempt-commit, unknown-exempt-button], one generated example per pair `["_method","patch"]`, `["utf8","✓"]`, `["authenticity_token","x"]`, `["commit","Cập nhật trạng thái"]`, `["button",""]`: `change(order, {"status"=>"shipped", key=>value})` is 303, `permitted` has none of them, status applied. The control, `{"status"=>"shipped","not_exempt"=>"1", key=>value}`, is 422 and the page's violations are exactly `["not_exempt"]` (so `unknown: :error` was live and the exempt key was not counted).
  - `"only an undeclared key is unknown, never the path id"` [unknown-exempt-path-params]: `{"status"=>"shipped","bogus"=>"1"}` is 422; the violations (from the page's `li[data-param]` list) are exactly `["bogus"]`.
  - `"in: Order.statuses is read as its keys"` [opt-in-enum-hash]: for each of `pending confirmed shipped delivered` a fresh pending order accepts it (303); `"status"=>"lost"` is 422 `status`/`inclusion`; each key of `Order.cancel_reasons` is accepted with `"status"=>"cancelled"`; `"cancel_reason"=>"1"` (a Hash value) is 422 `cancel_reason`/`inclusion`.
  - `"remind_after: default as authored, transform on sent values"` [opt-default-as-authored-with-transform]: omitted gives `permitted["remind_after"]` `eql` `1800` and DB `1800`; `"remind_after"=>"45"` gives `2700`; `"99999"` and `"-5"` are 422 `remind_after`/`format` (Review Focus 4).
  - `"finalize is not run while a field is invalid"` [finalize-basic]: `{"status"=>"cancelled","remind_after"=>"abc"}` is 422 with exactly `[["remind_after","format"]]` (no `required_when_cancelled`).
  - `"cancelling needs a reason"` [finalize-violate, msg-violate-keyword]: `{"status"=>"cancelled"}` is 422, `violation("cancel_reason","required_when_cancelled")` text eq `bắt buộc khi trạng thái là Đã huỷ` in vi and `is required when the status is cancelled` with `locale: "en"`; order still `pending`. `{"status"=>"cancelled","cancel_reason"=>"wrong_address"}` is 303, status `cancelled`, `cancel_reason` `wrong_address`. `{"status"=>"shipped","cancel_reason"=>"other"}` is 422 `only_when_cancelled` with the copy `chỉ dùng khi trạng thái là Đã huỷ`.
  - `"closed orders are terminal"` (Review Focus 3): a `cancelled` order with a valid payload and with `{"status"=>"lost"}` is 303, alert present, status unchanged, zero events.
  - `"hostile input"` (Review Focus 4): `"status"=>["shipped"]` is 422 `status`/`invalid_type`; empty body is 422 `status`/`missing`; no 500 in any case.
  - `"locale on a rootless contract"` (Review Focus 5): `locale: "xx"` (path built with `?locale=xx`) is 303 and the change is applied; `?locale[]=vi` is 422 with `violation("locale","invalid_type")` and `html[lang="vi"]`.
  - `"unknown id"` (Review Focus 1): `patch order_status_path(0), params: {"status"=>"shipped"}` is 404, zero events.

- [ ] **Step 2: Run to verify failure**

Run: `bin/test 8.1 shared/spec/requests/orders_status_spec.rb`
Expected: FAIL (`No route matches`).

- [ ] **Step 3: Implement** route, contract, action, show-page form, copy.

- [ ] **Step 4: Run to verify pass**

Run: `bin/test 8.1 shared/spec/requests/orders_status_spec.rb && bin/test 8.1`
Expected: 0 failures. If the app fails to boot on the `remind_after` default, or `finalize`'s `p[:status]` is not indifferent, stop and report (finding or README question), do not alter the contract to fit.

- [ ] **Step 5: Flip the matrix**

`opt-in-enum-hash`, `opt-default-as-authored-with-transform`, `finalize-basic`, `msg-violate-keyword`, `unknown-exempt-path-params`, `use-contract`, `unknown-exempt-form-keys`, `unknown-exempt-csrf`, `unknown-exempt-commit`, `unknown-exempt-button`: `status: "shared/spec/requests/orders_status_spec.rb"`. `finalize-violate`: add the spec to `also:`.
Run: `ruby bin/coverage-report` (no `problems`).

- [ ] **Step 6: Commit**

```bash
git add shared docs
git commit -m "feat: change order status through a rootless lazy contract with finalize; flip ten rows"
```

---

### Task 7: Gem matcher specs for the edit and status contracts

**Files:**
- Create: `shared/spec/controllers/orders_edit_contract_spec.rb`
- Modify: `docs/coverage-matrix.yml`

**Interfaces:**
- Consumes: `OrdersController` rules `:update` and `:change_status`, `StatusChange`, matchers.
- Produces: matrix `also:` entries only.

- [ ] **Step 1: Write the spec** (`# README: Testing contracts (RSpec matchers); Standalone contracts`, `require "permittable/rspec"`, describe `OrdersController`, `since: "0.12.0"`, `covers: %w[matcher-accept-reject use-contract opt-in-enum-hash unknown-exempt-path-params cl-0_14_0-9]`)

  - `"declares the update contract"`: `permit_param(:priority).for_action(:update).within(%w[standard express]).optional`; `permit_param(:delivery_on).for_action(:update).as(:date).optional`; `permit_param(:note).for_action(:update).nullable`; `permit_param("shipping_address.city").for_action(:update).required`; `not_to permit_param(:status).for_action(:update)`, same for `:cancel_reason`, `:code`, `:customer` (mass-assignment guard at declaration level).
  - `"does not fill defaults on update"`: `accept_params("order"=>{"note"=>"x"}).for_action(:update).returning("note"=>"x")` (a kept `priority` default would add `"priority"=>"standard"`).
  - `"declares the status contract through use StatusChange"` [use-contract, opt-in-enum-hash]: `permit_param(:status).for_action(:change_status).as(:string).required.within(Order.statuses.keys)`; `permit_param(:cancel_reason).for_action(:change_status).within(Order.cancel_reasons.keys).optional`; `not_to permit_param(:id).for_action(:change_status)`.
  - `"accepts and rejects status payloads"`: `accept_params("status"=>"shipped").for_action(:change_status).returning("status"=>"shipped","remind_after"=>1800)`; `reject_params("status"=>"cancelled").for_action(:change_status).with_violation("cancel_reason", :required_when_cancelled)`; `reject_params("status"=>"cancelled","cancel_reason"=>"1").with_violation("cancel_reason", :inclusion)`.
  - `"matchers do not see path parameters"` [unknown-exempt-path-params]: `reject_params("status"=>"shipped","id"=>"1").for_action(:change_status).with_violation("id", :unknown)` (README "Testing contracts": leave path parameters out of the payload).
  - `describe "deep munge", since: "0.14.0"`: `accept_params("order"=>{"services"=>["gift_wrap", nil]}).for_action(:update).returning("services"=>["gift_wrap"])`; `not_to reject_params("order"=>{"services"=>[nil, "gift_wrap"]}).for_action(:update)`; control: `Permittable::Contract.define(root: :order) { array :services, of: :string }.call("order"=>{"services"=>["gift_wrap", nil]})` is not valid with a violation on `order.services[1]` (`invalid_type`): a standalone contract is unchanged.
  - `describe "Symbol values", since: "0.15.0"`: `accept_params("status"=>:shipped).for_action(:change_status).returning("status"=>"shipped","remind_after"=>1800)`; control: `StatusChange.call("status"=>:shipped)` is not valid with `[["status","invalid_type"]]`.
  - `describe "a blank default on a nullable field", since: "0.14.0"` [cl-0_14_0-9; `# README: Explicit nulls (nullable:)`], on anonymous `Class.new(BaseController)` classes with a rootless `:show` rule and `accept_params({}).for_action(:show).returning(...)`:
    - `optional :note, :string, nullable: true, default: ""` returns `"note"=>nil`; `permit_param(:note).for_action(:show).with_default("")` passes.
    - `optional :note, :string, normalize: :strip, nullable: true, default: "   "` returns `"note"=>nil`.
    - `optional :colour, :string, in: %w[red], nullable: true, default: ""`, `optional :code, :string, format: /\A\d+\z/, nullable: true, default: ""` and `optional :age, :integer, nullable: true, default: ""` all load and return `nil` (before 0.14.0 they raised at class load).
    - Controls: non-nullable `optional :note, :string, default: ""` returns `"note"=>""`; `optional :note, :string, nullable: true, transform: ->(v) { v.upcase }, default: ""` returns `"note"=>""` (as authored, no `nil` reading).
    - Not tested (undocumented): a `:json` field with `transform:` and a blank default.

- [ ] **Step 2: Run, and prove each example can fail**

Run: `bin/test 8.1 shared/spec/controllers/orders_edit_contract_spec.rb`
Expected: PASS on a correct gem. Temporarily flip one expectation per describe (for example `returning("services"=>["gift_wrap", nil])`) to see RED, then revert; do not commit the flips.

- [ ] **Step 3: Flip the matrix**

Add this spec to `also:` on `matcher-accept-reject`, `use-contract`, `opt-in-enum-hash`, `unknown-exempt-path-params`; set `cl-0_14_0-9` `status: "shared/spec/controllers/orders_edit_contract_spec.rb"`; add `"0.15.0"` to `matcher-accept-reject`'s `changelog:` (`0.14.0` was added in Task 5).
Run: `ruby bin/coverage-report` (no `problems`).

- [ ] **Step 4: Commit**

```bash
git add shared/spec/controllers/orders_edit_contract_spec.rb docs/coverage-matrix.yml
git commit -m "test: gem matcher specs for the edit and status contracts, deep munge and Symbol values"
```

---

### Task 8: System specs through the real forms, with the Inspector

**Files:**
- Create: `shared/spec/system/orders_edit_spec.rb`
- Modify: `docs/coverage-matrix.yml`

**Interfaces:**
- Consumes: the edit form, the status form, `OrderPayloads.create_order`, Inspector iframe `inspector-frame` (`#inspector-status`, `#inspector-raw-params`, `#inspector-permitted`, `#inspector-violations`), as used by Plan 1's `orders_create_spec` system file.

- [ ] **Step 1: Write the spec** (`# README: How a request flows; Unknown parameters; Output reshaping`, `type: :system`, `covers: %w[unknown-exempt-form-keys unknown-exempt-csrf unknown-exempt-commit unknown-exempt-button]` at the describe level,, `since: "0.12.0"`; same `before`/`after` as Plan 1's system spec: clear `Inspector::Store`, turn `ActionController::Base.allow_forgery_protection` on and restore it. Never post a payload: every example `visit`s, fills and `click_button`s.)

  - `"edits an order through the real form"` [`covers: %w[use-optional absent-optional-omitted]` on the example]: `create_order(priority: "express", note: "keep", services: %w[gift_wrap])`; `visit order_path(order, locale: :vi)`, `click_link "Sửa đơn"`; assert the form is prefilled (`find_field("Ghi chú").value` is `keep`, the `Gói quà` box checked); `fill_in "Ghi chú", with: "  giao   buổi sáng "`, `uncheck "Gói quà"`, `check "Bảo hiểm"`; `click_button "Lưu thay đổi"`; page has `h1` with the order code and `#flash-notice` matching `/Đã cập nhật/`; reload: note `giao buổi sáng`, services `["insurance"]`, priority still `express`. Inside `within_frame("inspector-frame")`: `#inspector-status` matches `PATCH /orders/<id> → 303`; `#inspector-raw-params` has a row `_method` / `patch` and a row `order[services][]` / `` (the hidden blank); `#inspector-permitted` does not say `Bị từ chối`.
  - `"shows a violation in place"`: on the edit form `fill_in "Mã giảm giá", with: "abc"`, submit; `have_css(%(li[data-param="order.coupon_code"][data-code="format"]))`, the form is still on the page, `have_current_path(order_path(order), ignore_query: true)`; Inspector status `422` and `#inspector-permitted` has `Bị từ chối`.
  - `"changes status through the rootless form"` [`covers: %w[msg-violate-keyword unknown-exempt-path-params finalize-violate]`]: on the show page `select "Đã huỷ", from: "status"`, leave the reason blank, `click_button "Cập nhật trạng thái"`: `li[data-param="cancel_reason"][data-code="required_when_cancelled"]` with text `bắt buộc khi trạng thái là Đã huỷ`; Inspector status `422` and `#inspector-violations` has a row with `cancel_reason`. Then `select "Sai địa chỉ", from: "cancel_reason"`, submit again: show page has `Đã huỷ`, `#cancel-reason` text `Lý do huỷ: Sai địa chỉ`, `#remind-after` text `Nhắc khách sau: 1800 giây`; Inspector status `PATCH /orders/<id>/status → 303`, raw params include `_method`, `commit`, `authenticity_token` (the form works only because the gem exempts them under `unknown: :error`). A further example submits the same form with `click_button "Cập nhật trạng thái (nút)"` (the `button_tag`): status applied, raw params include `button` with an empty value. A second order: `fill_in "Nhắc khách sau (phút)", with: "45"`, status `Đang giao`, submit: `#remind-after` shows `2700 giây`.

- [ ] **Step 2: Run to verify failure, then pass**

Run: `bin/test 8.1 shared/spec/system/orders_edit_spec.rb`
Expected before Tasks 5 and 6 would be FAIL; after them it must PASS. If a selector differs from the views, fix the spec's selector only when the view is the lab's own; a red result caused by the gem stays red.

- [ ] **Step 3: Flip the matrix**

Add `shared/spec/system/orders_edit_spec.rb` to `also:` on `use-optional`, `absent-optional-omitted`, `msg-violate-keyword`, `unknown-exempt-path-params`, `finalize-violate`, `unknown-exempt-form-keys`, `unknown-exempt-csrf`, `unknown-exempt-commit`, `unknown-exempt-button`.
Run: `ruby bin/coverage-report` (no `problems`).

- [ ] **Step 4: Commit**

```bash
git add shared/spec/system/orders_edit_spec.rb docs/coverage-matrix.yml
git commit -m "test: system specs for the edit and status forms with Inspector assertions"
```

---

### Task 9: Full matrix, coverage report, README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Run everything**

Run: `bin/matrix` (local gem) and `ruby bin/coverage-report`
Expected: all three of 7.2, 8.0, 8.1 `PASS`, the same example count on each, `since` report empty for the local gem, no `FAILED TO RUN`. Report: `total 282`, `covered 76` (54 + 22), `uncovered 200`, `awaiting_author 0`, `out_of_scope 6`; no `plan 2` block under the uncovered list; no awaiting-author section; no `problems`. `ruby bin/coverage-report --strict` still exits 1 (other plans' rows).

- [ ] **Step 2: Triage**

A red example is one of: a lab bug (fix once in `shared/`, never per version), or a **finding** (gem differs from README): leave it red. For each finding add to README "Findings (gem vs README)": Rails version, README line, observed behaviour, minimal repro. Never edit an expectation to turn it green.

- [ ] **Step 3: Update README**

Replace "None so far" under "Findings (gem vs README)" with this plan's result (example count per Rails version, findings or none). Add to "Per-version notes" anything the three Rails versions needed (nothing is expected). Add a short "Notes for the author" list: CHANGELOG 0.12.0 #123 ("frozen" copy reaches the action) and 0.15.0 #176 ("enforce or monitor" wording) differ from the code, the README is correct on both; these are notes, not findings, and no spec tests them.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: Plan 2 results and findings"
```

---

## Self-review

**Spec coverage.** Section 6 row "Sửa đơn / đổi trạng thái": partial update (Task 5), `in:` for status (Task 6, Hash form via `Order.cancel_reasons`), `finalize` + `violate!` (Task 6), `use G, optional: true` (Task 5), path param `:id` (Task 6). All 22 `plan: 2` rows (the 17 original, the four exemption rows moved from plan 5, and `cl-0_14_0-9`) are in the "how each example fails" table and flipped in Tasks 4 to 7 (six, five, ten and one primaries; the 17 original: use-only-except, use-override-duplicate, use-refuses-finalize, finalize-bare-runner, pp-last-rule-wins, finalize-violate | pp-enforce-lazy, use-compose, use-optional, absent-optional-omitted, event-once-per-request | opt-in-enum-hash, opt-default-as-authored-with-transform, finalize-basic, msg-violate-keyword, unknown-exempt-path-params, use-contract). Rows reassigned: the four exemption rows from plan 5 to plan 2 (Task 2). Every row has an honest example; `finalize-bare-runner` and the class-load rows run on anonymous classes, with the reason stated. Housekeeping (a) Task 2 (and anchors in Tasks 5 and 7), (b) to (d) Task 1. System specs and Inspector: Task 8. Full matrix and report: Task 9.

**Step scan.** Test steps name the example and the assertions with the README's literal values; code steps give signatures and exact contract shapes, not bodies. Verification steps carry a command and an expected result. Task 4 and Task 7 write specs for existing gem behaviour, so "fails first" is replaced by an explicit mutation check that each example can go red.

**Type consistency.** `OrderScheduleFields`, `OrderExtrasFields`, `StatusChange`, `Order.cancel_reasons`, `Order#closed?`, `OrderPayloads.create_order`, `order_status_path`, `set_order`, `guard_closed_order`, `record_attempted_fields`, `render_error(message:, code:, status:, errors: [])` are defined in Tasks 3 and 5 and used with the same names in Tasks 6 to 8. Violation codes `required_when_cancelled` and `only_when_cancelled` and the copy strings match across Tasks 6 and 8.

**Review Focus.** Five lines, each with its test in Tasks 5, 6.

**Proportion.** About 4 times the spec's size, close to Plan 1's ratio; most of the length is the row table and the per-example assertions the skill requires, with no function bodies.

## Risks and rollback

- Gem moved to 0.15.0 during planning; if it moves again, re-read the README sections cited in the row table before Task 5 and 6 and re-check the date literals.
- `remind_after`'s `format:` plus an Integer `default:` may be refused at class load (README says defaults are checked against the field's own contract). That is a finding, not a reason to edit the contract.
- The create refactor (Task 3) is protected by the whole Plan 1 suite; revert that commit alone if it regresses.
- Each task is one commit on `plan-02-edit-order`, stacked on `plan-01-foundation` (PR #1 not merged); rollback is `git revert` of the task's commit.
