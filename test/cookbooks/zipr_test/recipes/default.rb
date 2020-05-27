#
# Cookbook:: zipr_test
# Recipe:: default
#
# Copyright:: 2018, Alex Munoz, All Rights Reserved.

Chef::Log.info 'Creating test files'
test_folder = node.platform?('windows') ? 'C:/zipr_test' : '/zipr_test'

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

# rubyzip based resources
zipr_archive "#{test_folder}/test_archive.zip" do
  action :create
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/*.txt") # only pick up the txt files in the test_folder
  exclude_files 'file4.txt'
end

# This should not create the archive as it should already exist and the action is :create_if_missing - file4.txt should not be added to zip
zipr_archive "Create if missing: #{test_folder}/test_archive.zip" do
  action :create_if_missing
  archive_path "#{test_folder}/test_archive.zip"
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/**/*")
  exclude_files '*.exe'
end

# This should create the archive as it doesn't already exist and the action is :create_if_missing - file4.txt should not be added to zip
zipr_archive "Create if missing: #{test_folder}/test_archive_cim.zip" do
  action :create_if_missing
  archive_path "#{test_folder}/test_archive.zip"
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/**/*")
  exclude_files '*.exe'
end

# This should add nested folder to the existing archive created earlier
zipr_archive 'Add nested folder' do
  action :create
  archive_path "#{test_folder}/test_archive.zip"
  archive_type :zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/**/*")
  exclude_files ['file4.txt', 'test_archive*.*', 'extract_*test', 'nested/file8.txt', '*.exe']
end

zipr_archive "Extract #{test_folder}/test_archive.zip" do
  action :extract
  archive_path "#{test_folder}/test_archive.zip"
  destination_folder "#{test_folder}/extract_test"
  exclude_files ['file2.txt', 'file3.txt', '**/file6.txt']
  exclude_unless_missing 'file5.txt'
end

# seven_zip based resources
zipr_archive "#{test_folder}/test_archive2.7z" do
  action :create
  archive_type :seven_zip
  source_folder test_folder
  target_files Dir.glob("#{test_folder}/*.txt") + ["#{test_folder}/nested/file7.txt"]
  exclude_files ['file2.txt', 'file4.txt']
end

zipr_archive "Extract #{test_folder}/test_archive2.7z" do
  action :extract
  archive_path "#{test_folder}/test_archive2.7z"
  destination_folder "#{test_folder}/extract_7z_test"
  exclude_files 'file3.txt'
  exclude_unless_missing 'file5.txt'
  delete_after_processing true
end

zipr_sfx "#{test_folder}/test_sfx.exe" do
  action :create
  installer_title 'Test Installer'
  installer_executable 'msiexec /quiet /package testpackage.msi'
  target_files "#{test_folder}/**/*"
  source_folder test_folder
  exclude_files ['extract_*test', 'test_sfx.exe']
end
