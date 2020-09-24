require 'feature_helper'

RSpec.feature "Search", type: :feature, js: true do
  scenario "shows form" do
    visit_root
    expect(page).to have_selector("#search form input")
  end

  scenario "clear button" do
    visit_root
    expect(page).not_to have_selector("#search form .clearbtn")

    fill_in "url", with: "test"
    expect(page).to have_selector("#search form .clearbtn")

    expect(page).to have_selector("#search form input[value='test']")
    find("#search form .clearbtn").click
    expect(page).to have_selector("#search form input[value='']")
  end

  scenario "shows error when inputting invalid URL" do
    visit_root
    fill_in "url", with: "test"
    find('#search form input').native.send_key(:enter)
    expect(page).to have_selector("#errormodal", text: "Invalid URL")
  end

  scenario "Adds correctly formatted video URL to list" do
    url = "https://www.youtube.com/watch?v=8X8QfZYdx3s"
    info = JSON.parse(file_fixture("video.json").read)

    visit_root
    fill_in "url", with: url
    find('#search form input').native.send_key(:enter)
    YoutubeDL.expects(:info).twice.with(url).returns(info)
    expect(page).to have_selector('#preview .dialog')
    find("#preview .dialog .startbtn").click
    expect(page).to have_selector('.downloadlist .download', count: 1)
    expect(page).to have_selector('.downloadlist .download h1', text: info["title"])
  end
end
