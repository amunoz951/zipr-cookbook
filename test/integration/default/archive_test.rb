# # encoding: utf-8

# Inspec test for recipe zipr_test::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

test_folder = os.windows? ? 'C:/zipr_test' : '/zipr_test'

describe file("#{test_folder}/test_archive.zip") do
  it { should exist }
end

%w(file1 file5 nested/file7).each do |file_name|
  describe file("#{test_folder}/extract_test/#{file_name}.txt") do
    it { should exist }
  end
end

%w(file2 file3 file4 nested/file6 nested/file8).each do |file_name|
  describe file("#{test_folder}/extract_test/#{file_name}.txt") do
    it { should_not exist }
  end
end

%w(file1 file5 nested/file7).each do |file_name|
  describe file("#{test_folder}/extract_7z_test/#{file_name}.txt") do
    it { should exist }
  end
end

%w(file2 file3 file4 nested/file6).each do |file_name|
  describe file("#{test_folder}/extract_7z_test/#{file_name}.txt") do
    it { should_not exist }
  end
end

# delete_after_processing was executed for the resource extracting this file
describe file("#{test_folder}/test_archive2.7z") do
  it { should_not exist }
end

describe file("#{test_folder}/test_sfx.exe") do
  it { should exist }
end
