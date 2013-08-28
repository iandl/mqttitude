# Future

Thoughts on possible future enhancements.

## Short term

* Stability
* Reliability [#38](https://github.com/binarybucks/mqttitude/issues/38) 
* Battery consumption [#68](https://github.com/binarybucks/mqttitude/issues/68)
* Ensure UI has `Credits` with URL to Web site [#41](https://github.com/binarybucks/mqttitude/issues/41)
* Disable all location services (unload app) [#74](https://github.com/binarybucks/mqttitude/issues/74)
* LWT [#55](https://github.com/binarybucks/mqttitude/issues/55)

## Mid-term

* Add "traffic light" [#73](https://github.com/binarybucks/mqttitude/issues/73)
* Add live "info" pane to Apps [#47](https://github.com/binarybucks/mqttitude/issues/47)
* Remote-control [#71](https://github.com/binarybucks/mqttitude/issues/71)
* Annotations.
  * Click on pin
  * Enter text string `"Restaurante La Comida; wonderful gambas al ajillo"`
  * PUBlish with full `_location` and additional `"note" : "...."`


## Long-term

* Add presence. Are my friends in the area?
  * Needs friends/family on same broker
  * Needs 'standardized' topic names (maybe with Twitter id in topic?)
* Queue updates on device (with `tst` etc) to be PUBlished upon available connection

## Very-long term, a.k.a. "Neat ideas"

* Publish incoming phone call (caller-id), [submitted by @bordingnon](http://twitter.com/bordignon/status/372627079059079168). JPM: Also SMS? Have to force TLS then, at least.
