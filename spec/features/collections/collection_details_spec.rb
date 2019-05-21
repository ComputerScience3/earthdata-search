require 'rails_helper'

describe 'Collection details' do
  context 'when displaying the collection details' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1000000004-EDF_DEV09', env: :sit, authenticate: 'edsc'
    end

    it 'those details provide the expected collection data' do
      within('#collection-details') do
        expect(page).to have_content('ASTER Expedited L1A Reconstructed Unprocessed Instrument Data V003')
        expect(page).to have_content("LP DAAC User Services\nARCHIVER")
        expect(page).to have_content("EDC\nPROCESSOR")
        expect(page).to have_content('AST_L1AE')
        expect(page).to have_content('VERSION 3')
        # expect(page).to have_content('lpdaac@usgs.gov Telephone: 605-594-6116')
        expect(page).to have_content('Bounding Rectangle: (90.0°, -180.0°, -90.0°, 180.0°)')
        expect(page).to have_content("Temporal Extent:\n1999-12-18 ongoing")
        expect(page).to have_content("Science Keywords:\nEARTH SCIENCE\nSPECTRAL/ENGINEERING\nINFRARED WAVELENGTHS\nEARTH SCIENCE\nSPECTRAL/ENGINEERING\nVISIBLE WAVELENGTHS")
      end
    end

    context 'when the For developers toggle is clicked' do
      before :all do
        click_on 'For developers'
      end

      it 'provides the metadata formats links' do
        expect(page).to have_link('Native')
        expect(page).to have_link('ATOM')
        expect(page).to have_link('ECHO10')
        expect(page).to have_link('ISO19115')
        expect(page).to have_link('DIF')
      end

      it 'provides the API Endpoints links' do
        expect(page).to have_link('CMR')
        expect(page).to have_link('OSDD')
      end
    end
  end

  context 'when selecting a collection that is only viewable after logging in' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1216393716-EDF_OPS', env: :uat, authenticate: 'edsc'
    end

    it 'displays the collection details' do
      within('#collection-details') do
        expect(page).to have_content('SMAP Enhanced L3 Radiometer Global Daily 9 km EASE-Grid Soil Moisture V001')
        expect(page).to have_content("EDF_OPS\nDISTRIBUTOR ARCHIVER")
        expect(page).to have_content('SPL3SMP_E')
        expect(page).to have_content('VERSION 001')
        expect(page).to have_content('Bounding Rectangle: (85.0445°, -180.0°, -85.0445°, 180.0°)')
        expect(page).to have_content("Temporal Extent:\n2015-03-31 to 2020-12-31")
        expect(page).to have_content("Science Keywords:\nEARTH SCIENCE\nLAND SURFACE\nSOILS")
      end
    end

    context 'when the For developers toggle is clicked' do
      before :all do
        click_on 'For developers'
      end

      it 'provides the metadata formats links' do
        expect(page).to have_link('Native')
        expect(page).to have_link('ATOM')
        expect(page).to have_link('ECHO10')
        expect(page).to have_link('ISO19115')
        expect(page).to have_link('DIF')
      end

      it 'provides the API Endpoints links' do
        expect(page).to have_link('CMR')
        expect(page).to have_link('OSDD')
      end
    end
  end

  context 'when selecting a collection without contacts in the xml' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1214560812-JAXA', ac: true
    end

    it 'displays the collection\'s detail page with no errors' do
      expect(page).to have_content("JP/JAXA/SAOC\nARCHIVER")
    end
  end

  context 'when selecting a collection with multiple temporal fields but some of which have only BeginningDateTime' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1214560374-JAXA', ac: true
    end

    it 'displays the correct title' do
      expect(page).to have_content('JAXA/EORC Tropical Cyclones database')
    end

    it 'displays all the temporal' do
      expect(page).to have_content('1997-12-07 to 2001-08-06')
      expect(page).to have_content('2001-08-25 ongoing')
    end
  end

  context 'when selecting a collection with multiple lines of description' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C197265171-LPDAAC_ECS'
    end

    it 'displays carriage returns in the description' do
      expect(page).to have_content(" (METI).\n\nASTER is capable of collecting in-")
    end
  end

  context 'when selecting a collection with a description with links' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1200230663-MMT_1', env: :sit, ac: true
    end

    it 'only displays one link total' do
      expect(page.find(:css, 'div.long-paragraph.collapsed')).to have_selector('a', count: 1)
    end

    it 'displays the external link' do
      expect(page).to have_link('Greenland Ice Mapping Project (GIMP)', href: 'http://nsidc.org/data/measures/gimp')
      expect(find_link('Greenland Ice Mapping Project (GIMP)')[:target]).to eq('_blank')
    end

    it 'does not display a link for relative paths' do
      expect(page).not_to have_link('Bad Link', href: '/data/measures/gimp')
    end
  end

  context 'when selecting a collection with multiple spatial values' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1214560151-JAXA', ac: true
    end

    it 'displays all spatial content' do
      expect(page).to have_content("Bounding Rectangle: (22.0°, -96.0°, -20.0°, -48.0°)\nBounding Rectangle: (10.0°, -14.0°, -9.0°, 34.0°)\nBounding Rectangle: (27.0°, 92.0°, -20.0°, 151.0°)")
    end
  end

  context 'when selecting a collection with multiple data centers' do
    before do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C179460405-LPDAAC_ECS'
    end

    it 'displays all data center content' do
      expect(page).to have_content("LP DAAC\nDISTRIBUTOR")
      expect(page).to have_content("JP/METI/AIST/JSS/GDS\nPROCESSOR")
    end
  end

  context 'when selecting a collection with temporal that doesn\'t have an end date or `ends at present` flag' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1443533440-LAADS'
    end

    it 'displays the temporal correctly' do
      expect(page).to have_content('2000-02-24 ongoing')
    end
  end

  context 'when selecting a collection with related urls' do
    before do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C1200230663-MMT_1', env: :sit, ac: true
    end

    it 'displays highlighted urls' do
      expect(collection_details).to have_content 'Data Set Landing Page'
      expect(collection_details).to have_content 'ATBD'
    end

    context 'when clicking View All Related URLs' do
      before do
        click_on 'View All Related URLs'
      end

      it 'displays all related urls grouped by URLContentType' do
        within '#related-urls-modal' do
          expect(page).to have_content 'Collection URL'
          expect(page).not_to have_content 'Collection URLs'
          expect(page).to have_content 'Publication URLs'
        end
      end

      it 'displays types and subtypes of related urls' do
        within '#related-urls-modal' do
          expect(page).to have_content "GET DATA\nLANCE"
        end
      end

      it 'displays urls in alphabetical order' do
        within '#related-urls-modal' do
          expect(page).to have_content "IEW RELATED INFORMATION\nhttp://www.usersguide.come\nVIEW RELATED INFORMATION\nALGORITHM THEORETICAL BASIS DOCUMENT\nhttps://www.example.com\nVIEW RELATED INFORMATION\nGENERAL DOCUMENTATION\nwww.lpdaac.org"
        end
      end

      it 'doesn\'t display EDSC or Reverb URLs' do
        within '#related-urls-modal' do
          expect(page).not_to have_content 'GET DATA EARTHDATA SEARCH'
          expect(page).not_to have_content 'GET DATA REVERB'
        end
      end
    end
  end

  context 'when selecting a collection without related urls' do
    before do
      mock_get_collection('collection_without_related_urls')
      load_page :search, q: 'C1234567890-EDSC'
      first_collection_result.click_link('View collection details')
      wait_for_xhr
    end

    it 'does not display option to view all related urls' do
      expect(collection_details).not_to have_content 'Related URLs:'
      expect(collection_details).not_to have_content 'View All Related URLs'
    end
  end

  context 'when selecting a collection with polygon spatial' do
    before :all do
      load_page :collection_details, focus: 'C1267331834-ASF'
    end

    it 'displays the spatial' do
      expect(page).to have_content('Polygon: ((89.99°, -179.999999°), (65.0°, -179.999999°), (65.0°, -90.0°), (65.0°, 0.0°), (65.0°, 90.0°), (65.0°, 179.999999°), (89.99°, 179.999999°), (89.99°, 90.0°), (89.99°, 0.0°), (89.99°, -90.0°), (89.99°, -179.999999°))')
    end
  end

  context 'when selecting a collection with invalid DOI field' do
    before :all do
      load_page :collection_details, focus: 'C1200235634-EDF_DEV06', env: :sit, ac: true, authenticate: 'edsc'
    end

    it 'displays the DOI and the Authority' do
      expect(page).to have_content('DOI')
      expect(page).to have_content('THE DIGITIAL OBJECT IDENTIFIER.')
      expect(page).not_to have_link('THE DIGITIAL OBJECT IDENTIFIER.')
    end
  end

  context 'when selecting a collection with a DOI field which contains "http://"' do
    before :all do
      load_page :collection_details, focus: 'C1200230663-MMT_1', env: :sit, ac: true, authenticate: 'edsc'
    end

    it 'updates the URL to contain "https://"" instead' do
      expect(page).to have_selector("a[href='https://dx.doi.org/10.5067/AQUA/AIRS/DATA301']")
    end
  end

  context 'when selecting a collection with valid DOI field' do
    before :all do
      Capybara.reset_sessions!
      load_page :collection_details, focus: 'C179003620-ORNL_DAAC'
    end

    it 'displays the DOI and the Authority' do
      expect(page).to have_content('DOI')
      expect(page).to have_content('10.3334/ORNLDAAC/830')
      expect(page).to have_link('10.3334/ORNLDAAC/830')
    end
  end
end
