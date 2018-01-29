resource_name :zipr_archive

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing
property :exclude_files, [String, Array], default: [] # Array of relative_paths for files that should not be extracted or archived

# Compression properties
property :archive_type, Symbol, default: :zip # :zip, :seven_zip
property :target_files, [String, Array], default: [] # 7-zip wildcards allowed in windows
property :source_folder, String

# Extraction properties
property :destination_folder, String
property :exclude_unless_missing, [String, Array], default: [] # Array of relative_paths for files that should not be extracted if they already exist

default_action :extract

action :extract do
  require 'digest'
  require 'json'
  extend ZiprHelper
  standardize_properties(new_resource)

  checksums_folder = "#{::Chef::Config[:file_cache_path]}/zipr/archive_checksums"
  archive_name = ::File.basename(new_resource.archive_path)
  filepath_checksum = ::Digest::SHA256.hexdigest(new_resource.archive_path)[0..10]
  checksum_file = "#{checksums_folder}/#{archive_name}_#{filepath_checksum}.json"
  changed_files, archive_checksums = changed_files_for_extract(checksum_file,
                                                               new_resource.destination_folder,
                                                               new_resource.exclude_files,
                                                               new_resource.exclude_unless_missing)
  return if !changed_files.nil? && changed_files.empty?

  converge_if_changed do
    raise "Failed to extract archive because the archive does not exist! Archive path: #{new_resource.archive_path}" unless ::File.exist?(new_resource.archive_path)
    include_recipe 'zipr::default' if Gem::Version.new(Chef::VERSION) < Gem::Version.new('13.0.0')
    require 'zip'

    directory new_resource.destination_folder do
      action :create
      recursive true
    end

    calculated_checksums = extract_archive(new_resource.archive_path,
                                           new_resource.destination_folder,
                                           changed_files,
                                           archive_checksums: archive_checksums,
                                           archive_type: new_resource.archive_type)

    zipr_checksums_file checksum_file do
      archive_checksums calculated_checksums
    end

    file "delete #{new_resource.archive_path}" do
      action :delete
      path new_resource.archive_path
      only_if { new_resource.delete_after_processing }
    end
  end
end

action :create do
  require 'digest'
  require 'json'
  extend ZiprHelper
  standardize_properties(new_resource)

  checksums_folder = "#{::Chef::Config[:file_cache_path]}/zipr/archive_checksums"
  archive_name = ::File.basename(new_resource.archive_path)
  filepath_checksum = ::Digest::SHA256.hexdigest(new_resource.archive_path)[0..10]
  checksum_file = "#{checksums_folder}/#{archive_name}_#{filepath_checksum}.json"
  changed_files, archive_checksums = changed_files_for_add_to_archive(checksum_file,
                                                                      new_resource.source_folder,
                                                                      new_resource.target_files,
                                                                      new_resource.exclude_files,
                                                                      new_resource.exclude_unless_missing)
  return if changed_files.empty?

  converge_if_changed do
    include_recipe 'zipr::default' if Gem::Version.new(Chef::VERSION) < Gem::Version.new('13.0.0')
    require 'zip'
    calculated_checksums = add_to_archive(new_resource.archive_path,
                                          new_resource.source_folder,
                                          changed_files,
                                          archive_checksums: archive_checksums,
                                          archive_type: new_resource.archive_type)

    zipr_checksums_file checksum_file do
      archive_checksums calculated_checksums
    end

    # TODO: validate this works with 7zip wildcards
    if new_resource.delete_after_processing
      new_resource.changed_files.each do |changed_file|
        file changed_file do
          action :delete
        end
      end
    end
  end
end

action :create_if_missing do
  zipr_archive "Create if missing: #{new_resource.archive_path}" do
    action :create
    archive_path new_resource.archive_path
    archive_type new_resource.archive_type
    exclude_files new_resource.exclude_files
    target_files new_resource.target_files
    source_folder new_resource.source_folder
    delete_after_processing new_resource.delete_after_processing
    not_if { ::File.exist?(new_resource.archive_path) }
  end
end

def standardize_properties(new_resource)
  new_resource.exclude_files = [new_resource.exclude_files] if new_resource.exclude_files.is_a?(String)
  new_resource.exclude_unless_missing = [new_resource.exclude_unless_missing] if new_resource.exclude_unless_missing.is_a?(String)
  new_resource.target_files = [new_resource.target_files] if new_resource.target_files.is_a?(String)
end
