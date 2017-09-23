resource_name :zipr_archive

# Common properties
property :archive_path, String, name_property: true # Compressed file path
property :delete_after_processing, [TrueClass, FalseClass], default: false # Delete source files or source archive after processing
property :exclude_files, Array # Array of relative_paths for files that should not be extracted
property :exclude_unless_missing, Array # Array of relative_paths for files that should not be extracted if they already exist

# Compression properties
property :archive_type, Symbol, default: :zip # :zip, :seven_zip, :sfx
property :target_file, String, default: ''
property :target_files, [String, Array], default: lazy { |r| [r.target_file] } # 7-zip wildcards allowed for windows

# Extraction properties
property :destination_folder, String

default_action :extract

action :create do
  raise 'Unsupported OS platform!' unless node['platform'] == 'windows'
  sevenzip_folder = "#{::Chef::Config[:file_cache_path]}/7-zip"
  zip_types = { zip: 'tzip', seven_zip: 't7z', sfx: 't7z' }

  # TODO: include_recipe seven_zip in windows
  include_recipe 'seven_zip::default'
  puts "node['seven_zip']['home']: #{node['seven_zip']['home']}"
  raise 'stop'

  include_recipe 'zipr::deploy_binaries'

  file_list = new_resource.target_files.is_a?(String) ? new_resource.target_files : "\"#{new_resource.target_files.join('" "')}\""

  execute "Create #{new_resource.archive_type} archive" do
    action :run
    command <<-EOS
      #{sevenzip_folder}\\7z.exe a -#{zip_types[new_resource.archive_type]} #{new_resource.archive_path} #{file_list}
    EOS
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
  zip_file_archive "Create if missing: #{new_resource.archive_path}" do
    action :create
    archive_path new_resource.archive_path
    archive_type new_resource.archive_type
    target_file new_resource.target_file
    target_files new_resource.target_files
    delete_after_processing new_resource.delete_after_processing
    not_if { ::File.exist?(new_resource.archive_path) }
  end
end

action :extract do
  require 'digest'
  require 'json'
  require 'zip'
  extend ZiprHelper

  cache_folder = "#{::Chef::Config[:file_cache_path]}/zipr/"
  checksums_folder = "#{cache_folder}/archive_checksums"
  archive_name = ::File.basename(new_resource.archive_path)
  filepath_checksum = ::Digest::SHA256.hexdigest(new_resource.archive_path)[0..10]
  checksum_file = "#{checksums_folder}/#{archive_name}_#{filepath_checksum}"
  changed_files = []

  if ::File.exist?(checksum_file)
    up_to_date = true
    file_content = ::File.read(checksum_file)
    archive_checksums = JSON.parse(file_content)
    archive_checksums.each do |compressed_file, compressed_file_checksum|
      next if (new_resource.exclude_files || []).grep(/#{compressed_file}/i)
      next if ::File.exist?("#{new_resource.destination_folder}/#{compressed_file}") &&
              (::Digest::SHA256.file("#{new_resource.destination_folder}/#{compressed_file}").hexdigest == compressed_file_checksum ||
              (new_resource.exclude_unless_missing || []).grep(/#{compressed_file}/i))
      changed_files.push(compressed_file)
    end
    return if changed_files.empty?
  end

  converge_if_changed do
    directory new_resource.destination_folder do
      action :create
      recursive true
    end

    case new_resource.archive_type
    when :zip
      ruby_block 'Extract files' do
        block do
          extend ZiprHelper
          zipr_extract(new_resource.archive_path,
                       new_resource.destination_folder,
                       changed_files: changed_files,
                       exclude_files: new_resource.exclude_files,
                       exclude_unless_missing: new_resource.exclude_unless_missing,
                       archive_checksums: archive_checksums)
          zipr_checksums_file checksum_file do
            archive_checksums archive_checksums
          end
        end
      end
    else
      raise "The archive type '#{new_resource.archive_type}' is not currently supported!"
    end

    file "delete #{new_resource.archive_path}" do
      action :delete
      path new_resource.archive_path
      only_if { new_resource.delete_after_processing }
    end
  end
end
