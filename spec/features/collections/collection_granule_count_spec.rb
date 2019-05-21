require 'rails_helper'

describe 'Collection Granule Count' do
  before :all do
    Capybara.reset_sessions!
    load_page :search, q: 'C1002-LPDAAC_TBD', env: :sit
  end

  it 'displays many granules for the given collection' do
    expect(page). to have_content('2,149 Granules')
  end

  context 'when applying search constraint' do
    before :all do
      click_link 'Temporal'
      fill_in 'Start', with: "2014-12-01 00:00:00\t"
      js_click_apply '.temporal-dropdown'
      wait_for_xhr
    end

    it 'displays an updated granule count' do
      expect(page).to have_content('0 Matching Collections')
    end
  end
end
