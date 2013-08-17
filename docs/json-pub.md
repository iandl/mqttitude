## Format of JSON

```json
{
    "lat": "xx.xxxxxx", 
    "lon": "y.yyyyyy", 
    "tst": "1376715317",
    "acc": "75m",
    "mo" : "<type>"
}
```

* `lat` is latitude as decimal, represented as a string
* `lon` is longitude as decimal, represented as a string
* `tst` is a UNIX epoch timestamp (i.e. number of seconds since 1970-01-01 etc.)
* `acc` is accuracy if available
* `mo` is motion (e.g. `vehicle`, `on foot`, etc.) if available
