#
# Cookbook:: zipr
# Recipe:: dependencies
#
# Description:: Installs all gems required by this cookbook. Should be included before calling any zipr cookbook resources
#

if node.platform_family?('rhel')
  # gcc-c++ is required for seven_zip_ruby in centos/rhel
  package 'gcc-c++' do
    action :nothing
    source node['zipr']['gcc-c++']['source']
  end.run_action(:install)

  # binutils needs an update when centos is below 7.8
  package 'binutils' do
    action :nothing
    version '2.27'
    source node['zipr']['binutils']['source']
    only_if { platform?('centos') && ::Gem::Version.new(node['platform_version']) < ::Gem::Version.new('7.8') }
  end.run_action(:install)
end

required_gems = {
  'seven_zip_ruby' => '1.3.0', # dependency of zipr gem
  'rubyzip' => '2.3.0', # dependency of zipr gem
  'os' => '1.1.0', # dependency of zipr gem
  'hashly' => '0.2.0', # dependency of easy_json_config
  'easy_json_config' => '0.4.0', # dependency of easy_io
  'logger' => '1.4.2', # dependency of easy_io
  'open3' => '0.1.0', # dependency of easy_io
  'easy_format' => '0.2.0', # dependency of easy_io gem
  'sys-filesystem' => '1.4.3', # dependency of easy_io gem
  'easy_io' => '0.6.0', # dependency of zipr gem
  'zipr' => '0.4.1',
}
required_gems.each do |gem_name, gem_version|
  chef_gem gem_name do
    version gem_version
    compile_time true
    action :install
  end
end

require 'zipr'

EasyIO.logger = Chef::Log
