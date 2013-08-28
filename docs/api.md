## API

The MQTTitude backend is designed to store locations that are provided by mobile apps into a database. 
It provides a REST API that can be accessed to view and manage stored locations. 

Before proceeding, please read and understand the following
* The backend does not protect your data during transport. It is strongly advised to issue API calls over a secure connection. 
* The current API version 1 is not finished subject to change at any time 


### API Version 1

This document assumes that the MQTTitude backend is running on ```localhost```.

#### Users

**Request** ```GET /api/v1/users/{id}```  
**Description:** Gets the user specified by ```id```.   
**Request authentication**: yes  
**Response**: 

#### Locations

#### Subscriptions

#### Authentication
