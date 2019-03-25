# Fiona 6/7 Classic Exporter

The Fiona 6/7 Classic exporter exports the Fiona content in a format that is suitable for importing
into Fiona 8 or Scrivito. If edited is set to true, the export will contain the edited versions of
objects as opposed to only the published versions.

The Fiona 6 exporter exists in a stripped-down Rails apps because the Fiona connector gems require
Rails.

## Requirements

Fiona must be "railsified". To do this, run `./bin/CM -railsify` in the Fiona instance.

A MySQL connection. Edit `MYSQL_HOST`, `MYSQL_CMS_DB`, `MYSQL_CMS_USER`, `MYSQL_CMS_PASSWORD` in
`.env`.

## Usage

The specified export directory must not exist. It will be created.

```shell
rails runner 'Fiona6Export.new.export(dir_name: "export", edited: false)'
```
