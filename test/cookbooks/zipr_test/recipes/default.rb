#
# Cookbook:: ncr_vault_test
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.
Chef::Log.info 'Creating test files'
test_folder = 'C:/zipr_test'

directory "#{test_folder}/nested" do
  action :nothing
  recursive true
end.run_action(:create)

%w(1 2 3 4 5 6 7 8).each do |file_number|
  file "#{test_folder}/#{'nested/' if file_number.to_i >= 6}file#{file_number}.txt" do
    action :nothing
    content file_number
  end.run_action(:create)
end

zipr_archive "#{test_folder}/test_archive.zip" do
  action :create
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/*.txt") # only pick up the txt files in the test_folder
  exclude_files 'file4.txt'
end

# This should not create the archive as it should already exist and the action is :create_if_missing
zipr_archive "#{test_folder}/test_archive.zip" do
  action :create_if_missing
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/**/*")
end

# This should add nested folder to the existing archive created earlier
zipr_archive 'Add nested folder' do
  action :create
  archive_path "#{test_folder}/test_archive.zip"
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/**/*")
  exclude_files ['file4.txt', 'test_archive*.*', 'extract_test', 'extract_test/**/*', 'nested/file8.txt']
end

# TODO: complete 7z implementation via seven_zip_ruby gem
# zipr_archive "#{test_folder}/test_archive2.7z" do
#   action :create
#   archive_type :seven_zip
#   source_folder test_folder
#   target_files Dir.glob("#{test_folder}/*.txt")
#   exclude_files ['file2.txt', 'file4.txt']
# end

zipr_archive "#{test_folder}/test_archive.zip" do
  action :extract
  destination_folder "#{test_folder}/extract_test"
  exclude_files ['file2.txt', 'file3.txt', '**/file6.txt']
  exclude_unless_missing 'file5.txt'
end

# TODO: complete 7z implementation via seven_zip_ruby gem
# zipr_archive "#{test_folder}/test_archive2.7z" do
#   action :extract
#   destination_folder "#{test_folder}/extract_test"
#   exclude_files 'file3.txt'
#   exclude_unless_missing 'file5.txt'
#   delete_after_processing true
# end
