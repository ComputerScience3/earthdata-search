require 'nokogiri'
require 'open-uri'
require 'json'

module Colormaps
  def self.load(products = nil)
    puts 'Loading GIBS colormap data...'

    # Destroy all current colormaps to prevent orphaned records
    Colormap.destroy_all

    # We need to process the GetCapabilities files for each projection, as some products do not appear in
    # the Geographic projection
    gibs_urls = [
      'https://gibs.earthdata.nasa.gov/wmts/epsg4326/best/wmts.cgi?SERVICE=WMTS&request=GetCapabilities',
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/wmts.cgi?SERVICE=WMTS&request=GetCapabilities',
      'https://gibs.earthdata.nasa.gov/wmts/epsg3413/best/wmts.cgi?SERVICE=WMTS&request=GetCapabilities',
      'https://gibs.earthdata.nasa.gov/wmts/epsg3031/best/wmts.cgi?SERVICE=WMTS&request=GetCapabilities'
    ]

    file_count = 0
    error_count = 0

    gibs_urls.each do |gibs_url|
      capabilities_str = open(gibs_url).read
      # This xmlns was breaking xpath queries
      capabilities_file = Nokogiri::XML(capabilities_str.sub('xmlns="http://www.opengis.net/wmts/1.0"', ''))

      layers = capabilities_file.xpath('/Capabilities/Contents/Layer')
      layers.each do |layer|
        id = layer.xpath('./ows:Identifier').first.content.to_s

        next unless products.nil? || products.include?(id)

        # get v1.3 role metadata node
        target = layer.xpath("./ows:Metadata[contains(@xlink:role, '1.3')]")
        url = if target.empty?
                # not upgraded yet, layer does not have a metadata node with xlink:role v1.3,
                # so try to use url from another metadata node (no version or v1.0)
                layer.xpath('./ows:Metadata/@xlink:href').to_s
              else
                target.attribute('href').to_s
              end

        url = url.gsub(/^http:/, 'https:')

        colormap = Colormap.find_or_initialize_by(product: id)

        next if id.empty? || url.empty? || !url.start_with?('http') || colormap.persisted?

        file_count += 1
        result = Colormaps.xml_to_json(colormap, url)
        error_count += 1 unless result
      end
    end

    puts "#{error_count} error(s), #{file_count} file(s)"

    error_count
  end

  # This method takes a XML formatted GIBS colormap and converts it to JSON format
  # https://github.com/nasa-gibs/worldview/blob/12ac2e188048c1d32a858f68b2eaac85852462d6/bin/wv-options-colormap
  # colormap: Colormap object initialized with an ID. Used to name JSON file. (MODIS_Terra_NDSI_Snow_Cover)
  # url: GIBS URL for XML colormap. (https://gibs.earthdata.nasa.gov/colormaps/v1.3/MODIS_Terra_NDSI_Snow_Cover.xml)
  def self.xml_to_json(provided_colormap, url)
    xml_file = open(url).read
    xml = Nokogiri::XML(xml_file)

    scale_colors   = []
    scale_labels   = []
    scale_values   = []
    class_colors   = []
    class_labels   = []
    special_colors = []
    special_labels = []

    colormaps = xml.xpath('//ColorMaps/ColorMap')

    # Strip out colormap data that isn't necessary to generate our json files
    colormaps_to_ignore = ['No Data', 'Classification', 'Classifications']
    colormaps_to_ignore.each do |ignored_colormap_title|
      colormap_to_delete = colormaps.find { |cmap| cmap.attribute('title').to_s == ignored_colormap_title && cmap.xpath('./Entries[not(@*)]') }
      colormaps.delete(colormap_to_delete) unless colormap_to_delete.nil?
    end

    return if colormaps.nil?

    colormaps.each do |colormap|
      # Pull the units of measurement for the colormap data
      units = colormap.attribute('units')

      entries = colormap.xpath('./Entries/ColorMapEntry')
      entries.each do |entry|
        r, g, b = entry.attribute('rgb').to_s.split(',')
        a = 255
        a = 0 if entry.attribute('transparent') && entry.attribute('transparent') == 'true'
        color = "#{str_to_hex(r)}#{str_to_hex(g)}#{str_to_hex(b)}#{str_to_hex(a)}"
        ref = entry.attribute('ref').value

        # v1.3 moved the `label` out of the ColorMapEntry into Legend/LegendEntry['tooltip']
        legend_entry = colormap.xpath("./Legend/LegendEntry[@id='#{ref}']")

        # Only process entries with legend entries
        next if legend_entry.blank?

        label = legend_entry.attribute('tooltip')

        if a == 0
          # transparent
          special_colors << color
          special_labels << label
        elsif entry.attribute('value')
          items = entry.attribute('value').to_s.gsub(/[\(\)\[\]]/, '').split(',')
          begin
            items.each do |scale_value|
              v = scale_value.to_f
              v = Float::MAX if v == Float::INFINITY
              v = Float::MIN if v == -Float::INFINITY
              scale_values << v
            end
          rescue ValueError
            raise "Invalid value: {entry.attribute('value').to_s}"
          end
          scale_colors << color
          scale_labels << "#{label} #{units}"
        else
          class_colors << color
          class_labels << "#{label} #{units}"
        end
      end

      data = {}
      unless scale_colors.empty?
        data['scale'] = {}
        data['scale']['colors'] = scale_colors
        data['scale']['values'] = scale_values
        data['scale']['labels'] = scale_labels
      end
      unless special_colors.empty?
        data['special'] = {}
        data['special']['colors'] = special_colors
        data['special']['labels'] = special_labels
      end
      unless class_colors.empty?
        data['classes'] = {}
        data['classes']['colors'] = class_colors
        data['classes']['labels'] = class_labels
      end
      data['id'] = provided_colormap.product

      provided_colormap.jsondata = data
      provided_colormap.url      = url

      provided_colormap.save!
    end

    return true
  rescue Exception => e
    # GIBS-876: GIBS serves up two URLs that are 404.  We need to cope with these.
    error_type = e.message == '404 Not Found' ? 'Warning' : 'Error'
    puts "#{error_type} [#{url}]: #{e.message}"
    return error_type == 'Warning'
  end

  def self.str_to_hex(str)
    str.to_i.to_s(16).rjust(2, '0')
  end
end
