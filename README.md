# zipr Cookbook

[![Cookbook Version](https://img.shields.io/badge/cookbook-1.0.7-green.svg)](https://supermarket.chef.io/cookbooks/zipr)

Provides resources and helper methods for extracting and compressing files

## Contents

- [Attributes](#attributes)
- [Resources](#resources)

  - [zipr_archive](#zipr_extract) Extracts a zip file idempotently or creates a zip archive.
  - [zipr_sfx](#zipr_sfx) Creates a self extracting 7-zip archive.

- [Usage](#usage)

  - [default](#default) Default recipe
  - [mod_*](#mod_) Recipes for installing individual IIS modules (extensions).

- [Alternatives](#alternative-cookbooks)

- [License and Author](#license-and-author)

## Requirements

### Platforms

- Windows Server 2012 (R2)
- Centos

### Chef

- Chef 13+

### Cookbooks

- seven_zip

## Attributes

- `node['seven_zip']['home']` - 7-zip home directory. default is `%PROGRAMFILES%\7-zip`

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
- `delete_after_processing` - Deletes source files after processing, such as a zip file when extracting or source files when creating an archive. True or false, default: `false`
- `exclude_files` - Exclude files from extraction or creation. Use relative paths for extraction and full paths for creation. String or array of strings, default: `[]`
- `archive_type` - The type of archive being created or extracted. Symbol, default: `:zip`, options: `:zip`, `:seven_zip`
- `target_files` - The files to be compressed, only used during `:create` and `:create_if_missing`. String or array of strings, default: `[]`
- `destination_folder` - The destination folder where a zip file is extracted, only used during `:extract`. String, required for action: `:extract`
- `exclude_unless_missing` - Exclude files from extraction if the destination file already exists, only used during `:extract`. String or array of strings, default: `[]`

#### Examples

```ruby
# Add foo.html to default documents, and add '.dmg' as mime type extension at root level
zipr_archive 'C:/zipr_test/test_archive.zip' do
  destination_folder 'C:/zipr_test/extract_test'
  exclude_files ['file1.txt', 'subfolder/file2.txt']
  exclude_unless_missing 'app.config'
  delete_after_processing true
  action :extract
  notifies :create, 'remote_file[C:/zipr_test/test_archive.zip]', :before
end
```

```ruby
# Create the archive test_archive.7z from the files returned by Dir.glob('C:/zipr_test/**/*') excluding C:/zipr_test/file1.txt
zipr_archive "C:/zipr_test/test_archive.7z" do
  archive_type :seven_zip
  target_files Dir.glob('C:/zipr_test/**/*')
  exclude_files 'C:/zipr_test/file1.txt'
  action :create
end
```

## Usage

### default recipe

Installs seven_zip gem

## License and Author

- Author:: Alex Munoz ([amunoz951@gmail.com](mailto:amunoz951@gmail.com))

```text
Copyright 2016-2018, Alex Munoz.

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
