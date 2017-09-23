resource_name :zipr_sfx

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing

# Compression properties
property :target_file, String, default: ''
property :target_files, [String, Array], default: lazy { [target_file] } # 7zip specific wildcards allowed for windows

# SFX only properties
property :installer_title, String # Title of SFX installer window
property :installer_executable, String # executable to launch after extraction
property :info_file_path, String # Optionally specify custom info_file - examples: https://sevenzip.osdn.jp/chm/cmdline/switches/sfx.htm

default_action :create

action :create do
  sfx_folder = "#{::Chef::Config[:file_cache_path]}/SFX_Installers"
  sevenzip_folder = "#{::Chef::Config[:file_cache_path]}/7-zip" # calculate correct path in windows

  FileUtils.mkdir_p(sfx_folder) unless ::File.exist?(sfx_folder)

  temp_archive_path = "#{sfx_folder}\\sfx_temp_archive.7z"

  zipr_archive temp_archive_path do
    action :create
    delete_after_processing new_resource.delete_after_processing
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
  end

  execute "Create SFX Installer: #{new_resource.archive_path.tr('/', '\\')}" do
    action :run
    command <<-EOS
      copy /b "#{sevenzip_folder.tr('/', '\\')}\\7zS.sfx" + "#{new_resource.info_file_path.tr('/', '\\')}" + "#{temp_archive_path.tr('/', '\\')}" "#{new_resource.archive_path.tr('/', '\\')}"
    EOS
  end

  file temp_archive_path do
    action :delete
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
