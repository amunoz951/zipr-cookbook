# # encoding: utf-8

# Inspec test for recipe zipr_test::default

# The Inspec reference, with examples and extensive documentation, can be
# found at http://inspec.io/docs/reference/resources/

describe file('C:/zipr_test/test_archive.zip') do
  it { should exist }
end

%w(file1 file5 nested/file7).each do |file_name|
  describe file("C:/zipr_test/extract_test/#{file_name}.txt") do
    it { should exist }
  end
end

%w(file2 file3 file4 nested/file6 nested/file8).each do |file_name|
  describe file("C:/zipr_test/extract_test/#{file_name}.txt") do
    it { should_not exist }
  end
end

# describe file('C:/zipr_test/test_archive2.7z') do
#   it { should exist }
# end

# %w(file1 file5 nested/file7).each do |file_name|
#   describe file("C:/zipr_test/extract_7z_test/#{file_name}.txt") do
#     it { should exist }
#   end
# end

# %w(file2 file3 file4 nested/file6).each do |file_name|
#   describe file("C:/zipr_test/extract_7z_test/#{file_name}.txt") do
#     it { should_not exist }
#   end
# end
