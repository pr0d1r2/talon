require_relative 'rails_helper'

Dir[Rails.root.join('spec/feature/support/**/*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.include(FeatureHelpers)
end

require 'webdrivers/chromedriver'

SELENIUM_LOGGING_PREFS = {
  browser: 'ALL',
  client: 'ALL',
  driver: 'ALL',
  server: 'ALL'
}.freeze

SELENIUM_CHROME_OPTIONS_ARGS = %w[window-size=1920x1080].freeze

if ENV['HEADLESS']
  SELENIUM_CHROME_HEADLESS_OPTIONS_ARGS = (
    %w[headless disable-gpu] + SELENIUM_CHROME_OPTIONS_ARGS
  ).freeze

  Capybara.register_driver(:chrome) do |app|
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(
      chromeOptions: { args: SELENIUM_CHROME_HEADLESS_OPTIONS_ARGS, w3c: false },
      loggingPrefs: SELENIUM_LOGGING_PREFS
    )

    Capybara::Selenium::Driver.new(app, browser: :chrome, desired_capabilities: caps)
  end
else
  Capybara.register_driver(:chrome) do |app|
    caps = Selenium::WebDriver::Remote::Capabilities.chrome(
      chromeOptions: { args: SELENIUM_CHROME_OPTIONS_ARGS, w3c: false },
      loggingPrefs: SELENIUM_LOGGING_PREFS
    )

    Capybara::Selenium::Driver.new(app, browser: :chrome, desired_capabilities: caps)
  end
end

Capybara.javascript_driver = :chrome
