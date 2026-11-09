# Evaluated from each app's Gemfile via eval_gemfile (added by shared/bin/patch_app.rb).
require File.expand_path("lib/lab/gem_source", __dir__)

# Rails 8.0.x (activesupport JSON encoding) passes `quirks_mode:` to JSON.generate, which json 3.x
# rejects ("unknown keyword: quirks_mode"). Pinned for every version so the apps stay uniform.
gem "json", "< 3.0"

gem(*Lab::GemSource.from_env.gem_args)

group :development, :test do
  gem "rspec-rails"
  gem "capybara"
  gem "cuprite"
end
