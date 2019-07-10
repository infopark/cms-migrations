# Fiona 7 with Scrivito UI Exporter

**For Fiona 7 with Scrivito SDK (hybrid) in stand-alone or legacy mode.**

The Fiona 7 exporter exports the Fiona 7 content in a format that is suitable for importing into
Fiona 8 or Scrivito. If edited is set to true, the export will contain the edited versions of
objects as opposed to only the published versions.

The Fiona 7 exporter exists in a stripped-down Rails apps because the Fiona connector gems require
Rails.

## Requirements

A MySQL connection. Edit `MYSQL_HOST`, `MYSQL_CMS_DB`, `MYSQL_CMS_USER`, `MYSQL_CMS_PASSWORD` and `MYSQL_PORT` in
`.env`.

Change the `FIONA7_INSTANCE` and `FIONA7_MODE (standalone|legacy)` variables in `.env` if needed.

## Usage

The specified export directory must not exist. It will be created.

```shell
rails runner 'Fiona7Export.new.export(dir_name: "export", options: {path: "/", edited: false})'
```

This will export all objects in your Fiona7 system.

## Partial export

If you want to export only specific objects, you can run

```shell
rails runner 'Fiona7Export.new.export(dir_name: "export", options: {id: "id", edited: false})'
```

To export a subtree, use the obj path like:

```shell
rails runner 'Fiona7Export.new.export(dir_name: "export", options: {path: "/path/to/obj", edited: false})'
```

Exporting all objs by type, if you onle want to migrate e.g. all User Objects, you can use:

```shell
rails runner 'Fiona7Export.new.export(dir_name: "export", options: {obj_class: "User", edited: false})'
```
