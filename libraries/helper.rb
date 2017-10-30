module ZiprHelper
  def extract_archive(archive_path, destination_folder, changed_files: nil, exclude_files: nil, exclude_unless_missing: nil, archive_checksums: nil, archive_type: :zip)
    case archive_type
    when :zip
      extract_zip(archive_path, destination_folder,
                       changed_files: changed_files, exclude_files: exclude_files,
                       exclude_unless_missing: exclude_unless_missing, archive_checksums: archive_checksums)
    when :seven_zip
      extract_seven_zip(archive_path,
                             destination_folder,
                             changed_files: changed_files,
                             exclude_files: exclude_files,
                             exclude_unless_missing: exclude_unless_missing,
                             archive_checksums: archive_checksums)
    else
      raise "':#{archive_type}' is not a supported archive type!"
    end
  end

  def extract_zip(archive_path, destination_folder, changed_files: nil, exclude_files: nil, exclude_unless_missing: nil, archive_checksums: nil)
    archive_checksums = {} if archive_checksums.nil?
    Zip::File.open(archive_path) do |archive_items|
      Chef::Log.info("Extracting to #{destination_folder}...")
      archive_items.each do |archive_item|
        destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
        destination_path = destination_path.tr('/', '\\') if node['platform'] == 'windows'
        if archive_item.ftype == :directory
          FileUtils.mkdir_p(destination_path)
          next
        end
        extract_lambda = -> { archive_item.extract(destination_path) { :overwrite } }
        puts "sending lambda for #{archive_item.name}..."

        archive_item_checksum = extract_file(destination_folder, archive_item.name, extract_lambda, changed_files: changed_files, exclude_files: exclude_files, exclude_unless_missing: exclude_unless_missing)
        puts "archive_item_checksum: #{archive_item_checksum}"
        archive_checksums[archive_item.name.tr('\\', '/')] = archive_item_checksum unless archive_item_checksum.nil?
      end
    end
    archive_checksums
  end

  def extract_seven_zip(archive_path, destination_folder, changed_files: nil, exclude_files: nil, exclude_unless_missing: nil, archive_checksums: nil)
    include_recipe 'zipr::default'
    require 'seven_zip_ruby'

    archive_checksums = {} if archive_checksums.nil?
    ::File.open(archive_path, 'rb') do |archive_file|
      SevenZipRuby::Reader.open(archive_file) do |archive_items|
        Chef::Log.info("Extracting to #{destination_folder}...")
        archive_items.entries.each do |archive_item|
          destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
          next unless changed_files.nil? || changed_files.include?(archive_item.name)
          next if (exclude_files || []).grep(/#{archive_item.name}/i)
          next if (exclude_unless_missing || []).grep(/#{archive_item.name}/i) && ::File.exist?(destination_path)
          destination_path = destination_path.tr('/', '\\') if node['platform'] == 'windows'
          if archive_item.ftype == :directory
            FileUtils.mkdir_p(destination_path)
            next
          end
          extract_lambda = -> { archive_item.extract(destination_path) { :overwrite } }
          archive_item_checksum = extract_file(destination_folder, archive_item.name, extract_lambda, changed_files: changed_files, exclude_files: exclude_files, exclude_unless_missing: exclude_unless_missing)
          FileUtils.mkdir_p(::File.dirname(destination_path))
          Chef::Log.info("Extracting #{archive_item.name}...")
          archive_item.extract(destination_path) { :overwrite }
          archive_checksums[archive_item.name.tr('\\', '/')] = archive_item_checksum unless archive_item_checksum.nil?
        end
      end
    end
    archive_checksums
  end

  def extract_file(destination_folder, archive_item_name, extract_lambda, changed_files: nil, exclude_files: [], exclude_unless_missing: [])
    destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item_name}"
    return nil unless changed_files.nil? || changed_files.include?(archive_item_name)
    return nil if exclude_files.any? { |f| f.match(/#{archive_item_name}/i) }
    return nil if exclude_unless_missing.any? { |f| f.match(/#{archive_item_name}/i) } && ::File.exist?(destination_path)
    destination_path = destination_path.tr('/', '\\') if node['platform'] == 'windows'

    FileUtils.mkdir_p(::File.dirname(destination_path))
    Chef::Log.info("Extracting #{archive_item_name}...")
    extract_lambda.call
    Digest::SHA256.file(destination_path)
  end

  def seven_zip_exe
    path = if node['seven_zip']['home']
             node['seven_zip']['home']
           else
             seven_zip_exe_from_registry
           end
    Chef::Log.debug("Using 7-zip home: #{path}")
    ::File.join(path, '7z.exe')
  end

  def seven_zip_exe_from_registry
    key_path = 'SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\7zFM.exe'
    return nil unless key_exists?(key_path)
    require 'win32/registry'
    # Read path from recommended Windows App Paths registry location
    # docs: https://msdn.microsoft.com/en-us/library/windows/desktop/ee872121
    ::Win32::Registry::HKEY_LOCAL_MACHINE.open(key_path, ::Win32::Registry::KEY_READ).read_s('Path')
  end

  def key_exists?(path)
    Win32::Registry::HKEY_LOCAL_MACHINE.open(path, ::Win32::Registry::KEY_READ)
    true
  rescue
    false
  end
end
