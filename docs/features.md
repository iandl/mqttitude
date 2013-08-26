# Features


This is **preliminary** documentation and **subject to change dramatically!**

## General

* Location information is PUBlished as a JSON string. [See json-pub](json-pub.md).

# Currently implemented

## Android

* The broker connection works well with:

  * No TLS (i.e. plain)
  * TLS using the Android build in certificate authorities (either the shipped
ones, or user provided ones that require a lock screen password to be set)
  * TLS with user-provided certificates via an absolute path (e.g. to Downloads).
    This doesn't require a password to be set on the device, but is a bit fiddly
    to set up.
  * Username/password auth works.

* Automatic publishes at configurable intervals (disabled or > 1 minute)

* Display of a marker at which the app believes the user to be at
  (lastKnownLocation)

* Reverse geo coding that displays the address of lastKnownLocation

* Accuracy of lastKnownLocation (if the accuracy is > 250m, the marker
  changes to a circle centered around lastKnownLocation with radius == accuracy)

* Button to manually publish  lastKnownLocation

* Button to share a Google Maps link that places a marker at lastKnownLocation

* For location the Google Fused Location Provider at Balanced Battery
  Settings is used. This one can re use GPS or other Position fixes that are
  requested by other apps in order to save battery and select the most
  appropriate position source.


## iOS

* Runs on iPhones running IOS >=6.1 (3GS, 4, 4S, 5) and iPads running IOS >=6.1 as an iPhone app. Not tested on iPods yet.

* Monitors "significant location changes" as define by Apple Inc (about 5 minutes and
  "significant location changes" (>500m))

* Displays a map with the current location and marks the last ~50 locations with timestamp, name and reverse-geocoded location

* Shows the well-known map-user-tracking-button

* Shows a button to explicitly mark the current location on the map and...

* ... publish this location via MQTT to the configured server

* All configration parameters are accessible via the settings-button

* MQTT server is configured by 
	* specifying hostname/ip-address,
	* port,
	* whether TLS is used and/or 
	* authentication is done via user/password

* If TLS is used, the server certificate needs to be distributed separately and installed on the IOS device

* Data published on the server lablelled with a user-configurable `topic`. The data in JSON format contains
	* a timestamp
	* longitude and latitude and horizontal accuracy
	* altitude and vertical accuracy
	* velocity and direction

* MQTT parameters are
	* QoS and
	* Retain

* Scrollable log of last 50 locations published on the map

* Connection indicator light shows current status of the MQTT server connection
  The server connection is established automatically when a new location shall be published. In order to save 
  battery power, the connection is closed after 15 seconds to save enery on the IOS device.
	* BLUE=IDLE, no connection established to save battery power
	* GREEN=CONNECTED, server connection established
	* AMBER=ERROR OCCURED, WAITING FOR RECONNECT, app will automatically try to reconnect to the server
	* RED=ERROR, no to the server possible or transient errror condition

* Stop-Button to complete shut down the app, location monitoring and server publishes und subscriptions (quiet and private)

* Application supports a background-mode
	* "significant location changes" are automatically published to the MQTT server
	* app listens to commands published by the server on topic <my topic>/listento. commands defined are
		* `publish`: app publishes current location immediately to the server
		* ...
	* app listens to all published locations of other devices and displays the last location published per device on it's map
	* app shows an application badge indicating the number of other device's loctions on it's map
	* app connects once per hour to collect commands or other device's locations
