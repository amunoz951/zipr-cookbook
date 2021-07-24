resource_name :zipr_archive

# Note: You may use a :before notification to download the archive before extraction. You may then delete it afterwards and it will stay idempotent.
#       If you do use a :before notification, you must include the zipr::dependencies recipe before declaring your resource.

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing
property :checksum_file, [String, nil], default: nil # Specify a custom checksum file path
property :exclude_files, [String, Regexp, Array], default: [] # Array of relative_paths for files that should not be extracted or archived
property :exclude_unless_missing, [String, Regexp, Array], default: [] # Array of relative_paths for files that should not be extracted or archived if they already exist

# Compression properties
property :archive_type, Symbol, default: lazy { |r| r.archive_path[-3..-1] =~ /.7z/i ? :seven_zip : :zip } # :zip, :seven_zip
property :target_files, [String, Array], default: [] # Dir.glob wildcards allowed
property :source_folder, String, default: ''

# Extraction properties
property :destination_folder, String
property :password, [String, nil], default: nil # Password for archive

default_action :extract

action :extract do
  new_resource.sensitive = true unless new_resource.password.nil?
  raise 'destination_folder is a required property for action: :extract' if new_resource.destination_folder.nil?
  standardize_properties(new_resource)
  ZiprHelper.load_zipr_dependencies(new_resource)

  archive_name = ::File.basename(new_resource.archive_path)
  archive_path_hash = ::Digest::SHA256.hexdigest(new_resource.archive_path + new_resource.destination_folder)
  checksum_file = new_resource.checksum_file || "#{ZiprHelper.checksums_folder}/#{archive_name}_#{archive_path_hash}.json"
  options = {
              exclude_files: new_resource.exclude_files,
              exclude_unless_missing: new_resource.exclude_unless_missing,
              overwrite: true,
              password: new_resource.password,
              archive_type: new_resource.archive_type,
            }

  has_before_notifications = new_resource.before_notifications.empty?
  checksum_path = (has_before_notifications || ::File.exist?(new_resource.archive_path)) ? checksum_file : nil
  changed_files, checksums = Zipr::Archive.determine_files_to_extract(new_resource.archive_path, new_resource.destination_folder, options: options, checksum_file: checksum_path)
  return if !changed_files.nil? && changed_files.empty?

  converge_if_changed do # so that why-run doesn't run this code when using a :before notification
    raise "Failed to extract archive because the archive does not exist! Archive path: #{new_resource.archive_path}" unless ::File.exist?(new_resource.archive_path)
    _checksum_path, checksums = Zipr::Archive.extract(new_resource.archive_path, new_resource.destination_folder, files_to_extract: changed_files, options: options, checksums: checksums)

    zipr_checksums_file checksum_file do
      checksums checksums
    end

    file "delete #{new_resource.archive_path}" do
      action :delete
      path new_resource.archive_path
      only_if { new_resource.delete_after_processing }
    end
  end
end

action :create do
  new_resource.sensitive = true unless new_resource.password.nil?
  standardize_properties(new_resource)
  ZiprHelper.load_zipr_dependencies(new_resource)

  options = {
              exclude_files: new_resource.exclude_files,
              exclude_unless_missing: new_resource.exclude_unless_missing,
              archive_type: new_resource.archive_type,
            }

  changed_files, checksums = Zipr::Archive.determine_files_to_add(new_resource.archive_path, new_resource.source_folder, files_to_check: new_resource.target_files, options: options)
  return if changed_files.empty?

  converge_if_changed do # so that why-run doesn't run this code when using a :before notification
    _checksum_path, checksums = Zipr::Archive.add(new_resource.archive_path, new_resource.source_folder, files_to_add: changed_files, options: options, checksums: checksums)
    checksum_file = new_resource.checksum_file || create_action_checksum_file(new_resource.archive_path, new_resource.target_files)

    zipr_checksums_file checksum_file do
      checksums checksums
    end

    if new_resource.delete_after_processing
      changed_files.each do |changed_file|
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
  new_resource.exclude_files = flattened_paths(new_resource.source_folder, new_resource.exclude_files)
  new_resource.exclude_unless_missing = flattened_paths(new_resource.source_folder, new_resource.exclude_unless_missing)
end
