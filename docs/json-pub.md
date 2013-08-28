## Location object

This location object is published by the mobile apps and delivered by the backend JSON API.
The commments behind the elements document which of the apps (Android (a), iOS (i)) provide
the elements.

```json
{
    "_type": "location",	// (a) (i)
    "lat": "xx.xxxxxx", 	// (a) (i)
    "lon": "y.yyyyyy", 		// (a) (i)
    "tst": "1376715317",	// (a) (i)
    "acc": "75m",		// (a) (i)
    "alt" : "mmmmm",		// (a) (i)
    "vac" : "xxxx",		// (i)
    "dir" : "xxx",		// (i)
    "vel" : "xxx",		// (i)
}
```

* `lat` is latitude as decimal, represented as a string
* `lon` is longitude as decimal, represented as a string
* `tst` is a UNIX [epoch timestamp](http://en.wikipedia.org/wiki/Unix_time)
* `acc` is accuracy if available
* `alt` altitude, measured in meters (i.e. units of 100cm). Android provides the info, but it doesn't always contain anything useful.
* `vac`,  "xxxx" for vertical accuracy in meters - negative value indicates no valid altitude information
* `dir` is direction
* `vel` is velocity
