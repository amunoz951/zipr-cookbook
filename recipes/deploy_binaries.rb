FileUtils.mkdir_p(sevenzip_folder) unless ::File.exist?(sevenzip_folder)

%w(7z.exe 7z.dll 7zS.sfx).each do |filename|
  cookbook_file "#{Chef::Config[:file_cache_path]}/7-zip/#{filename}" do
    action :create
    source filename
  end
end
