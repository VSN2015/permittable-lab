# README: Contents
require "lab/coverage_matrix"
require "tmpdir"
require "fileutils"

RSpec.describe Lab::CoverageMatrix, covers: %w[] do
  ROOT = File.expand_path("../../..", __dir__)
  UNCOVERED = "chưa phủ".freeze
  AWAITING = "chờ tác giả".freeze
  OUT = "ngoài phạm vi".freeze

  ANCHOR_IDS = %w[
    pp-root pp-model pp-model-true-infer pp-unknown pp-enforce-true pp-enforce-lazy pp-mode-monitor pp-desc pp-catch-all pp-last-rule-wins pp-subclass-override
    kind-scalar kind-nested kind-array-scalar kind-array-hash kind-array-fields-for-hash kind-array-length-short-circuit kind-json
    opt-in-range opt-in-list opt-in-live-include opt-in-enum-hash opt-format-regexp opt-length-string opt-length-array opt-length-integer-exact opt-normalize-squish opt-normalize-strip opt-normalize-downcase opt-normalize-upcase opt-normalize-email opt-normalize-proc opt-default-cast opt-default-as-authored-with-transform opt-validate-falsy opt-validate-symbol-code opt-transform opt-virtual opt-sensitive opt-sensitive-cascade opt-sensitive-false-opt-out opt-message-string opt-message-hash opt-of opt-max-depth opt-required-array opt-desc opt-example opt-nullable opt-nullable-required opt-nullable-default-nil opt-nullable-array-nested opt-check-order
    preset-email preset-uuid preset-url preset-slug preset-hostname
    type-string type-integer type-float type-decimal type-boolean type-date type-datetime type-json type-confusion-array-for-scalar type-string-encoding
    absent-nullable-normalize-blank absent-blank-array-only-result absent-nil-and-empty absent-normalize-first absent-optional-omitted absent-required-missing absent-default absent-blank-array-element absent-false-is-present
    err-code-missing err-code-invalid-type err-code-inclusion err-code-format err-code-length err-code-unknown err-code-invalid err-code-custom-symbol err-status-400-root-missing err-status-400-root-wrong-shape err-status-422-field err-path-dotted-indexed err-details-complete-message-bounded err-envelope-json err-render-error-custom err-render-error-private err-render-error-three-keyword err-rescue-from-order
    i18n-default-messages i18n-fallback-order i18n-per-request-locale msg-string msg-hash msg-violate-keyword
    problem-format problem-title-by-status problem-base-uri problem-instance problem-opts-out-render-error
    unknown-ignore unknown-log unknown-error unknown-every-level unknown-exempt-router-keys unknown-exempt-csrf unknown-exempt-csrf-renamed unknown-exempt-form-keys unknown-exempt-commit unknown-exempt-button unknown-exempt-image-submit unknown-exempt-path-params unknown-wrapper-key date-select-parts datetime-select-parts time-select-parts date-parts-blank date-parts-invalid date-parts-own-key-wins date-parts-time-zone-recipe
    use-group use-compose use-optional use-only-except use-contract use-refuses-finalize use-override-duplicate transform-field transform-default-authored finalize-basic finalize-violate finalize-bare-runner
    drift-missing-column drift-migration-hint drift-ignored-columns drift-virtual drift-nested-implicit-virtual drift-schema-unreachable drift-check-types drift-type-groups drift-enum drift-pg-array-column
    log-filter-params log-filter-non-string log-filter-sql-bind log-registry-swap log-assign-heals event-payload event-mode event-once-per-request monitor-pass-through monitor-violations monitor-env monitor-rule-beats-global monitor-eager monitor-uncheckable-logged
    rake-audit-table rake-audit-strict rake-audit-stale rake-audit-ignore rake-audit-outside-root rake-audit-engines rake-audit-metal rake-audit-routes-order rake-openapi-stdout rake-openapi-file rake-openapi-engines rake-openapi-metal rake-openapi-path-params rake-openapi-problem rake-openapi-monitor-extension rake-generate-all rake-generate-one rake-generate-expect-permit rake-generate-monitor-draft rake-generate-ignore rake-generate-pg-array
    matcher-permit-param matcher-accept-reject matcher-negated matcher-preset contract-call contract-call-bang contract-json-schema contract-always-enforces contract-no-router-exemption contract-no-memo contract-input-errors contract-unknown-log audit-entries-plain generator-draft-plain registry-swap alias-concerns-on-rails
    cfg-mode cfg-error-format cfg-problem-base-uri cfg-check-column-types cfg-audit-ignore cfg-audit-ignore-outside-root
  ].freeze

  def good(overrides = {})
    { "id" => "r1", "area" => "field-option", "feature" => "f", "readme" => "R", "since" => "0.6.0",
      "plan" => 1, "status" => UNCOVERED, "question" => nil, "reason" => nil, "also" => [], "changelog" => [] }.merge(overrides)
  end

  def problems(rows, root: @root, files: @files)
    Lab::CoverageMatrix.problems(rows, spec_root: root, spec_files: files)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      @root = dir
      FileUtils.mkdir_p(File.join(dir, "shared/spec"))
      @files = []
      example.run
    end
  end

  def write_spec(rel, body)
    path = File.join(@root, rel)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, body)
    @files << path
    rel
  end

  def meta(ids)
    "RSpec.describe 'x', #{'cov' + 'ers'}: %w[#{ids.join(' ')}] do\nend\n"
  end

  def expect_problem(rows, id, **opts)
    msgs = problems(rows, **opts)
    expect(msgs.grep(/#{Regexp.escape(id)}/)).not_to be_empty, "expected a problem mentioning #{id}, got #{msgs.inspect}"
  end

  it("accepts a clean row") { expect(problems([good])).to eq [] }

  it("reports a duplicate id") { expect_problem([good, good], "r1") }
  it("reports an unknown area") { expect_problem([good("area" => "nope")], "r1") }
  it("reports a plan outside 1..6") { expect_problem([good("plan" => 7)], "r1") }
  it("reports a missing plan on an in-scope row") { expect_problem([good("plan" => nil)], "r1") }

  it "allows a missing plan only for out-of-scope rows" do
    row = good("area" => "out-of-scope", "plan" => nil, "status" => OUT, "reason" => "not here")
    expect(problems([row])).to eq []
  end

  it "reports a status path that does not exist" do
    expect_problem([good("status" => "shared/spec/missing_spec.rb")], "r1")
  end

  it "reports an existing file that lacks covers: for the id" do
    rel = write_spec("shared/spec/a_spec.rb", meta(%w[other]))
    msgs = problems([good("status" => rel), good("id" => "other", "status" => UNCOVERED)])
    expect(msgs.grep(/r1/)).not_to be_empty
  end

  it "accepts a path status whose file covers the id" do
    rel = write_spec("shared/spec/a_spec.rb", meta(%w[r1]))
    expect(problems([good("status" => rel)])).to eq []
  end

  it("reports an awaiting-author row with no question") { expect_problem([good("status" => AWAITING)], "r1") }
  it("accepts an awaiting-author row with a question") { expect(problems([good("status" => AWAITING, "question" => "?")])).to eq [] }

  it "reports an out-of-scope row with no reason" do
    expect_problem([good("area" => "out-of-scope", "plan" => nil, "status" => OUT)], "r1")
  end

  it "reports an out-of-scope status on a row whose area is not out-of-scope" do
    expect_problem([good("plan" => nil, "status" => OUT, "reason" => "x")], "r1")
  end

  it("reports a status outside the four forms") { expect_problem([good("status" => "done")], "r1") }
  it("reports a since that is not a version") { expect_problem([good("since" => "soon")], "r1") }
  it("reports a non-string since") { expect_problem([good("since" => 0.6)], "r1") }

  it "reports a covers: id with no row (orphan)" do
    write_spec("shared/spec/a_spec.rb", meta(%w[ghost-row]))
    expect_problem([good], "ghost-row")
  end

  it "summarises the rows" do
    rows = [good("id" => "a"), good("id" => "b", "status" => AWAITING, "question" => "?"),
            good("id" => "c", "area" => "out-of-scope", "plan" => nil, "status" => OUT, "reason" => "x"),
            good("id" => "d", "status" => "shared/spec/a_spec.rb")]
    expect(Lab::CoverageMatrix.summary(rows)).to eq(total: 4, covered: 1, uncovered: 1, awaiting_author: 1, out_of_scope: 1)
  end

  context "with the real matrix" do
    let(:rows) { Lab::CoverageMatrix.load(File.join(ROOT, "docs/coverage-matrix.yml")) }

    it "the real matrix is consistent" do
      files = Dir[File.join(ROOT, "shared/spec/**/*_spec.rb")]
      expect(Lab::CoverageMatrix.problems(rows, spec_root: ROOT, spec_files: files)).to eq []
    end

    it "has the seeded anchor rows" do
      expect(ANCHOR_IDS - rows.map { |r| r["id"] }).to eq []
    end
  end
end
