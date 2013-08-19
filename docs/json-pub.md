## Location object

This location object is published by the mobile apps and delivered by the backend JSON API.
The commments behind the elements document which of the apps (Android (a), iOS (i)) provide
the elements.

```json
{
    "lat": "xx.xxxxxx", 	// (a) (i)
    "lon": "y.yyyyyy", 		// (a) (i)
    "tst": "1376715317",	// (a) (i)
    "acc": "75m",		// (a) (i)
    "mo" : "<type>", 		// (i)
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
* `mo` is motion (e.g. `vehicle`, `on foot`, etc.) if available
* `alt` altitude, measured in meters (i.e. units of 100cm). Android provides the info, but it doesn't always contain anything useful.
* `vac`,  "xxxx" for vertical accuracy in meters - negative value indicates no valid altitude information
* `dir` is direction
* `vel` is velocity

## User object
```json
{
    "_type" : "user"
    "name": "testuser"
}
```

## Location indices 
```json
{
    "_type": "year"
    "value": "2013"
    "user" : "/users/1"
    "months" : "/users/1/years/2013/months"
    "locations" : "/users/1/locations?year=2013"
}
```
```json
{
    "_type": "month"
    "value": "12"
    "user" : "/users/1"
    "year" : "/users/1/years/2013"
    "days" : "/users/1/years/2013/months/12/days"
    "locations" : "/users/1/locations?year=2013&month=12"
}
```
```json
{
    "_type": "day"
    "value": "23"
    "user" : "/users/1"
    "year" : "/users/1/years/2013"
    "month" : "/users/1/years/2013/months/12"
    "locations" : "/users/1/locations?year=2013&month=12&day=23"
}
```


## Backend API

```none
GET /api/1/users
> {"items":[{"name" : foo}, {"name" : "bar"}]}
```

```none
GET /api/1/users/1
> {"name" : foo}
```

Query locations. All locations are sorted by decending by ```tst``` 
```none
GET /api/1/users/1/locations
=> tbd
```

```none
GET /api/1/users/1/locations?limit=1
=> tbd
```

```none
GET /api/1/users/1/locations?year=2013
# >, <, >=, <= operators also avilable
=> tbd

```

```none
GET /api/1/users/1/locations?month=1
# >, <, >=, <= operators also avilable
=> tbd
```

```none
GET /api/1/users/1/locations?day=13
# >, <, >=, <= operators also avilable
=> tbd
```

```none
GET /api/1/users/1/locations?tst=1376912006
# >, <, >=, <= operators also avilable
=> tbd
```

Index for dates with available location object. This index uses 365+12+1 = 378 database tupels per user per year. 
Compared to 24*2*365*1/3 = 5840 location entries per user per year at an intervall of 30 minutes assuming every third check results in new location data. 
```none
GET /api/1/users/1/years
=> tbd
```
```none
GET /api/1/users/1/years/2013
=> tbd
```
```none
GET /api/1/users/1/years/2013/months
=> tbd
```
```none
GET /api/1/users/1/years/2013/months/12
=> tbd
```
```none
GET /api/1/users/1/years/2013/months/12/days
=> tbd
```
```none
GET /api/1/users/1/years/2013/months/12/days/23
=> tbd
```
