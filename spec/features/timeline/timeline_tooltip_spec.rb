require 'rails_helper'

describe "Timeline tooltip", pending_updates: true do
  before :all do
    Capybara.reset_sessions!
    page.current_window.resize_to(1280, 1024)
    load_page :search, focus: ['C179003030-ORNL_DAAC']
    pan_timeline(-16.days)
    wait_for_xhr
  end

  context "when viewing month zoom level" do
    it "displays a tooltip for timeline data" do
      script = '$($(".C179003030-ORNL_DAAC.timeline-data").children()[1]).trigger("mouseover");'
      page.execute_script(script)

      expect(page).to have_content("01 Oct 1987 to 05 Mar 1988")
    end
  end

  context "when viewing year zoom level" do
    before :all do
      find('.timeline-zoom-out').click
      wait_for_xhr
    end

    after :all do
      find('.timeline-zoom-in').click
      wait_for_xhr
    end

    it "displays a tooltip for timeline data" do
      script = '$($(".C179003030-ORNL_DAAC.timeline-data").children()[1]).trigger("mouseover");'
      page.execute_script(script)

      expect(page).to have_content("Oct 1987 to Apr 1988")
    end
  end

  context "when viewing decade zoom level" do
    before :all do
      find('.timeline-zoom-out').click
      find('.timeline-zoom-out').click
      wait_for_xhr
    end

    after :all do
      find('.timeline-zoom-in').click
      find('.timeline-zoom-in').click
      wait_for_xhr
    end

    it "displays a tooltip for timeline data" do
      script = '$($(".C179003030-ORNL_DAAC.timeline-data").children()[0]).trigger("mouseover");'
      page.execute_script(script)

      expect(page).to have_content("1984 to 1989")
    end
  end

  context "when viewing day zoom level" do
    before :all do
      find('.timeline-zoom-in').click
      wait_for_xhr
    end

    after :all do
      find('.timeline-zoom-out').click
      wait_for_xhr
    end

    it "displays a tooltip for timeline data" do
      script = '$($(".C179003030-ORNL_DAAC.timeline-data").children()[0]).trigger("mouseover");'
      page.execute_script(script)
      expect(page).to have_content("03 Jul 1987 13:08 GMT to 15 Aug 1987 01:00 GMT")
    end
  end
end
