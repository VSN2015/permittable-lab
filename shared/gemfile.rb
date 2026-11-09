# Evaluated from each app's Gemfile via eval_gemfile (added by shared/bin/patch_app.rb).
require File.expand_path("lib/lab/gem_source", __dir__)

# Rails 8.0.x (activesupport JSON encoding) passes `quirks_mode:` to JSON.generate, which json 3.x
# rejects ("unknown keyword: quirks_mode"). Pinned for Rails 8.0 only (LAB_RAILS is set per
# Compose service); 7.2 and 8.1 stay stock installs.
gem "json", "< 3.0" if ENV["LAB_RAILS"] == "8.0"

gem(*Lab::GemSource.from_env.gem_args)

group :development, :test do
  gem "rspec-rails"
  gem "capybara"
  gem "cuprite"
end
