---
date: 2026-11-12
topic: Which user-visible CHANGELOG claims (permittable 0.11.0 - 0.15.0) the README does not state, and are they true
git_commit: n/a (gem repo master, version 0.15.0; lab branch plan-02-edit-order)
status: complete
---
## Answer
The README is almost complete: of 89 changelog bullets checked (internal-only bullets such as dependency bumps, CI and spec-suite fixes excluded), 73 are stated in the README and 16 are missing or only partly stated. Every probed claim is true except one: the 0.12.0 #123 wording "reaches the action as a frozen ... copy" is false for the value the action receives (stored default is frozen; the action's copy is not).

Probe method: Rails 8.1 lab container (gem 0.15.0 mounted), probes in `apps/rails-8_1/tmp/probes/` (`h.rb` helper, `p1.rb` ... `p8.rb`). Docker Desktop was not running; I started it. Error messages in probe output are Vietnamese because the lab app's locale is `vi`.

## Key findings
- Both known gaps confirmed missing from the README and true (see section 2, rows G1 and G2).
- The README states, with line numbers, nearly all `0.11.1` security, generator, matcher and export fixes (see table).
- One CHANGELOG sentence is looser than the code (0.15.0 #176, see Ambiguous).

## 1. Table (one row per bullet; stated rows grouped where they share a README line)
Probe column: "true (pN)" = probe script `apps/rails-8_1/tmp/probes/pN.rb`; "not probed" = README already states it, so not re-run (task scope).

| Version | #PR | Claim (short) | README status | Probe |
|---|---|---|---|---|
| 0.15.0 | 174 | `:date`/`:datetime` string zone name/hour/offset `Date._parse` drops: honoured or refused (`"2026-09-05 EST"` = 05:00Z etc.) | stated 699, 703, 714 | true (p4: EST 05:00Z, ctime EST/-0500 15:00Z, `20260905 10 EST` 15:00Z, `T10`/`foo`/`W. Europe`/`10 EST`/`UTC+0000` refused) |
| 0.15.0 | 174 | dotted eras (`A.D.`) skipped, single letter never a zone, initial-led unknown zones (`W. Europe`, `S. Africa Standard Time`) refused | partly (703 says "any other word", not the initial-led/era/single-letter cases) | true (p4) |
| 0.15.0 | 174 | `:date` in:/default:/example: written as non-midnight-UTC time string fails at load | stated 698 (string rule), 1626 partly | true (p4: `in:` and `default:` "2026-09-05 EST" raise ArgumentError) |
| 0.15.0 | 175 | authored `:json` default/example with non-finite BigDecimal or sub-ns Time (any depth) fails at load | partly (737 names "NaN or Infinity"; 1626 covers `:datetime` only) | true (p4, path `a.b[0].c` in message, `.round(9)` hint) |
| 0.15.0 | 175 | `:date` `in:` member written as String exported `YYYY-MM-DD` | stated 1550 | true (p4) |
| 0.15.0 | 175 | blank default on nullable `:json` reads `nil` (non-nullable still raises) | missing (known gap b) | true (p1, p8) |
| 0.15.0 | 176 | audit lists controllers a route names that nothing loaded (`Rails::HealthController`) | stated 1272 | true (p5) |
| 0.15.0 | 176 | loading runs the controller file; error inside it is raised, not rescued as NameError | partly (1272 says it loads; not that errors raise) | true (p5: RuntimeError propagates; missing constant skipped) |
| 0.15.0 | 176 | Metal rule that cannot run is audited uncovered with note | partly (541 says "`no contract` (`contract cannot run`)"; actual note text differs) | true for `enforce: true`/monitor (p6); see Ambiguous |
| 0.15.0 | 177 | matcher Symbol value read as String on a controller; Contract still `invalid_type` | stated 1433 | true (p7) |
| 0.15.0 | 177 | matcher failure messages redact sensitive values, `differs at:` | stated 1433 | true (p7) |
| 0.15.0 | 178 | rootless `unknown: :error` JSON body lists form keys as free properties | stated 931 | not probed |
| 0.15.0 | 178 | `alias_attribute` / `store_accessor` fields checked against backing column | stated 1044 | not probed |
| 0.14.0 | 165 | `:file` field and `of: :file` | stated 601-608, 701 | not probed |
| 0.14.0 | 165 | operation with `:file` exported `multipart/form-data` | stated 608, 1548 | not probed |
| 0.14.0 | 156 | `rails_routes` descriptors gain `defaults:` | stated 931 | not probed |
| 0.14.0 | 153 | `:date` string with time/zone accepted only at midnight UTC | stated 698 | not probed (p4 covers EST case) |
| 0.14.0 | 166 | ISO date + offset/`Z` and no time is midnight at that offset | stated 699, 703 | not probed |
| 0.14.0 | 154 | matchers apply Rails deep munge | stated 1433, 747 | not probed |
| 0.14.0 | 155 | Metal controller enforces whatever module order, or raises at load | stated 541 | true (p6 "M1 load" raises for own `mode: :monitor`) |
| 0.14.0 | 156 | route-`defaults:` name leaves the OpenAPI request body | stated 931 | not probed |
| 0.14.0 | 160 | blank default on nullable field reads `nil` (incl. `"   "` + `normalize: :strip`, export `"default": null`, `with_default("")`) | missing (known gap a) | true (p1, p7, p8) |
| 0.13.1 | 157 | ignored column in table not reported missing | stated 1042 | not probed |
| 0.13.1 | 159 | `:datetime` default/example finer than ns fails at load | stated 1626 | not probed |
| 0.13.1 | 161 | export no longer documents Metal framework methods | stated 1272 (Metal controllers) / internal | not probed |
| 0.13.1 | 162 | array `example:` with date parts exported as the date | missing | true (p4: `"examples":[[{"on":"2026-10-17"}]]`) |
| 0.13.1 | 163 | `:json` default/example NaN/Infinity fails at load | stated 737 | true (p4) |
| 0.13.1 | 164 | midnight-UTC Time/DateTime before 1582 to `:date` reads the day it names | missing (714 covers strings only) | true (p4: 1500-01-01 for Time and DateTime) |
| 0.13.1 | 158 | catch-all `rescue_from` after include wins | stated 794 | not probed |
| 0.13.0 | 144 | audit/export follow mounted engines; `engines: false` | stated 1343, 1492, 1319 | not probed |
| 0.13.0 | 108 | tasks read Metal controllers | stated 1272 | not probed |
| 0.13.0 | 136 | rootless field filled from URL documented as path param | stated 931 | not probed |
| 0.12.0 | 121 | `use G, optional: true` drops `default:` | stated 972, 978 | not probed |
| 0.12.0 | 122 | `use` refuses a Contract with `finalize` | stated 990 | true (p4) |
| 0.12.0 | 126 | Hash/Array/Set subclass with own `include?` read as list | stated 628 | not probed |
| 0.12.0 | 127 | `:date` reads Time/DateTime only at midnight UTC | stated 698 | not probed |
| 0.12.0 | 128 | `date_select`/`datetime_select`/`time_select` parts | stated 935 | not probed |
| 0.12.0 | 106 | `:datetime` `in:` member finer than ns fails at load | stated 1626 | not probed |
| 0.12.0 | 99 | bad `length:` Range ends fail at load | stated 1623 | not probed |
| 0.12.0 | 100 | `:datetime` string read Gregorian; unhonourable zone refused | stated 714 | not probed |
| 0.12.0 | 101, 110, 145 | decimal underflow, huge decimal string, uncastable Numeric | stated 695, 696, 707 | not probed |
| 0.12.0 | 111 | scalar array drops hidden blank element | stated 747 | not probed |
| 0.12.0 | 97, 105 | generator: PG array column; json default-array TODO | stated 1075, 1240 | not probed |
| 0.12.0 | 94 | negated matchers fail when no rule covers the action | stated 1431 | not probed |
| 0.12.0 | 95 | `returning` on reject / `with_violation` on accept raise | stated 1419 | true (p7) |
| 0.12.0 | 117 | `permit_param` holds `[n]` to the field they index | missing | true (p7, p8: `items[0].sku` ok on array, false on hash field; `[0][1]` false) |
| 0.12.0 | 116 | `accept_params`/`reject_params` on a Contract run through `Contract#call` | missing | true (p7: non-Hash raises ArgumentError as `call` does) |
| 0.12.0 | 146 | matchers exempt configured CSRF param | stated 1433 | not probed |
| 0.12.0 | 123 | `:json` default reaches action as frozen indifferent-access copy, String keys | partly (632: "frozen, each request gets its own deep copy"; String keys not said) | String keys, HWIA, distinct copy per call: true. "frozen": FALSE at the action (p2, p3) |
| 0.12.0 | 150 | private `render_error` delegated to | stated 817 | not probed |
| 0.12.0 | 152 | JSON Schema table `finalize` row restored | stated 1557 | not probed |
| 0.11.1 | 149 | sensitive non-String value not in AR bind log | stated 1122-1129 | not probed |
| 0.11.1 | 132, 142 | array default/example and sensitive `in:`/`format:` not exported | stated 1558 | true (p4) |
| 0.11.1 | 98 | three-keyword `render_error` works | stated 817 | not probed |
| 0.11.1 | 147 | envelope Content-Type JSON under `respond_to` | missing | true (p5: `application/json; charset=utf-8`, 422) |
| 0.11.1 | 102 | `Parameters` nested in a Contract Hash input converted | stated 1458 | not probed |
| 0.11.1 | 131 | `unknown: :log` works for standalone Contract | stated 1460 | not probed |
| 0.11.1 | 130 | standalone rejection instrumented with `action: "call"` | stated 1456 | not probed |
| 0.11.1 | 129 | `button_tag`/`image_submit_tag` keys exempt | stated 931 | not probed |
| 0.11.1 | 112 | `fields_for` hash-by-index accepted by `array ... do` | stated 618 | not probed |
| 0.11.1 | 143 | `:decimal` accepts exact Rational | stated 696 | not probed |
| 0.11.1 | 124 | `example:` under `transform:` published with right type | stated 642 | not probed |
| 0.11.1 | 125 | empty live `in:` at class load | stated 628 | not probed |
| 0.11.1 | 115 | monitor-mode eager check cannot stop the action (malformed JSON, raising `validate:`) | partly (1195 says eager; not that it is rescued) | true (p5: 200 and action ran for both) |
| 0.11.1 | 109 | audit stale/unmatched-ignore sections printed with no routed action | stated 1304, 1353 | not probed |
| 0.11.1 | 114 | export omits non-OpenAPI verbs | stated 1477 | not probed |
| 0.11.1 | 135 | optional-group variants Rails never dispatches not documented | stated 1494 | not probed |
| 0.11.1 | 133 | `finalize` flagged `x-permittable-finalize` | stated 1490, 1557 | not probed |
| 0.11.1 | 134 | required decimal/date/datetime `minLength: 1` | stated 1545 | true (p4 array example export shows `minLength: 1`) |
| 0.11.1 | 113 | editing an exported `desc:` no longer rewrites the contract | missing | true (p4: append to exported description leaves contract at "d") |
| 0.11.1 | 138, 137, 104, 139, 140 | generator: helper-name boundary, `%i[]`, no-paren/String root, undefined actions, id/timestamp | stated 1210, 1241, 1243, 1249 | not probed |
| 0.11.1 | 103 | type guard accepts generator's integer-enum recipe | stated 1085 | not probed |
| 0.11.1 | 96, 120 | matcher instrumentation controller path; failure-message subject | stated 1141 (payload) / internal wording | not probed |
| 0.11.1 | 118 | `with_default` on `:json` matches either key spelling | missing | true (p7: sym and String keys both match both ways) |
| 0.11.1 | 119 | `matching("email")` String preset | stated 685 | true (p7) |
| 0.11.1 | 148 | locale switch must wrap enforce check | stated 867 | not probed |
| 0.11.0 | 69 | `Permittable.audit_ignore` | stated 231, 1323 | not probed |
| 0.11.0 | 68 | operationId collisions ranked by operation | stated 1496, 1506 | not probed |
| 0.11.0 | 68, 67 | routes Rails never dispatches; optional segments | stated 1306, 1319, 1494 | not probed |
| 0.11.0 | 49 | `Audit.stale` base-controller inheritance | stated 1304 | not probed |
| 0.11.0 | 70 | wrapper-key exemption with ParamsWrapper order | stated 931, 933 | not probed |

## 2. README text proposed (missing or partly stated, probe true)

**G1 (0.14.0 #160), heading `### Explicit nulls (`nullable:`)` (README line 761), after the `default: nil` bullet at line 785:**
> A blank `default:` on a `nullable:` field reads as `nil`, as a request that sends `""` does. `optional :note, :string, nullable: true, default: ""` gives the action `nil` when `note` is omitted, and so does a default that normalizes to `""` (`"   "` with `normalize: :strip`); the exported schema prints `"default": null`, `example: ""` publishes `[null]`, and `with_default("")` reads as `nil` in the matcher. An `in:`, `format:` or `:integer` field with a nullable `default: ""` therefore loads, with `nil` as its default. A non-nullable `default: ""` is unchanged, and a nullable `required: true` field with a default is still refused. A field with `transform:` keeps its default as authored, `""` included.

**G2 (0.15.0 #175 plus the transform rule), heading `### Free-form hashes (`:json`)` (line 716), after the table row at line 737:**
> A `nullable:` `:json` field with `default: ""` loads with `nil` as its default, the same reading a request that sends `""` gets; a non-nullable `:json` field with `default: ""` still raises at class load ("must be a Hash"). With a `transform:`, the default is still handed out as authored, except here: observed behaviour is that a blank default on a nullable `:json` field with `transform:` also reads `nil` (probe p1 b5), so the transform never sees `""`. An authored `default:` or `example:` that holds a non-finite `BigDecimal` or a `Time`/`DateTime` finer than a nanosecond, at any depth, fails at class load naming the field and the path (`a.b[0].c`); round a `Time` with `.round(9)`.

**0.12.0 #123, heading `### Free-form hashes (`:json`)` (line 716):**
> A `:json` field's `default:` reaches the action as a copy with String keys and indifferent access (`default: { theme: "dark" }` gives `keys == ["theme"]`; `default[:theme]` still works). Each request gets its own copy. [Do not claim it is frozen at the action: the stored default is frozen, the per-request copy is not.]

**0.11.1 #147, heading `### Violations and error responses` (line 790):**
> Under `respond_to`, the error envelope is sent as `application/json` even when the action lists `html` first.

**0.11.1 #115, heading `### Monitor mode (roll out without rejecting)` (line 1163), after line 1195:**
> The eager check cannot stop the action: a malformed JSON body or a `validate:` that raises inside a monitor-mode rule is rescued, and the action runs as before (a malformed body does not answer 400 from the check; in enforce mode it still does).
(Caveat: p5 showed the action ran with 200 for malformed JSON in monitor mode; the "400 in enforce" half was not verified through a real middleware stack, since a direct `action.call` raises `ParseError` before the gem runs. Drop that clause.)

**0.13.1 #164, heading `### Types and strict coercion` (line 687), after line 714:**
> A `Time`, `DateTime` or `TimeWithZone` sent to a `:date` reads as the day its own calendar labels name, in the proleptic Gregorian calendar: `Time.utc(1500, 1, 1)` is `1500-01-01`, with or without ActiveSupport, matching the String `"1500-01-01"`.

**0.13.1 #162, heading `### Exporting OpenAPI (docs that cannot drift)` (line 1468) or its schema table (line 1550 area):**
> An `example:` written with `date_select` parts (`{ "on(1i)" => "2026", "on(2i)" => "10", "on(3i)" => "17" }`), also inside an `array`, is published as the date it spells (`"2026-10-17"`).

**0.15.0 #174 remainder, heading `### Types and strict coercion`, after line 703:**
> Dotted eras (`A.D.`, `B.C.`) are skipped like `AD` and `BC`, and a single letter is never a zone (`"2026-09-05 A"` is midnight UTC). A zone name that starts with an initial and that Ruby does not know (`"W. Europe"`, `"S. Africa Standard Time"`) is `invalid_type`.

**0.15.0 #176, heading `### Auditing coverage (`permittable:audit`)` (line 1268), after line 1272:**
> Loading a routed controller runs its file, so an import-time side effect runs, and an error raised in that file is raised from the audit rather than rescued as a missing constant.

**0.12.0 #116 and #117, heading `### Testing contracts (RSpec matchers)` (line 1380):**
> On a standalone `Contract`, `accept_params` and `reject_params` call `Contract#call`, so a payload that is not a Hash (`accept_params([{ "id" => "1" }])`) raises `ArgumentError` as `call` does. `permit_param` takes at most one `[n]` per path segment and only on an array field: `permit_param("items[0].sku")` passes for `array :items`, and fails for a nested hash `h`, as the runtime would answer `invalid_type`.

**0.11.1 #118, same section:**
> `with_default` on a `:json` field matches either key spelling: `with_default("theme" => "dark")` and `with_default(theme: "dark")` both pass for `default: { theme: "dark" }` and for a String-keyed one.

**0.11.1 #113, heading `### Exporting OpenAPI (docs that cannot drift)`:**
> The exported document is a copy: appending to a `description` in it does not change the contract or later exports. (Low value; optional.)

## 3. FALSE findings (gem findings)
1. 0.12.0 #123, CHANGELOG: "A `:json` field's `default:` now reaches the action as a frozen indifferent-access copy, with string keys". Observed: the value the action receives is an `ActiveSupport::HashWithIndifferentAccess` with String keys, distinct per call, but NOT frozen (`.frozen?` false at top level and nested; mutating it succeeds). The default stored on the rule is frozen (`rule[:fields].first[:default].frozen?` true, nested true), so the README's wording at line 632 ("stored frozen, each request gets its own deep copy") is right and the CHANGELOG sentence is wrong or sloppy. Probes: `apps/rails-8_1/tmp/probes/p2.rb` (result and real controller request), `p3.rb` (stored value).

## Ambiguous
- 0.15.0 #176 CHANGELOG says the effective mode "is `enforce` or `monitor`". Code and probe p6: inert only for `enforce: true` or effective mode `:monitor`; `mode: :enforce` or the default `Permittable.mode = :enforce` without `enforce: true` is NOT inert (rule validates lazily from `permitted_params`). README 541 matches the code. CHANGELOG wording is the loose one.
- 0.15.0 #175 plus 0.14.0 #160: with `transform:`, a nullable String field's blank default stays `""` (p1 b2) but a nullable `:json` field's blank default becomes `nil` (p1 b5). Neither CHANGELOG entry says the `:json` case ignores the "stored as authored" rule; likely intended (a `""` is not a Hash) but undocumented.
- Counts: "stated" is judged by a README line that carries the claim; for grouped bullets (generator, decimal) I checked the cited lines by grep and a short read, not every clause.
- Not verified: the 0.13.1 #161 claim and the generator/task bullets via runtime; README states them.

## Recommendation
Add the 12 snippets above (G1 and G2 first); fix the CHANGELOG #123 "frozen" wording (or freeze the copy, if that was the intent).

## Sources
- /Users/sang/Projects/individual-projects/permittable/CHANGELOG.md (0.11.0-0.15.0, lines 3-189)
- /Users/sang/Projects/individual-projects/permittable/README.md (line numbers above, gem 0.15.0)
- /Users/sang/Projects/individual-projects/permittable/lib/permittable/audit.rb (`inert?`, `routed_controllers`)
- Probes: /Users/sang/Projects/individual-projects/permittable-lab/apps/rails-8_1/tmp/probes/{h,p1,p2,p3,p4,p5,p6,p7,p8}.rb
