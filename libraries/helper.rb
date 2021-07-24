require 'json'

module ZiprHelper
  module_function

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
