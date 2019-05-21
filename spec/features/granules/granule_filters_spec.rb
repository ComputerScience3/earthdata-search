require 'rails_helper'

describe 'Granule search filters' do
  context 'for granules that can be filtered by day/night flag or cloud cover' do
    before_granule_count = 0
    before(:each) do
      # Labs parameter enables additional attribute searching
      load_page :search, focus: 'C14758250-LPDAAC_ECS', labs: true, temporal: ['1999-12-01T00:00:00Z', '2015-01-01T00:00:00Z']
      click_on 'Granule filters'
      wait_for_xhr
      number_granules = search_results_granule_count.text.match(/\d{1,3}(,\d{3})*(\.\d+)? Granules/)
      before_granule_count = number_granules.to_s.split(' ')[0]
    end

    context 'when choosing a day/night flag' do
      it 'selecting day returns day granules' do
        select 'Day only', from: 'day-night-select'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      end

      it 'selecting night returns night granules' do
        select 'Night only', from: 'day-night-select'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      end

      it 'selecting both returns both day and night granules' do
        select 'Both day and night', from: 'day-night-select'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      end

      it 'clicking the clear button selects Anytime' do
        select 'Day only', from: 'day-night-select'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)

        click_button 'granule-filters-clear'
        expect(search_results_granule_count).to reset_granules_to(before_granule_count)
        expect(page).to have_select('day-night-select', selected: 'Anytime')
      end
    end

    context 'when choosing cloud cover' do
      it 'filters with both min and max' do
        fill_in 'Minimum:', with: '2.5'
        fill_in 'Maximum:', with: "5.0\t"
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'filters with only min' do
        fill_in 'Minimum:', with: "2.5\t"
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'filters with only max' do
        fill_in 'Maximum:', with: "5.0\t"
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'clicking the clear button clears minimum and maximum' do
        fill_in 'Minimum:', with: '2.5'
        fill_in 'Maximum:', with: "5.0\t"
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)

        click_button 'granule-filters-clear'
        expect(search_results_granule_count).to reset_granules_to(before_granule_count)
        expect(page).to have_field('Minimum', with: '')
        expect(page).to have_field('Maximum', with: '')
      end

      it "entering and removing values doesn't set invalid query param in the url" do
        fill_in 'Minimum:', with: '2.5'
        page.find('.master-overlay-secondary-content').click
        wait_for_xhr

        fill_in 'Minimum:', with: ''
        expect(page).to have_field('Minimum', with: '')

        page.execute_script('$("#cloud-cover-min").trigger("change"); null;')
        page.find('.master-overlay-secondary-content').click
        click_button 'Apply'
        wait_for_xhr

        expect(current_url).not_to have_content('pg[1][cc][min]')
        click_on 'Granule filters'
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      context 'validates input' do
        after :each do
          click_button 'granule-filters-clear'
          wait_for_xhr
        end

        it 'minimum must be more than 0.0' do
          fill_in 'Minimum', with: '-1.0'
          fill_in 'Maximum', with: ''
          page.find('.master-overlay-secondary-content').click
          wait_for_xhr
          expect(page).to have_content 'Value must be between 0.0 and 100.0'
        end

        it 'maximum must be less than 100.0' do
          fill_in 'Minimum', with: ''
          fill_in 'Maximum', with: '110.0'
          page.find('.master-overlay-secondary-content').click
          wait_for_xhr
          expect(page).to have_content 'Value must be between 0.0 and 100.0'
        end

        it 'minimum must be less than maximum' do
          fill_in 'Minimum', with: '5.0'
          page.find('.master-overlay-secondary-content').click
          wait_for_xhr
          fill_in 'Maximum', with: '1.0'
          page.find('.master-overlay-secondary-content').click
          wait_for_xhr
          expect(page).to have_content 'Minimum must be less than Maximum'
        end
      end
    end

    context 'when choosing data access options' do
      it 'selecting browse only loads granules with browse images' do
        check 'Find only granules that have browse images.'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      end

      it 'selecting online only loads downloadable granules' do
        check 'Find only granules that are available online.'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      end

      it 'clicking the clear button unchecks data access options' do
        check 'Find only granules that have browse images.'
        check 'Find only granules that are available online.'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)

        click_button 'granule-filters-clear'
        expect(search_results_granule_count).to reset_granules_to(before_granule_count)
        expect(page).to have_unchecked_field('Find only granules that have browse images.')
        expect(page).to have_unchecked_field('Find only granules that are available online.')
      end
    end

    context 'when excluding by granule id' do
      before :each do
        first_granule_list_item.click_link 'Remove granule'
      end

      after :each do
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'displays an indication that granules have been excluded' do
        expect(page).to have_content('1 granule has been removed from your results')
      end

      it 'removes the granule from the granule list' do
        expect(page).to have_css('#granule-list .panel-list-item', count: 19)
      end

      it "updates the page's hits count" do
        expect(granule_list).to have_content("Showing 19 of #{ActiveSupport::NumberHelper.number_to_delimited(before_granule_count.delete(',').to_i - 1)} matching granules")
      end

      context 'when the user clicks the link to clear removed granules' do
        before :each do
          click_on 'Add it back'
          wait_for_xhr
        end

        after :each do
          first_granule_list_item.click
          first_granule_list_item.click_link 'Remove granule'
          wait_for_xhr
        end

        it 'includes the excluded granules in the list' do
          expect(page).to have_css('#granule-list .panel-list-item', count: 20)
        end

        it 'updates the granule hits count' do
          expect(page).to have_content("Showing 20 of #{before_granule_count} matching granules")
        end
      end
    end

    context 'when searching by temporal' do
      it 'selecting temporal range filters granules' do
        js_uncheck_recurring 'granule'
        click_button 'granule-filters-clear'
        wait_for_xhr
        fill_in 'Start', with: "2013-12-01 00:00:00\t"
        fill_in 'End', with: "2013-12-31 00:00:00\t"
        js_click_apply '.master-overlay-content'
        wait_for_xhr
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        js_uncheck_recurring 'granule'
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'selecting temporal recurring filters granules' do
        js_check_recurring 'granule'
        fill_in 'Start', with: "12-01 00:00:00\t"
        fill_in 'End', with: "12-31 00:00:00\t"
        script = 'edsc.page.project.searchGranulesCollection().granuleDatasource().cmrQuery().temporal.pending.years([2005, 2010])'
        page.execute_script(script)
        js_click_apply '.master-overlay-content'
        click_button 'Apply'
        wait_for_xhr
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        click_on 'Granule filters'
        js_uncheck_recurring 'granule'
        click_button 'granule-filters-clear'
        wait_for_xhr
      end

      it 'clicking the clear button clears temporal fields' do
        js_uncheck_recurring 'granule'
        click_button 'granule-filters-clear'
        wait_for_xhr
        fill_in 'Start', with: "2013-12-01 00:00:00\t"
        fill_in 'End', with: "2013-12-31 00:00:00\t"
        js_click_apply '.master-overlay-content'
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)

        click_button 'granule-filters-clear'
        expect(search_results_granule_count).to reset_granules_to(before_granule_count)
        expect(page).to have_field('Start', with: '')
        expect(page).to have_field('End', with: '')
      end
    end

    it 'shows collection additional attributes' do
      expect(page).to have_text('Collection-Specific Attributes')
      expect(page).to have_field('ASTERMapProjection')
    end

    context 'when searching by additional attributes' do
      before(:each) do
        load_page :search, focus: ['C14758250-LPDAAC_ECS'], labs: true, temporal: ['1999-12-01T00:00:00Z', '2015-01-01T00:00:00Z']
        click_on 'Granule filters'
        fill_in('DAR_ID', with: '')
        wait_for_xhr
        fill_in('LowerLeftQuadCloudCoverage', with: "50 - 100\t")
        wait_for_xhr
      end

      it 'filters granules using the additional attribute values' do
        click_button 'Apply'
        wait_for_xhr
        expect(search_results_granule_count).to filter_granules_from(before_granule_count)
        click_on 'Granule filters'
      end

      context 'when clearing the attribute search' do
        before(:all) do
          click_button 'granule-filters-clear'
          wait_for_xhr
        end

        it 'clears the attribute search field' do
          expect(page).to have_field('LowerRightQuadCloudCoverage', with: '')
        end

        it 'resets the granule search' do
          click_button 'Apply'
          wait_for_xhr
          expect(search_results_granule_count).to filter_granules_from(before_granule_count)
          click_on 'Granule filters'
        end
      end
    end
  end

  context "for granules that can't be filtered by day/night flag or cloud cover" do
    before :all do
      load_page :search, focus: ['C1236224182-GES_DISC']
      click_on 'Granule filters'
    end

    it "day/night flag or cloud cover don't show up in the filter panel" do
      expect(page).not_to have_content('Day / Night Flag')
      expect(page).not_to have_content('Find granules captured during the day, night or anytime.')

      expect(page).not_to have_content('Cloud Cover')
      expect(page).not_to have_content('Find granules by cloud cover percentage.')
    end
  end

  context 'When specifying a collection level project/campaign param' do
    before :all do
      load_page :search, facets: true, q: 'C1000000062-NSIDC_ECS'
      find('h3.panel-title', text: 'Projects').click
      within '.projects' do
        first('.facets-item').click
      end
      wait_for_xhr
      first_collection_result.click
      wait_for_xhr
    end

    it 'the param is carried over to the granule search' do
      expect(page.current_url).to include('pg[0][project]=')
    end
  end

  context 'for granules that cannot be filtered by orbit spatial parameters' do
    before(:all) do
      # Labs parameter enables additional attribute searching
      load_page :search, focus: ['C14758250-LPDAAC_ECS'], labs: true, temporal: ['1999-12-01T00:00:00Z', '2015-01-01T00:00:00Z']
      click_on 'Granule filters'
    end

    it 'does not show the orbit spatial parameters in the granule filter list' do
      expect(page).to_not have_content('Orbit Spatial Parameters')
    end
  end

  context 'for granules that can be filtered by orbit spatial parameters' do
    before_granule_count = 0
    before(:each) do
      load_page :search, focus: ['C1000001167-NSIDC_ECS'], labs: true
      click_on 'Granule filters'

      number_granules = search_results_granule_count.text.match(/\d{1,3}(,\d{3})*(\.\d+)? Granules/)
      before_granule_count = number_granules.to_s.split(' ')[0]
    end

    it 'shows the orbit spatial parameters in the granule filter list' do
      expect(page).to have_content('Orbit Spatial Parameters')
    end

    it 'filters when only the orbit number min is set' do
      fill_in 'Orbit Number Min:', with: '30000'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][on][min]=30000')
    end

    it 'filters when only the orbit number max is set' do
      fill_in 'Orbit Number Max:', with: '30009'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][on][max]=30009')
    end

    it 'filters when the orbit number min and max are set' do
      fill_in 'Orbit Number Min:', with: '30000'
      fill_in 'Orbit Number Max:', with: '30009'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][on][min]=30000&pg[0][on][max]=30009')
    end

    it 'filters when only the equatorial crossing longitude min is set' do
      fill_in 'Equatorial Crossing Longitude Min:', with: '-45'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecl][min]=-45')
    end

    it 'filters when only the equatorial crossing longitude max is set' do
      fill_in 'Equatorial Crossing Longitude Max:', with: '-40'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecl][max]=-40')
    end

    it 'filters when the equatorial crossing longitude min and max are set' do
      fill_in 'Equatorial Crossing Longitude Min:', with: '-45'
      fill_in 'Equatorial Crossing Longitude Max:', with: '-40'
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecl][min]=-45&pg[0][ecl][max]=-40')
    end

    it 'filters when only the equatorial crossing date start time is set' do
      page.execute_script("$('#equatorial-crossing-date-min').datepicker('setDate', '2015-01-24')")
      page.execute_script('$("#granule-filters-submit").click()')
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecd][min]=2015-01-24T00%3A00%3A00')
    end

    it 'filters when only the equatorial crossing date end time is set' do
      page.execute_script("$('#equatorial-crossing-date-max').datepicker('setDate', '2015-01-25')")
      page.execute_script('$("#granule-filters-submit").click()')
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecd][max]=2015-01-25T23%3A59%3A59')
    end

    it 'filters when the equatorial crossing date start and end times are set' do
      page.execute_script("$('#equatorial-crossing-date-min').datepicker('setDate', '2015-01-24')")
      page.execute_script("$('#equatorial-crossing-date-max').datepicker('setDate', '2015-01-25')")
      page.find('.master-overlay-secondary-content').click
      click_button 'Apply'
      expect(search_results_granule_count).to filter_granules_from(before_granule_count)
      expect(page).to have_query_string('labs=true&p=C1000001167-NSIDC_ECS&pg[0][ecd][min]=2015-01-24T00%3A00%3A00&pg[0][ecd][max]=2015-01-25T23%3A59%3A59')
    end

    it 'loads the orbit number fields correctly when read from URL parameters' do
      load_page 'search/granules?p=C1000001167-NSIDC_ECS&pg[0][on][min]=30000&pg[0][on][max]=30009&m=-1.4765625!-19.23046875!3!1!0!0%2C2&tl=1487536527!4!!&q=C1000001167-NSIDC_ECS&ok=C1000001167-NSIDC_ECS'
      click_on 'Granule filters'
      expect(find('#orbit-number-min').value).to eql('30000')
      expect(find('#orbit-number-max').value).to eql('30009')
    end

    it 'loads the equatorial crossing longitude fields correctly when read from URL parameters' do
      load_page 'search/granules?p=C1000001167-NSIDC_ECS&pg[0][ecl][min]=-45&pg[0][ecl][max]=-40&m=-1.546875!-19.23046875!3!1!0!0%2C2&tl=1487536527!4!!&q=C1000001167-NSIDC_ECS&ok=C1000001167-NSIDC_ECS'
      click_on 'Granule filters'
      expect(find('#equatorial-crossing-longitude-min').value).to eql('-45')
      expect(find('#equatorial-crossing-longitude-max').value).to eql('-40')
    end

    it 'loads the equatorial crossing date fields correctly when read from URL parameters' do
      load_page 'search/granules?p=C1000001167-NSIDC_ECS&pg[0][ecd][min]=2015-01-24T00%3A00%3A00&pg[0][ecd][max]=2015-01-25T23%3A59%3A59&m=-1.546875!-19.23046875!3!1!0!0%2C2&tl=1487536527!4!!&q=C1000001167-NSIDC_ECS&ok=C1000001167-NSIDC_ECS'
      click_on 'Granule filters'
      expect(find('#equatorial-crossing-date-min').value).to eql('2015-01-24T00:00:00')
      expect(find('#equatorial-crossing-date-max').value).to eql('2015-01-25T23:59:59')
    end
  end
end
