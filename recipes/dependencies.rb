#
# Cookbook:: zipr
# Recipe:: dependencies
#
# Description:: Installs all gems required by this cookbook. Should be included before calling any zipr cookbook resources
#

# gcc-c++ is required for seven_zip_ruby in centos/rhel
package 'gcc-c++' do
  action :nothing
  only_if { node.platform_family?('rhel') }
end.run_action(:install)

required_gems = {
  'seven_zip_ruby_am' => '1.2.5.4', # dependency of zipr gem
  'rubyzip' => '2.3.0', # dependency of zipr gem
  'os' => '1.1.0', # dependency of zipr gem
  'hashly' => '0.1.1', # dependency of easy_json_config
  'easy_json_config' => '0.3.0', # dependency of easy_io
  'logger' => '1.4.2', # dependency of easy_io
  'open3' => '0.1.0', # dependency of easy_io
  'easy_format' => '0.2.0', # dependency of easy_io gem
  'easy_io' => '0.4.2', # dependency of zipr gem
  'zipr' => '0.2.3',
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
