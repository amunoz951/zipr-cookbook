resource_name :zip_file_archive

property :archive_path, String, name_property: true # Customer name
property :archive_type, Symbol, default: :zip # :zip, :seven_zip, :sfx
property :target_file, String, default: ''
property :target_files, [String, Array], default: lazy { [target_file] } # If string, pass the 7zip argument for the target folder/files
property :installer_title, String # SFX only - Title of SFX installer window
property :installer_executable, String # SFX only - executable to launch after extraction
property :info_file_path, String # SFX only - Optionally specify custom info_file - examples: https://sevenzip.osdn.jp/chm/cmdline/switches/sfx.htm
property :delete_after_processing, [TrueClass, FalseClass], default: false
property :artifacts, Hash, required: true

default_action :create

action :create do
  new_resource.sensitive = true

  sfx_folder = "#{::Chef::Config[:file_cache_path]}/SFX_Installers"
  sevenzip_folder = "#{::Chef::Config[:file_cache_path]}/7-zip"
  zip_types = { zip: 'tzip', seven_zip: 't7z', sfx: 't7z' }

  require 'fileutils'
  [sfx_folder, sevenzip_folder].each do |folder|
    FileUtils.mkdir_p(folder) unless ::File.exist?(folder)
  end

  include_recipe 'zip_file::deploy_binaries'

  temp_archive_path = archive_type == :sfx ? "#{sfx_folder}\\sfx_temp_archive.7z" : archive_path
  file_list = if target_files.is_a?(String)
                target_files
              else
                "\"#{target_files.join('" "')}\""
              end

  execute 'Create temporary archive' do
    action :run
    command <<-EOS
      #{sevenzip_folder}\\7z.exe a -#{zip_types[archive_type]} #{temp_archive_path} #{file_list}
    EOS
  end

  if archive_type == :sfx
    if info_file_path.nil?
      info_file = "#{sfx_folder}/sfx_info.txt"
      file info_file do
        action :create
        content <<-EOS
          ;!@Install@!UTF-8!
          Title="#{installer_title}"
          RunProgram="#{installer_executable}"
          ;!@InstallEnd@!
        EOS
          .strip
      end
    else
      info_file = info_file_path
    end

    execute "Create SFX Installer: #{archive_path.tr('/', '\\')}" do
      action :run
      command <<-EOS
        copy /b "#{sevenzip_folder.tr('/', '\\')}\\7zS.sfx" + "#{info_file.tr('/', '\\')}" + "#{temp_archive_path.tr('/', '\\')}" "#{archive_path.tr('/', '\\')}"
      EOS
    end

    file temp_archive_path do
      action :delete
    end
  end

  if delete_after_processing
    target_files.each do |source_file|
      file source_file do
        action :delete
      end
    end
  end
end

action :create_if_missing do
  new_resource.sensitive = true
  zip_file_archive "Create if missing: #{archive_path}" do
    action :create
    archive_path new_resource.archive_path
    archive_type new_resource.archive_type
    target_file new_resource.target_file
    target_files new_resource.target_files
    installer_title new_resource.installer_title
    installer_executable new_resource.installer_executable
    info_file_path new_resource.info_file_path
    delete_after_processing new_resource.delete_after_processing
    artifacts new_resource.artifacts
    not_if { ::File.exist?(archive_path) }
  end
end
