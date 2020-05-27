resource_name :zipr_sfx

property :archive_path, String, name_property: true # desired SFX path
property :exclude_files, [String, Array], default: [] # Array of relative_paths for files that should not be added to the SFX
property :target_files, [String, Array], required: true # Dir.glob style wildcards allowed
property :source_folder, String, default: lazy { |r| ::File.dirname(r.target_files.first) }
property :temp_subfolder, String # Optional cache subfolder where SFX will be generated

# SFX properties
property :installer_title, String # Title of SFX installer window
property :installer_executable, String # executable to launch after extraction
property :install_path, String, default: './' # Optionally specify where the files should be extracted to permanently
property :delete_install_path, [TrueClass, FalseClass], default: false # Optionally delete files extracted to install_path after installer_executable exits
property :begin_prompt, String # Optionally add a prompt when the SFX is run before the installer executable is launched.
property :show_progress, [TrueClass, FalseClass], default: false # Optionally show extraction progress

default_action :create

action :create do
  standardize_properties(new_resource)

  archive_name = ::File.basename(new_resource.archive_path)
  archive_path_hash = ::Digest::SHA256.hexdigest(new_resource.archive_path)
  checksum_file = "#{checksums_folder}/#{archive_name}-#{archive_path_hash}.json"
  options = {
              exclude_files: new_resource.exclude_files,
              archive_type: :seven_zip,
            }

  checksum_path = ::File.exist?(new_resource.archive_path) ? checksum_file : nil
  changed_files, checksums = Zipr::SFX.determine_files_to_add(new_resource.archive_path, new_resource.source_folder, files_to_check: new_resource.target_files, options: options, checksum_file: checksum_path)
  return if changed_files.empty?

  converge_if_changed do
    info_file_hash = {
      Title: new_resource.installer_title,
      InstallPath: new_resource.install_path,
      RunProgram: new_resource.installer_executable,
      Delete: new_resource.delete_install_path ? new_resource.install_path : nil,
      BeginPrompt: new_resource.begin_prompt,
      Progress: new_resource.show_progress ? 'yes' : 'no',
    }.select { |_k, v| v && !v.to_s.empty? }

    _checksum_path, checksums = Zipr::SFX.create(new_resource.archive_path, new_resource.source_folder, files_to_add: new_resource.target_files, options: options, checksums: checksums, info_hash: info_file_hash, temp_subfolder: new_resource.temp_subfolder)

    zipr_checksums_file checksum_file do
      checksums checksums
    end
  end
end

action :create_if_missing do
  new_resource.sensitive = true
  zipr_sfx "Create if missing: #{new_resource.archive_path}" do
    action :create
    archive_path new_resource.archive_path
    exclude_files new_resource.exclude_files
    source_folder new_resource.source_folder
    temp_subfolder new_resource.temp_subfolder
    target_files new_resource.target_files
    installer_title new_resource.installer_title
    installer_executable new_resource.installer_executable
    install_path new_resource.install_path
    delete_install_path new_resource.delete_install_path
    begin_prompt new_resource.begin_prompt
    show_progress new_resource.show_progress
    not_if { ::File.exist?(new_resource.archive_path) }
  end
end

def standardize_properties(new_resource)
  new_resource.target_files = [new_resource.target_files] if new_resource.target_files.is_a?(String)
  new_resource.exclude_files = [new_resource.exclude_files] if new_resource.exclude_files.is_a?(String)
  new_resource.exclude_files = flattened_paths(new_resource.source_folder, new_resource.exclude_files)
  new_resource.install_path = to_double_backslashes(new_resource.install_path, with_trailing_backslashes: true)
  new_resource.installer_executable = to_double_backslashes(new_resource.installer_executable)
end

def to_double_backslashes(path, with_trailing_backslashes: false)
  path = path.tr('/', '\\')
  path = "#{path}\\" if with_trailing_backslashes && !path.end_with?('\\')
  path.gsub(/(?<!\\)\\(?!\\)/) { '\\\\' }
end
