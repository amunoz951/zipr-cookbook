#
# Cookbook Name:: zip-file
# Recipe:: default
#
# Copyright (c) 2016 The Authors, All Rights Reserved.
#
# require 'seven_zip_ruby'
#
# File.open('C:/Test/Test.7z') do |file|
#   SevenZipRuby::Reader.open(file) do |szr|
#     list = szr.entries
#     list.each do |entry|
#       p entry.sha
#     end
#     # puts '***********'
#
#     # pp list
#     # => [ "#<EntryInfo: 0, dir, dir/subdir>", "#<EntryInfo: 1, file, dir/file.txt>", ... ]
#   end
# end
