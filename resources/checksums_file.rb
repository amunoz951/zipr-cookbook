resource_name :zipr_checksums_file

# Common properties
property :checksum_file_path, String, name_property: true # Compressed file path
property :archive_checksums, Hash, required: true
# property :temp_folder, String, required: true

default_action :create

action :create do
  directory ::File.dirname(new_resource.checksum_file_path) do
    action :create
    recursive true
  end

  file new_resource.checksum_file_path do
    action :create
    content new_resource.archive_checksums.to_json
  end
end

action :create_if_missing do
  zipr_checksums_file "Create if missing: #{new_resource.checksum_file_path}" do
    action :create
    archive_checksums new_resource.archive_checksums
    checksum_file_path new_resource.checksum_file_path
    not_if { ::File.exist?(new_resource.checksum_file_path) }
  end
end
