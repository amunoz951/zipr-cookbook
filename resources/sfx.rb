resource_name :zipr_sfx

property :archive_path, String, name_property: true # desired SFX path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files after processing
property :exclude_files, [String, Array], default: [] # Array of relative_paths for files that should not be added to the SFX
property :target_files, [String, Array], default: [] # 7zip specific wildcards allowed for windows
property :source_folder, String, default: lazy { |r| ::File.dirname(r.target_files.first) }
property :installer_title, String # Title of SFX installer window; required if info_file_path is not specified
property :installer_executable, String # executable to launch after extraction; required if info_file_path is not specified
property :info_file_path, String # Optionally specify custom info_file - examples: https://sevenzip.osdn.jp/chm/cmdline/switches/sfx.htm
property :extract_path, String, default: '.\unpack' # Optionally specify where the SFX will extract to

default_action :create

action :create do
  standardize_properties(new_resource)

  checksum_file = create_action_checksum_file(new_resource.archive_path, new_resource.target_files)
  options = {
              exclude_files: new_resource.exclude_files,
              exclude_unless_missing: [],
              archive_type: :seven_zip
            }

  changed_files = changed_files_for_add_to_archive(new_resource.archive_path,
                                                   checksum_file,
                                                   new_resource.source_folder,
                                                   new_resource.target_files,
                                                   options).first
  return if changed_files.empty?

  include_recipe 'zipr::default'

  converge_if_changed do
    sfx_folder = "#{::Chef::Config[:file_cache_path]}/zipr/SFX"
    sfx_module = "#{::Chef::Config[:file_cache_path]}/cookbooks/zipr/files/default/7zsd_All.sfx".tr('/', '\\')

    FileUtils.mkdir_p(sfx_folder) unless ::File.exist?(sfx_folder)

    temp_archive_path = "#{sfx_folder}/sfx_temp_archive.7z"

    zipr_archive temp_archive_path do
      action :create
      delete_after_processing new_resource.delete_after_processing
      source_folder new_resource.source_folder
      exclude_files new_resource.exclude_files
      checksum_file checksum_file
      archive_type :seven_zip
      target_files new_resource.target_files
    end

    if new_resource.info_file_path.nil?
      info_file = "#{sfx_folder}/sfx_info.txt"
      file info_file do
        action :create
        content <<-EOS.strip
          ;!@Install@!UTF-8!
          Title="#{new_resource.installer_title}"
          InstallPath="#{new_resource.extract_path}"
          RunProgram="#{new_resource.installer_executable}"
          ;!@InstallEnd@!
        EOS
      end
    else
      info_file = new_resource.info_file_path
    end

    create_sfx_command = if node['platform'] == 'windows'
                           'copy /b ' + <<-EOS.strip.tr('/', '\\')
                                         "#{sfx_module}" + "#{info_file}" + "#{temp_archive_path}" "#{new_resource.archive_path}"
                                       EOS
                         else
                           <<-EOS.strip.tr('\\', '/')
                             cat "#{sfx_module}" "#{info_file}" "#{temp_archive_path}" > "#{new_resource.archive_path}"
                           EOS
                         end

    execute "Create SFX Installer: #{new_resource.archive_path.tr('/', '\\')}" do
      action :run
      command create_sfx_command
    end

    directory sfx_folder do
      action :delete
      recursive true
    end
  end
end

action :create_if_missing do
  new_resource.sensitive = true
  zipr_sfx "Create if missing: #{new_resource.archive_path}" do
    action :create
    archive_path new_resource.archive_path
    target_file new_resource.target_file
    target_files new_resource.target_files
    installer_title new_resource.installer_title
    installer_executable new_resource.installer_executable
    info_file_path new_resource.info_file_path
    delete_after_processing new_resource.delete_after_processing
    not_if { ::File.exist?(new_resource.archive_path) }
  end
end

def standardize_properties(new_resource)
  new_resource.target_files = [new_resource.target_files] if new_resource.target_files.is_a?(String)
  new_resource.exclude_files = [new_resource.exclude_files] if new_resource.exclude_files.is_a?(String)
  new_resource.exclude_files = flattened_paths(new_resource.source_folder, new_resource.exclude_files)
end
