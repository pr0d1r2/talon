module FeatureHelpers
  def expect_to_see_auth_form(type)
    expect(page).to have_no_javascript_errors
    expect(page).to have_selector("##{type}.authcard")
  end

  def visit_root
    visit '/'
    expect(page).to have_no_javascript_errors
  end
end
