module HarvardAeon
  class ArchivalObjectMapper < ItemMapper

    RequestList.register_item_mapper(self, :harvard_aeon, ArchivalObject)

    def map(item)
      resource = JSON.parse(item.resolved_resource['json'])

      shared_fields = {
        'Site' => repo_field_for(item, 'Site'),
        'ItemInfo2' => hollis_number_for(resource),
        'ItemTitle' => strip_mixed_content(resource['title']),
        'SubItemTitle' => strip_mixed_content(item['title']),
        'ItemAuthor' => (item.resolved_resource["creators"] || []).join('; '), 
        'ItemDate' => creation_date_for(item['json']),
        'Location' => repo_field_for(item, 'Location'),
        'SubLocation' => physical_location_for(item['json']),
        'CallNumber' => item.resolved_resource['identifier'],
        'ItemPlace' => access_restrictions_for(resource), # actually any level - inheritance?
      }

      containers = containers_for(item)
      return [with_request_number(shared_fields)] if containers.empty?

      containers.map {|c|
        with_request_number(with_mapped_container(shared_fields, c))
      }
    end

  end
end