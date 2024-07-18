require 'json'
require 'icalendar'
# tomato
# darkviolet
# deeppink
# deepskyblue
# gold
# yellowgreen
COLOR_MAP = {
  # Default Color should be neutral
  "Event" => "dodgerblue",
  # These are unused event types
  "DeliveryEvent" => "ghostwhite",
  "EventSeries" => "ghostwhite",
  "PublicationEvent" => "ghostwhite",
  "SaleEvent" => "ghostwhite",
  # learning events go together in gold color
  "BusinessEvent" => "gold",
  "CourseInstance" => "gold",
  "EducationEvent" => "gold",
  "Hackathon" => "gold",
  "ChildrensEvent" => "deeppink",
  "ComedyEvent" => "tomato",
  "DanceEvent" => "tomato",
  "ExhibitionEvent" => "lightsalmon" ,
  "Festival" => "lightsalmon",
  "FoodEvent" => "yellowgreen",
  "LiteraryEvent" => "mediumpurple",
  "MusicEvent" => "darkslateblue",
  "ScreeningEvent" => "lightskyblue",
  "SocialEvent" => "yellowgreen",
  "SportsEvent" => "darkorange",
  "TheaterEvent" => "lightskyblue",
  "VisualArtsEvent" => "lightskyblue"
}

def append_address_if_needed(str, obj, key)
  return unless obj.is_a? Hash
  if obj.has_key? key
    v = obj[key].to_s
    if v.is_a? String and v!="NA"
      # No point in adding KA/IN
      return if key == 'addressCountry' and v.length == 2
      return if key == 'addressRegion' and v.length == 2
      return if key == 'postalCode' and v.length != 6 # PIN in India are six digits
      unless str.downcase.include? v.downcase
        o = "#{str}, #{v}" if str.length > 0
        o = v if str.length == 0
        str.replace(o)
      end
    end
  end
end

# TODO: This would be simpler as a JSONNET transformation
def get_location_as_text(location) # takes schema.org/Event.location
  if location.is_a? String
    return location
  end

  base = ""
  return "Bangalore" if location.nil?
  if location['@type'] == 'Place' 
    append_address_if_needed(base, location, 'name')
    append_address_if_needed(base, location, 'address')
    if location['address'].is_a?(Hash) and location['address']['@type'] == 'PostalAddress'
      append_address_if_needed(base, location['address'], 'streetAddress')
      append_address_if_needed(base, location['address'], 'addressLocality')
      append_address_if_needed(base, location['address'], 'addressRegion')
      append_address_if_needed(base, location['address'], 'addressCountry')
    end
  end
  base
end

# Converts a valid schema.org/Event (or subclass)
# to a ICALENDAR object.
module Jekyll
  module ToIcal
    def to_ical(event_json)
      ics = Icalendar::Event.new
      event = JSON.parse event_json
      ics.color = COLOR_MAP[event['@type']]
      ics.description = event['description']
      # set geolocation if available in schema.org/Place
      if event['location'].is_a?(Hash) && event['location']['geo']
        ics.geo = event['location']['geo']['latitude'].to_s + ";" + event['location']['geo']['longitude'].to_s
      end
      ics.location = get_location_as_text(event['location']) if event['location']

      # if event['organizer'].is_a?(Hash) and event['organizer']['url'].is_a? String
      #   ics.organizer = Icalendar::Values::CalAddress.new(event['organizer']['url'], cn=event['organizer']['name'])
      # end
      ics.status = "CONFIRMED"
      ics.summary = event['name']
      ics.transp = "TRANSPARENT"
      ics.ip_class = "PUBLIC"
      ics.dtstart = Time.parse(event['startDate'])
      ics.dtend = Time.parse(event['endDate']) if event['endDate']
      # TODO: Improve
      ics.uid = "blr.today/#{event['url']}"

      ics.url = event['url']
      # # TODO: Move this to a method
      # if event['image']
      #   if event['image'].is_a? String
      #     if event['image'].start_with?('http')
      #       ics.attach Icalendar::Values::Uri.new(event['image'])
      #     else
      #       data = JSON.parse(event['image'])
      #       if data.is_a? Hash
      #         if data['@type'] == 'ImageObject'
      #           if data['image'].is_a? String
      #             ics.attach Icalendar::Values::Uri.new(data['image'])
      #           elsif data['url'].is_a? String
      #             ics.attach Icalendar::Values::Uri.new(data['url'])
      #           end
      #         end
      #       end
      #     end
      #     ics.attach Icalendar::Values::Uri.new(event['image'])
      #   end
        
      # end
      if event['keywords'].is_a? String
        ics.categories = event['keywords']
      end
      if event['keywords'].is_a? Array
        ics.categories = event['keywords'].join(",")
      end
      ics.to_ical
    end
  end
end

Liquid::Template.register_filter(Jekyll::ToIcal)