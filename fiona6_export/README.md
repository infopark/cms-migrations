# Fiona 6/7 Classic Exporter

The Fiona 6/7 Classic exporter exports the Fiona content in a format that is suitable for importing
into Fiona 8 or Scrivito. The export contains the released versions of all objects.

The Fiona 6 exporter exists in a stripped-down Rails apps because the Fiona connector gems require
Rails.

## Requirements

Fiona must be "railsified". To do this, run `./bin/CM -railsify` in the Fiona instance.

A MySQL connection. Edit `MYSQL_HOST`, `MYSQL_CMS_DB`, `MYSQL_CMS_USER`, `MYSQL_CMS_PASSWORD` in
`.env`.

Bundler version 1.x, e.g. 1.16.5.

## Usage

```shell
rails runner 'Fiona6Export.new.analyze(output_config: "export-config.json")'
```

This command analyzes obj classes and attributes for compatibility with Fiona 8 and Scrivito. For
example, Fiona 8/Scrivito does not allow to have attributes with uppercase letters or a leading
underscore. Hence those attributes need to be renamed. The analyze command suggests new attribute
names. It writes out a configuration file `export-config.json` with this info. Please edit this file
if you're not happy with the suggestions.


```shell
rails runner 'Fiona6Export.new.export(config: "export-config.json", dir_name: "export")'
```

This command exports the content of all obj (except templates) to the specified directory. The
directory must not exist. It will be created. The command also reads in the `export-config.json`
from the analyze run and renames attributes as specified in this file.
