# This script generates the file src/crystal/system/win32/zone_names.cr
# that contains mappings for windows time zone names based on the values
# found in http://unicode.org/cldr/data/common/supplemental/windowsZones.xml

require "http/client"
require "xml"
require "../src/compiler/crystal/formatter"

WINDOWS_ZONE_NAMES_SOURCE = "http://unicode.org/cldr/data/common/supplemental/windowsZones.xml"
TARGET_FILE               = File.join(__DIR__, "..", "src", "crystal", "system", "win32", "zone_names.cr")

response = HTTP::Client.get(WINDOWS_ZONE_NAMES_SOURCE)

# Simple redirection resolver
# TODO: Needs to be replaced by proper redirect handling that should be provided by `HTTP::Client`
if (300..399).includes?(response.status_code) && (location = response.headers["Location"]?)
  response = HTTP::Client.get(location)
end

xml = XML.parse(response.body)

nodes = xml.xpath_nodes("/supplementalData/windowsZones/mapTimezones/mapZone[@territory=001]")

entries = [] of {key: String, zones: {String, String}, tzdata_name: String}

nodes.each do |node|
  location = Time::Location.load(node["type"])
  next unless location
  time = Time.now(location).at_beginning_of_year
  zone1 = time.zone
  zone2 = (time + 6.months).zone

  if zone1.offset > zone2.offset
    # southern hemisphere
    zones = {zone2.name, zone1.name}
  else
    # northern hemisphere
    zones = {zone1.name, zone2.name}
  end

  entries << {key: node["other"], zones: zones, tzdata_name: location.name}
rescue err : Time::Location::InvalidLocationNameError
  pp err
end

# sort by IANA database identifier
entries.sort_by! &.[:tzdata_name]

hash_items = String.build do |io|
  entries.each do |entry|
    entry[:key].inspect(io)
    io << " => "
    entry[:zones].inspect(io)
    io << ", # " << entry[:tzdata_name] << "\n"
  end
end

source = <<-CRYSTAL
  # This file was automatically generated by running:
  #
  #   scripts/generate_windows_zone_names.cr
  #
  # DO NOT EDIT

  module Crystal::System::Time
    # These mappings for windows time zone names are based on
    # #{WINDOWS_ZONE_NAMES_SOURCE}
    WINDOWS_ZONE_NAMES = {
      #{hash_items}
    }
  end
  CRYSTAL

source = Crystal.format(source)

File.write(TARGET_FILE, source)