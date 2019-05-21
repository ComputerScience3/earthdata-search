require 'rails_helper'

describe 'Displaying system errors' do
  context 'when a system error occurs' do
    before :all do
      Capybara.reset_sessions!
      load_page :search
      fill_in 'keywords',	with: 'trigger500'
    end

    it 'displays an error message containing the type of request that caused the error' do
      expect(page.find('.banner-error')).to have_text('Error retrieving collections')
    end

    it 'displays the readable message from the server, if available' do
      expect(page).to have_text('Some error string')
    end

    context 'and the user performs a subsequent successful request' do
      before :all do
        click_on 'Clear Filters'
        wait_for_xhr
      end

      after :all do
        fill_in 'keywords', with: 'trigger500'
      end

      it 'removes the error message' do
        expect(page).to have_no_text('Error retrieving collections')
      end
    end
  end

  context 'when invalid parameters are entered' do
    before :all do
      Capybara.reset_sessions!
      load_page :search, focus: 'C1000000029-EDF_OPS', env: :sit, queries: [{ id: '*foo!*foo2!*foo3' }], close_banner: false
    end

    it 'displays an error message containing the type of request that caused the error' do
      expect(page.find('.banner-error')).to have_text('Error retrieving granules')
    end

    it 'displays the readable message from the server, if available' do
      expect(page).to have_text('The query contained 3 conditions which used a leading wildcard')
    end
  end
end
