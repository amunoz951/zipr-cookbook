# zipr Cookbook

[![Cookbook Version](https://img.shields.io/badge/cookbook-5.0.1-green.svg)](https://supermarket.chef.io/cookbooks/zipr)

Provides idempotent resources and helper methods for extracting and compressing zip and 7-zip files

## Contents

- [Attributes](#attributes)
- [Resources](#resources)

  - [zipr_archive](#zipr_extract) Extracts a zip file idempotently or creates a zip archive.
  - [zipr_sfx](#zipr_sfx) Creates a self extracting 7-zip archive.

- [Usage](#usage)

  - [default](#default) Default recipe

- [Alternatives](#alternative-cookbooks)

- [License and Author](#license-and-author)

## Requirements

### Platforms

- Windows Server 2012 (R2)
- Centos

### Chef

- Chef 12+
- If chef-client version is <= 13.4, pin windows cookbook to a version <= 4.3.4 if using windows

### Cookbooks

- no cookbook dependencies

## Attributes

  none

## Resource/Provider

### zipr_archive

Creates or extracts an archive

#### Actions

`default` = `:extract`

- `:extract` - extracts an existing zip file; suggestion: use a :before notification to download the zip file
- `:create` - creates a zip file
- `:create_if_missing` - creates a zip file only if it does not exist

#### Properties

- `archive_path` - Specifies the path to the zip file. String, name property
- `exclude_files` - Exclude files from extraction or compression. Use relative paths for extraction and full paths or Dir.glob style wildcards for compression. String or array of strings, default: `[]`
- `exclude_unless_missing` - Exclude files from extraction if the destination file already exists, only used during `:extract`. String or array of strings, default: `[]`
- `archive_type` - The type of archive being created or extracted. Symbol, default: `:zip` unless file extension is .7z, options: `:zip`, `:seven_zip`
- `target_files` - The files to be compressed, only used during `:create` and `:create_if_missing`. String or array of strings, default: `[]`
- `source_folder` - The folder where the target_files reside and will be used as the root for archive paths, only used during `:create` and `:create_if_missing`. String, default: `''`
- `destination_folder` - The destination folder where a zip file is extracted, only used during `:extract`. String, required for action: `:extract`
- `checksum_file` - Optional property to override the checksum file path. String or nil, default: `nil`
- `delete_after_processing` - Deletes source files after processing, such as a zip file when extracting or source files when creating an archive. True or false, default: `false`
- `password` - The password needed to access an existing archive, only used during `:extract`. String or nil, default: `nil`

#### Examples

```ruby
# Extract files from test_archive.zip
zipr_archive '/zipr_test/test_archive.zip' do
  destination_folder '/zipr_test/extract_test'
  exclude_files ['file1.txt', 'subfolder/file2.txt']
  exclude_unless_missing 'app.config'
  delete_after_processing true
  action :extract
  notifies :create, 'remote_file[/zipr_test/test_archive.zip]', :before
end
```

```ruby
# Create the archive test_archive.7z from the files returned by Dir.glob('/zipr_test/**/*') excluding /zipr_test/file1.txt
zipr_archive "/zipr_test/test_archive.7z" do
  archive_type :seven_zip
  target_files Dir.glob('/zipr_test/**/*')
  exclude_files '/zipr_test/file1.txt'
  action :create
end
```

### zipr_sfx

Creates a self-extracting Windows executable

#### Actions

`default` = `:create`

- `:create` - creates an SFX archive
- `:create_if_missing` - creates an SFX archive only if it does not exist

#### Properties

- `archive_path` - Specifies the path of the desired self-extracting archive. String, name property
- `exclude_files` - Exclude files from extraction or creation. Use full paths or Dir.glob style wildcards. String or array of strings, default: `[]`
- `target_files` - The files to be compressed. String or array of strings, required property.
- `source_folder` - The folder where the target_files reside and will be used as the root for archive paths. String, default: Parent folder of first target_file.
- `delete_after_processing` - Deletes source files after processing. True or false, default: `false`
- `extract_path` - The relative or full path to the folder where files are extracted during execution of SFX archive. String, default: `'.\unpack'`
- `installer_title` - The title of the SFX installer window. String, required if `info_file_path` is not specified.
- `installer_executable` - The executable to be launched after SFX extraction. String, required if `info_file_path` is not specified.
- `info_file_path` - Optionally specify the path to a 7zip SFX info_file. examples: https://sevenzip.osdn.jp/chm/cmdline/switches/sfx.htm. String.

#### Examples

```ruby
# Create a self-extracting Windows executable at "
zipr_sfx "C:/zipr_test/test_sfx.exe" do
  action :create
  installer_title 'Test Installer'
  installer_executable 'msiexec /quiet /package testpackage.msi'
  target_files "C:/zipr_test/**/*"
  source_folder "C:/zipr_test"
end
```

## Usage

### default recipe

Installs seven_zip_ruby and rubyzip gems

## License and Author

- Author:: Alex Munoz ([amunoz951@gmail.com](mailto:amunoz951@gmail.com))

```text
Copyright 2016-2022, Alex Munoz.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
