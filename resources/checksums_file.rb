unified_mode true if respond_to?(:unified_mode)

# Common properties
property :checksum_file_path, String, name_property: true # Compressed file path
property :checksums, Hash, required: true

default_action :create

action :create do
  directory ::File.dirname(new_resource.checksum_file_path) do
    action :create
    recursive true
  end

  file new_resource.checksum_file_path do
    action :create
    content new_resource.checksums.to_json
  end
end

action :create_if_missing do
  zipr_checksums_file "Create if missing: #{new_resource.checksum_file_path}" do
    action :create
    checksums new_resource.checksums
    checksum_file_path new_resource.checksum_file_path
    not_if { ::File.exist?(new_resource.checksum_file_path) }
  end
end
