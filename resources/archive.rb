resource_name :zipr_archive

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing
property :exclude_files, [String, Array], default: [] # Array of relative_paths for files that should not be extracted or archived

# Compression properties
property :archive_type, Symbol, default: :zip # :zip, :seven_zip
property :target_files, [String, Array], default: [] # 7-zip wildcards allowed in windows

# Extraction properties
property :destination_folder, String
property :exclude_unless_missing, [String, Array], default: [] # Array of relative_paths for files that should not be extracted if they already exist

default_action :extract

action :extract do
  require 'digest'
  require 'json'
  extend ZiprHelper

  cache_folder = "#{::Chef::Config[:file_cache_path]}/zipr/"
  checksums_folder = "#{cache_folder}/archive_checksums"
  archive_name = ::File.basename(new_resource.archive_path)
  filepath_checksum = ::Digest::SHA256.hexdigest(new_resource.archive_path)[0..10]
  checksum_file = "#{checksums_folder}/#{archive_name}_#{filepath_checksum}"
  new_resource.exclude_files = [new_resource.exclude_files] if new_resource.exclude_files.is_a?(String)
  new_resource.exclude_unless_missing = [new_resource.exclude_unless_missing] if new_resource.exclude_unless_missing.is_a?(String)
  changed_files = nil # changed_files must be nil if the checksum file does not yet exist
  archive_checksums = {}

  if ::File.exist?(checksum_file)
    changed_files = []
    file_content = ::File.read(checksum_file)
    archive_checksums = JSON.parse(file_content)
    archive_checksums.each do |compressed_file, compressed_file_checksum|
      next if new_resource.exclude_files.grep(/#{compressed_file}/i)
      next if ::File.exist?("#{new_resource.destination_folder}/#{compressed_file}") &&
              (::Digest::SHA256.file("#{new_resource.destination_folder}/#{compressed_file}").hexdigest == compressed_file_checksum ||
              new_resource.exclude_unless_missing.grep(/#{compressed_file}/i))
      changed_files.push(compressed_file)
    end
    return if changed_files.empty?
  end

  converge_if_changed do
    raise "Failed to extract archive because the archive does not exist! Archive path: #{new_resource.archive_path}" unless ::File.exist?(new_resource.archive_path)
    require 'zip'
    extend ZiprHelper

    directory new_resource.destination_folder do
      action :create
      recursive true
    end

    calculated_checksums = extract_archive(new_resource.archive_path,
                                           new_resource.destination_folder,
                                           changed_files: changed_files,
                                           exclude_files: new_resource.exclude_files,
                                           exclude_unless_missing: new_resource.exclude_unless_missing,
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
  raise 'Unsupported OS platform!' unless node['platform'] == 'windows'
  extend ZiprHelper
  include_recipe 'seven_zip::default'
  zip_types = { zip: 'tzip', seven_zip: 't7z', sfx: 't7z' }
  file_list = new_resource.target_files.is_a?(String) ? "\"#{new_resource.target_files}\"" : "\"#{new_resource.target_files.join('" "')}\""
  file_list = '' if file_list == '""'
  exclude_list = new_resource.exclude_files.is_a?(String) ? "-x!\"#{new_resource.exclude_files}\"" : "-x!\"#{new_resource.exclude_files.join('" -x!"')}\""
  exclude_list = '' if exclude_list == '-x!""'

  execute "Create #{new_resource.archive_type} archive #{new_resource.archive_path}" do
    action :run
    command lazy { "\"#{seven_zip_exe}\" a -#{zip_types[new_resource.archive_type]} \"#{new_resource.archive_path}\" #{file_list} #{exclude_list}" }
  end

  # TODO: validate this works with 7zip wildcards
  if new_resource.delete_after_processing
    new_resource.target_files.each do |source_file|
      file source_file do
        action :delete
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
    delete_after_processing new_resource.delete_after_processing
    not_if { ::File.exist?(new_resource.archive_path) }
  end
end
