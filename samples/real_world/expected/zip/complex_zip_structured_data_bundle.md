# .hidden/manifest.txt

internal

# csv/sales.csv

| account | month | amount |
| --- | --- | --- |
| core | 2026-01 | 1200 |
| edge | 2026-02 | 980 |

# docs/notes.md

# Notes

Use `./samples/check.sh --real-world --tags complex` for long-form scenarios.

# json/api-response.json

| Key | Value |
| --- | --- |
| service | markitdown-mb |
| releases | [{"version":"0.3.1","status":"published"},{"version":"0.3.2-rc1","status":"draft"}] |
| flags | {"real_world_complex":true} |

# logs/raw.txt

line 1 line 2 with commas, tabs	and markers

# nested/archive.zip

> Skipped: nested archive is not supported: zip

# tsv/regions.tsv

| region | owner | status |
| --- | --- | --- |
| East | Ada | stable |
| West | Bob | review |

# xml/feed.xml

```xml
<?xml version="1.0" encoding="UTF-8"?><feed><item priority="high">validation</item><item priority="medium">docs</item></feed>
```

# yaml/deploy.yaml

| Key | Value |
| --- | --- |
| service | markitdown-mb |
| env | staging |
| checks | [markdown, metadata, assets] |
