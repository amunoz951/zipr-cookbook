#
# Cookbook:: ncr_vault_test
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.
Chef::Log.info 'Creating test files'
test_folder = 'C:/zipr_test'

directory test_folder do
  action :create
  recursive true
end

%w(1 2 3 4 5).each do |file_number|
  file "#{test_folder}/file#{file_number}.txt" do
    content file_number
  end
end

zipr_archive "#{test_folder}/test_archive.zip" do
  action :create
  archive_type :zip
  target_files Dir.glob("#{test_folder}/*.txt")
  exclude_files 'file4.txt'
end

zipr_archive "#{test_folder}/test_archive2.7z" do
  action :create
  archive_type :seven_zip
  target_files Dir.glob("#{test_folder}/*.txt")
  exclude_files ['file2.txt', 'file4.txt']
end

zipr_archive "#{test_folder}/test_archive.zip" do
  action :extract
  destination_folder "#{test_folder}/extract_test"
  exclude_files ['file2.txt', 'file3.txt']
  exclude_unless_missing 'file5.txt'
end

zipr_archive "#{test_folder}/test_archive2.7z" do
  action :extract
  destination_folder "#{test_folder}/extract_test"
  exclude_files 'file3.txt'
  exclude_unless_missing 'file5.txt'
  delete_after_processing true
end