require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver :lab_cuprite do |app|
  Capybara::Cuprite::Driver.new(
    app,
    browser_path: ENV["BROWSER_PATH"],
    window_size: [1280, 900],
    browser_options: { "no-sandbox" => nil, "disable-gpu" => nil },
    process_timeout: 30
  )
end

Capybara.server = :puma, { Silent: true }
Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :lab_cuprite }
end
