require 'rails_helper'

describe 'Collection GIBS Filtering' do
  before :all do
    Capybara.reset_sessions!
    load_page :search, facets: true
  end

  context 'when selecting the GIBS filter' do
    before :all do
      find('.facets-item', text: 'Map Imagery').click
      wait_for_xhr
    end

    it 'shows only GIBS enabled collections' do
      expect(page).to have_css('.badge-gibs', count: 20)
    end

    context 'when un-selecting the GIBS filter' do
      before :all do
        find('.facets-item', text: 'Map Imagery').click
        wait_for_xhr
      end

      it 'shows all collections' do
        expect(page).to have_css('.circle-badge-gibs', count: 1)
      end
    end
  end

end
