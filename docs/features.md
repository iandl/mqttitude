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

* Automatic publishes at "Apple" intervals (about 5 minutes and
  "significant location changes" (>500m)). This is the appropriate way to
  save battery power.

* Displays a marker where the app believes the user to be and marks of all
  previous published locations

* Accuracy is recorded

* Button to manually publish last location

* QoS and Retain are UI-configurable

* Scrollable log of last 50 status changes/published locations
