require 'rails_helper'

describe 'Direct download script SIT' do
  context 'when viewing the direct download script in SIT' do
    before :all do
      load_page :projects_page, env: :sit, project: ['C1000000082-EDF_OPS'], authenticate: 'edsc'
      choose('Direct Download')

      page.find_button('Download Data').click
      wait_for_xhr

      @sit_script_window = window_opened_by do
        click_link 'Download Access Script'
      end
    end

    it 'displays the correct URS path' do
      within_window(@sit_script_window) do
        expect(page.source).to have_content('machine sit.urs.earthdata.nasa.gov')
      end
    end
  end
end
