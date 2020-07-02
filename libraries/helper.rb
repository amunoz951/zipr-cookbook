require 'json'

module ZiprHelper
  # options: { exclude_files: [], exclude_unless_missing: [], overwrite: true, archive_type: :zip }
  def extract_archive(archive_path, destination_folder, changed_files, options, archive_checksums: nil)
    case options[:archive_type]
    when :zip
      extract_zip(archive_path, destination_folder, changed_files, options, archive_checksums: archive_checksums)
    when :seven_zip
      extract_seven_zip(archive_path, destination_folder, changed_files, options, archive_checksums: archive_checksums)
    else
      raise "':#{options[:archive_type]}' is not a supported archive type!"
    end
  end

  # options: { exclude_files: [], exclude_unless_missing: [], overwrite: true }
  def extract_zip(archive_path, destination_folder, changed_files, options, archive_checksums: nil)
    require 'zip'

    archive_checksums = {} if archive_checksums.nil?
    archive_checksums['archive_checksum'] = Digest::SHA256.file(archive_path).hexdigest
    Zip::File.open(archive_path) do |archive_items|
      Chef::Log.info("Extracting to #{destination_folder}...")
      archive_items.each do |archive_item|
        destination_path = ::File.join(destination_folder.tr('\\', '/'), archive_item.name)
        next unless changed_files.nil? || changed_files.include?(archive_item.name)
        next if excluded_file?(archive_item.name, options, destination_path: destination_path)
        if archive_item.ftype == :directory
          FileUtils.mkdir_p(destination_path)
          archive_checksums[archive_item.name.tr('\\', '/')] = 'directory'
          next
        end
        next if ::File.file?(destination_path) && !options[:overwrite] # skip extract if the file exists and overwrite is false
        FileUtils.mkdir_p(::File.dirname(destination_path))
        Chef::Log.info("Extracting #{archive_item.name}...")
        archive_item.extract(destination_path) { :overwrite }
        archive_checksums[archive_item.name.tr('\\', '/')] = Digest::SHA256.file(destination_path).hexdigest
      end
    end
    archive_checksums
  end

  # options: { exclude_files: [], exclude_unless_missing: [], overwrite: true, password: nil }
  def extract_seven_zip(archive_path, destination_folder, changed_files, options, archive_checksums: nil)
    include_recipe 'zipr::seven_zip_ruby'
    require 'seven_zip_ruby'

    archive_checksums = {} if archive_checksums.nil?
    archive_checksums['archive_checksum'] = Digest::SHA256.file(archive_path).hexdigest
    ::File.open(archive_path, 'rb') do |archive_file|
      SevenZipRuby::Reader.open(archive_file, options) do |seven_zip_archive|
        Chef::Log.info("Extracting to #{destination_folder}...")
        seven_zip_archive.entries.each do |archive_item|
          destination_path = ::File.join(destination_folder.tr('\\', '/'), archive_item.path)
          next unless changed_files.nil? || changed_files.include?(archive_item.path)
          next if excluded_file?(archive_item.path, options, destination_path: destination_path)
          if archive_item.directory?
            FileUtils.mkdir_p(destination_path)
            archive_checksums[archive_item.path.tr('\\', '/')] = 'directory'
            next
          end
          if ::File.file?(destination_path)
            options['overwrite'] ? FileUtils.rm(destination_path) : next # skip extract if the file exists and overwrite is false
          end
          FileUtils.mkdir_p(::File.dirname(destination_path))
          Chef::Log.info("Extracting #{archive_item.path}...")
          seven_zip_archive.extract(archive_item.index, destination_folder)
          archive_checksums[archive_item.path.tr('\\', '/')] = Digest::SHA256.file(destination_path).hexdigest
        end
      end
    end
    archive_checksums
  end

  # options: { exclude_files: [], exclude_unless_missing: [] }
  def changed_files_for_extract(archive_path, checksum_file, destination_folder, options)
    changed_files = nil # changed_files must be nil if the checksum file does not yet exist
    archive_checksums = {}
    if ::File.exist?(checksum_file)
      changed_files = []
      file_content = ::File.read(checksum_file)
      archive_checksums = JSON.parse(file_content)
      return [nil, {}] if ::File.exist?(archive_path) && archive_checksums['archive_checksum'] != Digest::SHA256.file(archive_path).hexdigest # If the archive has changed, return and extract again
      archive_checksums.each do |compressed_file, compressed_file_checksum|
        next if compressed_file == 'archive_checksum'
        destination_path = "#{destination_folder}/#{compressed_file}"
        next if excluded_file?(compressed_file, options, destination_path: destination_path)
        next if ::File.file?(destination_path) && ::Digest::SHA256.file(destination_path).hexdigest == compressed_file_checksum
        next if ::File.directory?(destination_path) && compressed_file_checksum == 'directory'
        changed_files.push(compressed_file)
      end
    end
    [changed_files, archive_checksums]
  end

  # options: { archive_type: :zip }
  def add_to_archive(archive_path, source_folder, source_files, options, archive_checksums: nil)
    return nil if source_files.nil?
    FileUtils.mkdir_p(::File.dirname(archive_path))
    calculated_checksums = case options[:archive_type]
                           when :zip
                             add_to_zip(archive_path, source_folder, source_files, archive_checksums: archive_checksums)
                           when :seven_zip
                             add_to_seven_zip(archive_path, source_folder, source_files, archive_checksums: archive_checksums)
                           else
                             raise "':#{options[:archive_type]}' is not a supported archive type!"
                           end
    raise "Failed to create archive at #{archive_path}!" unless ::File.file?(archive_path)
    calculated_checksums['archive_checksum'] = ::Digest::SHA256.file(archive_path).hexdigest
    calculated_checksums
  end

  def add_to_zip(archive_path, source_folder, source_files, archive_checksums: nil)
    require 'zip'

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
        archive_checksums[relative_path] = archive_item_checksum
      end
    end
    archive_checksums
  end

  def add_to_seven_zip(archive_path, source_folder, source_files, archive_checksums: nil)
    include_recipe 'zipr::seven_zip_ruby'
    require 'seven_zip_ruby'

    archive_checksums = {} if archive_checksums.nil?
    ::File.open(archive_path, 'wb') do |archive_file|
      SevenZipRuby::Writer.open(archive_file) do |seven_zip_archive|
        Chef::Log.info("Compressing to #{archive_path}...")
        source_files.each do |source_file|
          relative_path = source_file.tr('\\', '/')
          Chef::Log.debug "Source file using forward slashes: #{relative_path}"
          Chef::Log.debug "Source folder using forward slashes: #{source_folder.tr('\\', '/')}"
          relative_path.slice!(source_folder.tr('\\', '/'))
          relative_path = relative_path.reverse.chomp('/').reverse
          Chef::Log.debug "Relative path: #{relative_path}"
          raise "Source file (#{source_file}) does not contain the source folder (#{source_folder}). This may be due to inconsistent capitalization." if relative_path == source_file.tr('\\', '/')
          seven_zip_options = { as: relative_path }
          Chef::Log.info("Compressing #{relative_path}...")
          if ::File.directory?(source_file)
            seven_zip_archive.mkdir(relative_path)
            archive_item_checksum = 'directory'
          else
            seven_zip_archive.add_file(source_file, seven_zip_options)
            archive_item_checksum = Digest::SHA256.file(source_file).hexdigest
          end
          archive_checksums[relative_path] = archive_item_checksum
        end
      end
    end
    archive_checksums
  end

  # options: { exclude_files: [], exclude_unless_missing: [] }
  def changed_files_for_add_to_archive(archive_path, checksum_file, source_folder, target_files, options = {})
    checksum_file ||= create_action_checksum_file(archive_path, target_files)
    FileUtils.rm(checksum_file) if ::File.file?(checksum_file) && !::File.file?(archive_path) # Start over if the archive is missing

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
        exists_in_zip = !!archive_checksums[relative_path]
        next if excluded_file?(relative_path, options, exists_in_zip: exists_in_zip) || excluded_file?(source_file, options, exists_in_zip: exists_in_zip)
        next if ::File.file?(source_file) && archive_checksums[relative_path] == Digest::SHA256.file(source_file).hexdigest
        next if ::File.directory?(source_file) && archive_checksums[relative_path] == 'directory'
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
    return files if source_folder.nil? || source_folder.empty?
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

  def excluded_file?(file_path, options, destination_path: '', exists_in_zip: false)
    return true if options[:exclude_files].any? { |e| file_path =~ /#{e.tr('\\', '/').gsub('*', '.*')}/i }
    return true if ::File.exist?(destination_path) && options[:exclude_unless_missing].any? { |e| file_path =~ /#{e.tr('\\', '/').gsub('*', '.*')}/i }
    return true if exists_in_zip && options[:exclude_unless_missing].any? { |e| file_path =~ /#{e.tr('\\', '/').gsub('*', '.*')}/i }
    false
  end

  def prepend_source_folder(source_folder, entry)
    return entry.tr('\\', '/') if source_folder.nil? || source_folder.empty? || entry.tr('\\', '/').start_with?(source_folder.tr('\\', '/'))
    "#{source_folder.tr('\\', '/')}/#{entry.tr('\\', '/')}"
  end

  def slice_source_folder(source_folder, entry)
    entry.tr('\\', '/').sub(source_folder.tr('\\', '/'), '').reverse.chomp('/').reverse
  end

  def checksums_folder
    "#{::Chef::Config[:file_cache_path]}/zipr/archive_checksums"
  end

  def create_action_checksum_file(archive_path, source_files)
    "#{checksums_folder}/#{::File.basename(archive_path)}_#{Digest::SHA256.hexdigest(archive_path + source_files.join)}.json"
  end

  def load_zipr_dependencies(new_resource)
    ::Chef.run_context.include_recipe 'zipr::dependencies'
  rescue LoadError
    raise "The zipr::dependencies recipe must be included before using the #{new_resource.declared_type} resource when :before notifications are used!" unless new_resource.before_notifications.empty?
    raise
  end
end

Chef::Resource.send(:include, ZiprHelper)
Chef::Provider.send(:include, ZiprHelper)
