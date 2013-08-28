# API

The MQTTitude backend is designed to store locations that are provided by mobile apps into a database. 
It provides a REST API that can be accessed to view and manage stored locations. 

Before proceeding, please read and understand the following
* The backend does not protect your data during transport. It is strongly advised to issue API calls over a secure connection. 
* The current API version 1 is not finished subject to change at any time 


## API Version 1

This document assumes that the MQTTitude backend is running on ```localhost```.

### Users

**Get user**
```
GET /api/v1/users/{:user_id}  
> Content-Type: application/json  
```
```
< 200  
< Content-Type: application/json  
{"type_":"user","id":1,"name":"testuser"}
```

**Get current user**
```
GET /api/v1/users/me
> Content-Type: application/json  
```
```
< 200  
< Content-Type: application/json  
{"type_":"user","id":1,"name":"testuser"}
```

**Create user**
```
POST /api/v1/users
{ "name": "testuser", "password": "secret"}
```
```
< 200  
< Content-Type: application/json  
{"type_":"user","id":1,"name":"testuser"}
```


### Locations
**Get user's locations**
```
GET /api/v1/users/{:user_id}/locations
> Content-Type: application/json  
```
```
< 200  
< Content-Type: application/json  
[{"type_":"location",...}]
```


### Subscriptions

#### Authentication
```
POST /api/v1/authentication
{ "name": "testuser", "password": "secret"}
```
```
< 200  
< Content-Type: application/json  
{"type_":"user","id":1,"name":"testuser", "key": "secretsecretsecret"}
```


