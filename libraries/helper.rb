module ZiprHelper
  def extract_archive(archive_path, destination_folder, changed_files, archive_checksums: nil, archive_type: :zip)
    case archive_type
    when :zip
      extract_zip(archive_path, destination_folder, changed_files, archive_checksums: archive_checksums)
    when :seven_zip
      extract_seven_zip(archive_path, destination_folder, changed_files, archive_checksums: archive_checksums)
    else
      raise "':#{archive_type}' is not a supported archive type!"
    end
  end

  def extract_zip(archive_path, destination_folder, changed_files, archive_checksums: nil)
    archive_checksums = {} if archive_checksums.nil?
    Zip::File.open(archive_path) do |archive_items|
      Chef::Log.info("Extracting to #{destination_folder}...")
      archive_items.each do |archive_item|
        destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
        next unless changed_files.nil? || changed_files.include?(archive_item.name)
        if archive_item.ftype == :directory
          FileUtils.mkdir_p(destination_path)
          next
        end
        FileUtils.mkdir_p(::File.dirname(destination_path))
        Chef::Log.info("Extracting #{archive_item.name}...")
        archive_item.extract(destination_path) { :overwrite }
        archive_checksums[archive_item.name.tr('\\', '/')] = Digest::SHA256.file(destination_path).hexdigest
      end
    end
    archive_checksums
  end

  def extract_seven_zip(archive_path, destination_folder, changed_files, archive_checksums: nil)
    raise 'extract_seven_zip not yet implemented!'
    include_recipe 'zipr::default'
    require 'seven_zip_ruby'

    archive_checksums = {} if archive_checksums.nil?
    ::File.open(archive_path, 'rb') do |archive_file|
      SevenZipRuby::Reader.open(archive_file) do |archive_items|
        Chef::Log.info("Extracting to #{destination_folder}...")
        archive_items.entries.each do |archive_item|
          destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
          next unless changed_files.nil? || changed_files.include?(archive_item.name)
          if archive_item.ftype == :directory
            FileUtils.mkdir_p(destination_path)
            next
          end
          FileUtils.mkdir_p(::File.dirname(destination_path))
          Chef::Log.info("Extracting #{archive_item.name}...")
          archive_item.extract(destination_path) { :overwrite }
          archive_checksums[archive_item.name.tr('\\', '/')] = Digest::SHA256.file(destination_path).hexdigest
        end
      end
    end
    archive_checksums
  end

  def changed_files_for_extract(checksum_file, destination_folder, exclude_files, exclude_unless_missing)
    changed_files = nil # changed_files must be nil if the checksum file does not yet exist
    archive_checksums = {}
    if ::File.exist?(checksum_file)
      changed_files = []
      file_content = ::File.read(checksum_file)
      archive_checksums = JSON.parse(file_content)
      archive_checksums.each do |compressed_file, compressed_file_checksum|
        next if exclude_files.any? { |e| e.casecmp(compressed_file) == 0 }
        destination_path = "#{destination_folder}/#{compressed_file}"
        next if ::File.exist?(destination_path) && exclude_unless_missing.any? { |e| e.casecmp(compressed_file) == 0 }
        next if ::File.exist?(destination_path) && ::Digest::SHA256.file(destination_path).hexdigest == compressed_file_checksum
        changed_files.push(compressed_file)
      end
    end
    [changed_files, archive_checksums]
  end

  def add_to_archive(archive_path, source_folder, source_files, archive_checksums: nil, archive_type: :zip)
    return nil if source_files.nil?
    FileUtils.mkdir_p(::File.dirname(archive_path))
    case archive_type
    when :zip
      add_to_zip(archive_path, source_folder, source_files, archive_checksums: archive_checksums)
    when :seven_zip
      add_to_seven_zip(archive_path, source_folder, source_files, archive_checksums: archive_checksums)
    else
      raise "':#{archive_type}' is not a supported archive type!"
    end
  end

  def add_to_zip(archive_path, source_folder, source_files, archive_checksums: nil)
    archive_checksums = {} if archive_checksums.nil?
    Zip::File.open(archive_path, Zip::File::CREATE) do |zip_archive|
      Chef::Log.info("Compressing to #{archive_path}...")
      source_files.each do |source_file|
        relative_path = source_file.tr('\\', '/')
        relative_path.slice!(source_folder.tr('\\', '/'))
        relative_path = relative_path.reverse.chomp('/').reverse
        zip_archive.add(relative_path, source_file) { :overwrite }
        puts "adding #{source_file}"
        archive_item_checksum = Digest::SHA256.file(source_file).hexdigest
        archive_checksums[relative_path.tr('\\', '/')] = archive_item_checksum
      end
    end
    archive_checksums
  end

  def add_to_seven_zip(archive_path, source_folder, source_files, archive_checksums: nil)
    raise 'extract_seven_zip not yet implemented!'
    include_recipe 'zipr::default'
    require 'seven_zip_ruby'

    archive_checksums = {} if archive_checksums.nil?
    ::File.open(archive_path, 'wb') do |archive_file|
      SevenZipRuby::Writer.open(archive_file) do |seven_zip_archive|
        Chef::Log.info("Compressing to #{archive_path}...")
        source_files.each do |source_file|
          relative_path = source_file.tr('\\', '/')
          relative_path.slice!(source_folder.tr('\\', '/')).reverse.chomp('/').reverse

          puts "Compressing #{source_file}..."
          puts "relative path: #{relative_path}"
          Chef::Log.info("Compressing #{source_file}...")
          seven_zip_archive.add_file(source_file, relative_path)
          archive_item_checksum = Digest::SHA256.file(source_file).hexdigest
          archive_checksums[relative_path.tr('\\', '/')] = archive_item_checksum
        end
      end
    end
    archive_checksums
  end

  def changed_files_for_add_to_archive(checksum_file, source_folder, target_files, exclude_files, exclude_unless_missing)
    archive_checksums = {}
    changed_files = []
    if ::File.exist?(checksum_file)
      file_content = ::File.read(checksum_file)
      archive_checksums = JSON.parse(file_content)
    end
    target_files.each do |target_search|
      source_files = Dir.glob(target_search)
      source_files.each do |source_file|
        next if exclude_files.any? { |e| e.casecmp(source_file) == 0 }
        relative_path = source_file.sub(source_folder, '').reverse.chomp('/').reverse
        next if archive_checksums[relative_path] == Digest::SHA256.file(source_file).hexdigest
        next if exclude_files.any? { |f| f.match(/#{relative_path}/i) }
        next if exclude_unless_missing.any? { |f| f.match(/#{relative_path}/i) } && archive_checksums[relative_path]
        changed_files.push(source_file)
      end
    end
    [changed_files, archive_checksums]
  end

  def seven_zip_exe
    path = node['seven_zip']['home'] || seven_zip_exe_from_registry
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
