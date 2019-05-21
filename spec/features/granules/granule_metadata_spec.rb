require 'rails_helper'

describe 'Granule metadata' do
  before do
    load_page :search, focus: 'C179003030-ORNL_DAAC'
    # Select a specific granule
    fill_in 'granule-ids', with: "FIFE_STRM_15M.80611715.s15\t"
    wait_for_xhr

    first_granule_list_item.click_link('View granule details')
    wait_for_xhr
    click_link 'Metadata'
    wait_for_xhr
  end

  it 'provides metadata in multiple formats' do
    expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC")]')
    expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.atom")]')
    expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.echo10")]')
    expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.iso19115")]')
    expect(page).not_to have_xpath('//a[contains(@href, "?token=")]')
  end

  context 'when a logged in user views granule metadata' do
    before do
      login
      wait_for_xhr
      click_link 'Metadata'
      wait_for_xhr
    end

    it 'provides metadata in multiple formats with user tokens' do
      expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC?token=")]')
      expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.atom?token=")]')
      expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.echo10?token=")]')
      expect(page).to have_xpath('//a[contains(@href, "https://cmr.earthdata.nasa.gov/search/concepts/G1422671947-ORNL_DAAC.iso19115?token=")]')
    end
  end
end
