require 'spec_helper'

describe file('C:/zipr_test/test_archive.zip') do
  it { should exist }
end

%w(file1 file5).each do |file_name|
  describe file("C:/zipr_test/extract_test/#{file_name}.txt") do
    it { should exist }
  end
end
