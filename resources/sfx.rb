resource_name :zipr_sfx

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing
property :exclude_files, [String, Array], default: [] # Array of relative_paths for files that should not be extracted or archived

# Compression properties
property :target_files, [String, Array], default: [] # 7zip specific wildcards allowed for windows
property :source_folder, String, default: lazy { |r| ::File.dirname(r.target_files.first) }

# SFX only properties
property :installer_title, String # Title of SFX installer window
property :installer_executable, String # executable to launch after extraction
property :info_file_path, String # Optionally specify custom info_file - examples: https://sevenzip.osdn.jp/chm/cmdline/switches/sfx.htm

default_action :create

action :create do
  standardize_properties(new_resource)

  changed_files, _archive_checksums = changed_files_for_add_to_archive(new_resource.archive_path,
                                                                      new_resource.source_folder,
                                                                      new_resource.target_files,
                                                                      new_resource.exclude_files,
                                                                      [])
  return if changed_files.empty?

  converge_if_changed do
    sfx_folder = "#{::Chef::Config[:file_cache_path]}/zipr/SFX"
    sfx_module = "#{::Chef::Config[:file_cache_path]}/cookbooks/zipr/files/default/7zS.sfx".tr('/', '\\')

    FileUtils.mkdir_p(sfx_folder) unless ::File.exist?(sfx_folder)

    temp_archive_path = "#{sfx_folder}\\sfx_temp_archive.7z"

    zipr_archive temp_archive_path do
      action :create
      delete_after_processing new_resource.delete_after_processing
      source_folder new_resource.source_folder
      exclude_files new_resource.exclude_files
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
          RunProgram="#{new_resource.installer_executable}"
          ;!@InstallEnd@!
        EOS
      end
    else
      info_file = new_resource.info_file_path
    end

    execute "Create SFX Installer: #{new_resource.archive_path.tr('/', '\\')}" do
      action :run
      command <<-EOS
        copy /b "#{sfx_module}" + "#{info_file.tr('/', '\\')}" + "#{temp_archive_path.tr('/', '\\')}" "#{new_resource.archive_path.tr('/', '\\')}"
      EOS
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
end
