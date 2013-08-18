# MQTTitude

MQTTitude is an app (well, two apps actually -- one for Android, and for iOS),
which allow a device to periodically publish its location status to an [MQTT]
server. If you've previously used Google Latitude, you can think of this as a a
_decentralized Google Latitude_. MQTTitude was started because Google Latitude
was de-comissioned in August 2013.

Whether you want to keep track of your own location or that of a family member (with
their consent, of course), MQTTitude will let you do that in a safe way.

* MQTTitude uses TLS to communicate with a broker. (You can disable TLS if you
  know you don't want it.)
* MQTTitude encourages you to use your own broker so that you know where the
  location data goes to.
* MQTTitude is extensible: you can handle the location data received by the
  broker in any which way you desire.

## Components

There are three components to MQTTitude (and a whole slew of useful things you can do
with them):

* The _App_, or front-end which runs on a supported device. This reports location
  data to the [MQTT] broker. The app will be made available for iOS on the App store and for
  Android on Google Play.
* The MQTT broker is the service with which the App talks. You set up your own
  broker (which is easy to do) or use an existing broker, for example one of the
  test brokers or that of a friend. The important thing is: _MQTTitude doesn't enforce
  a particular broker on you_! You are free to choose where your data is stored.
* The MQTTitude back-end.

Both the App and the back-end talk to the broker (shown in the diagram below).
You can also have other programs obtain the data from the broker (MQTTitude
uses [JSON] for which there is support in almost any language you can imagine.)

 ![Architecture](mqttitude.png)

## Getting started

Before you get all excited and install the app, you need an [MQTT] broker. We
recommend you set one up yourself, on a Raspberry Pi, say, or use one of the [existing
public brokers][publicbroker]. If you choose the latter, be aware that your
location data will no longer be private: anybody can find it and follow you on
one of the public broker.


  [MQTT]: http://mqtt.org
  [JSON]: http://json.org
  [TLS]: http://en.wikipedia.org/wiki/Transport_Layer_Security
  [publicbroker]: http://mqtt.org/wiki/doku.php/public_brokers
