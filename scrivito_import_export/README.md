# Scrivito/Fiona 8 Importer and Exporter

These scripts can be used to export a snapshot of the Scrivito/Fiona 8 content to disk and to load
it back into a Scrivito/Fiona 8 tenant.

Note that the importer removes all existing content from the tenant prior to importing content!

## Requirements

HTTPS access to Fiona 8 or Scrivito.
Provide these env variables: `SCRIVITO_BASE_URL`, `SCRIVITO_TENANT`, `SCRIVITO_API_KEY`.

```
export SCRIVITO_BASE_URL=https://api.scrivito.com # or your Fiona 8 backend URL
export SCRIVITO_TENANT=your_tenant_id
export SCRIVITO_API_KEY=your_api_key
```

## Usage of the exporter

```
bundle exec ruby scrivito_export.rb "./export" | tee export.log
```

## Usage of the importer

```
bundle exec ruby scrivito_import.rb "./export" | tee import.log
```
