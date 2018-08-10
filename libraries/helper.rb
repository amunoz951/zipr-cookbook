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
    archive_checksums['archive_checksum'] = Digest::SHA256.file(archive_path).hexdigest
    Zip::File.open(archive_path) do |archive_items|
      Chef::Log.info("Extracting to #{destination_folder}...")
      archive_items.each do |archive_item|
        destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
        next unless changed_files.nil? || changed_files.include?(archive_item.name)
        if archive_item.ftype == :directory
          FileUtils.mkdir_p(destination_path)
          archive_checksums[archive_item.name.tr('\\', '/')] = 'directory'
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
    archive_checksums['archive_checksum'] = Digest::SHA256.file(archive_path).hexdigest
    ::File.open(archive_path, 'rb') do |archive_file|
      SevenZipRuby::Reader.open(archive_file) do |archive_items|
        Chef::Log.info("Extracting to #{destination_folder}...")
        archive_items.entries.each do |archive_item|
          destination_path = "#{destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
          next unless changed_files.nil? || changed_files.include?(archive_item.name)
          if archive_item.ftype == :directory
            FileUtils.mkdir_p(destination_path)
            archive_checksums[archive_item.name.tr('\\', '/')] = 'directory'
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

  def changed_files_for_extract(archive_path, checksum_file, destination_folder, exclude_files, exclude_unless_missing)
    changed_files = nil # changed_files must be nil if the checksum file does not yet exist
    archive_checksums = {}
    if ::File.exist?(checksum_file)
      changed_files = []
      file_content = ::File.read(checksum_file)
      archive_checksums = JSON.parse(file_content)
      return [nil, {}] unless !::File.exist?(archive_path) ||
                              archive_checksums['archive_checksum'] == Digest::SHA256.file(archive_path).hexdigest # If the archive has changed, extract again
      archive_checksums.each do |compressed_file, compressed_file_checksum|
        next if compressed_file == 'archive_checksum'
        next if exclude_files.any? { |e| e.casecmp(compressed_file) == 0 }
        destination_path = "#{destination_folder}/#{compressed_file}"
        next if ::File.exist?(destination_path) && exclude_unless_missing.any? { |e| e.casecmp(compressed_file) == 0 }
        next if ::File.file?(destination_path) && ::Digest::SHA256.file(destination_path).hexdigest == compressed_file_checksum
        next if ::File.directory?(destination_path) && compressed_file_checksum == 'directory'
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
        Chef::Log.info("Compressing #{relative_path}...")
        if ::File.directory?(source_file)
          zip_archive.mkdir(relative_path) unless zip_archive.find_entry(relative_path)
          archive_item_checksum = 'directory'
        else
          zip_archive.add(relative_path, source_file) { :overwrite }
          archive_item_checksum = Digest::SHA256.file(source_file).hexdigest
        end
        archive_checksums[relative_path.tr('\\', '/')] = archive_item_checksum
      end
    end
    [archive_checksums, Digest::SHA256.file(archive_path).hexdigest]
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
          relative_path.slice!(source_folder.tr('\\', '/'))
          relative_path = relative_path.reverse.chomp('/').reverse
          Chef::Log.info("Compressing #{relative_path}...")
          if ::File.directory?(source_file)
            seven_zip_archive.mkdir(relative_path) unless seven_zip_archive.find_entry(relative_path)
            archive_item_checksum = 'directory'
          else
            seven_zip_archive.add_file(source_file, relative_path)
            archive_item_checksum = Digest::SHA256.file(source_file).hexdigest
          end
          archive_checksums[relative_path.tr('\\', '/')] = archive_item_checksum
        end
      end
    end
    [archive_checksums, Digest::SHA256.file(archive_path).hexdigest]
  end

  def changed_files_for_add_to_archive(checksum_file, source_folder, target_files, exclude_files, exclude_unless_missing)
    archive_checksums = {}
    changed_files = []
    if ::File.exist?(checksum_file)
      file_content = ::File.read(checksum_file)
      archive_checksums = JSON.parse(file_content)
    end
    target_files.each do |target_search|
      source_files = Dir.glob(prepend_source_folder(source_folder, target_search))
      source_files.each do |source_file|
        relative_path = slice_source_folder(source_folder, source_file)
        next if exclude_files.any? { |e| e.casecmp(relative_path) == 0 || e.casecmp(source_file) == 0 }
        next if ::File.file?(source_file) && archive_checksums[relative_path] == Digest::SHA256.file(source_file).hexdigest
        next if ::File.directory?(source_file) && archive_checksums[relative_path] == 'directory'
        next if archive_checksums[relative_path] && exclude_unless_missing.any? { |e| e.casecmp(relative_path) == 0 || e.casecmp(source_file) == 0 }
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

  # returns results of all files found in the array of files, including files found by wildcard, as relative paths.
  def flattened_paths(source_folder, files)
    result = []
    files.each do |entry|
      standardized_entry = "#{source_folder.tr('\\', '/')}/#{slice_source_folder(source_folder, entry)}"
      files_found = Dir.glob(standardized_entry)
      if files_found.empty?
        result.push(entry)
      else
        result += files_found.map { |e| slice_source_folder(source_folder, e) }
      end
    end
    result
  end

  def prepend_source_folder(source_folder, entry)
    return entry.tr('\\', '/') if source_folder.nil? || source_folder.empty? || entry.start_with?(source_folder.tr('\\', '/'))
    "#{source_folder.tr('\\', '/')}/#{entry.tr('\\', '/')}"
  end

  def slice_source_folder(source_folder, entry)
    entry.tr('\\', '/').sub(source_folder.tr('\\', '/'), '').reverse.chomp('/').reverse
  end
end
