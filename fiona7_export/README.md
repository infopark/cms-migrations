# Fiona 7 with Scrivito UI Exporter

**Only for Fiona 7 with Scrivito UI (hybrid) in stand-alone mode.**

The Fiona 7 exporter exports the Fiona 7 content in a format that is suitable for importing into
Fiona 8 or Scrivito. If edited is set to true, the export will contain the edited versions of
objects as opposed to only the published versions.

The Fiona 7 exporter exists in a stripped-down Rails apps because the Fiona connector gems require
Rails.

## Requirements

A MySQL connection. Edit `MYSQL_HOST`, `MYSQL_CMS_DB`, `MYSQL_CMS_USER`, `MYSQL_CMS_PASSWORD` in
`.env`.

## Usage

The specified export directory must not exist. It will be created.

```shell
rails runner 'Fiona7Export.new.export(dir_name: "export", edited: false)'
```
