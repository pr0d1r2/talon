RSpec::Matchers.define :have_no_javascript_errors do
  match do |actual|
   error_messages(actual).size == 0
  end

  description do
    'have no javascript errors'
  end

  failure_message do |actual|
    [
      "expected that #{actual} would have no javascript errors, but there were:",
      error_messages(actual)
    ].flatten.join("\n")
  end

  def error_messages(page)
    @messages ||= actual.driver.browser.manage.logs.get(:browser).map(&:message).reject do |message|
      ignored_errors.any? { |ignored_error| message.include?(ignored_error) }
    end.uniq
  end

  def ignored_errors
    [
      'Download the React DevTools for a better development experience: https://fb.me/react-devtools'
    ]
  end
end
