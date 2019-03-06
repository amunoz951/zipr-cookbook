#
# Cookbook Name:: zipr
# Recipe:: default
#

chef_gem 'rubyzip' do
  action :install
  compile_time true
  version '1.2.0'
  not_if { Gem::Version.new(Chef::VERSION) >= Gem::Version.new('13.0.0') }
end
