module ZiprHelper
  def zipr_extract(archive_path, destination_folder, changed_files: nil, exclude_files: nil, exclude_unless_missing: nil, archive_checksums: nil)
    archive_checksums = {} if archive_checksums.nil?
    Zip::File.open(new_resource.archive_path) do |archive_items|
      Chef::Log.info("Extracting to #{new_resource.destination_folder}...")
      archive_items.each do |archive_item|
        destination_path = "#{new_resource.destination_folder.tr('\\', '/').chomp('/')}/#{archive_item.name}"
        next unless changed_files.nil? || changed_files.include?(archive_item.name)
        next if (exclude_files || []).grep(/#{archive_item.name}/i)
        next if (exclude_unless_missing || []).grep(/#{archive_item.name}/i) && ::File.exist?(destination_path)
        destination_path = destination_path.tr('/', '\\') if node['platform'] == 'windows'
        if archive_item.ftype == :directory
          FileUtils.mkdir_p(destination_path)
          next
        end
        FileUtils.mkdir_p(::File.dirname(destination_path))
        Chef::Log.info("Extracting #{archive_item.name}...")
        archive_item.extract(destination_path) { :overwrite }
        archive_checksums[archive_item.name.tr('\\', '/')] = Digest::SHA256.file(destination_path)
      end
    end
    archive_checksums
  end
end
