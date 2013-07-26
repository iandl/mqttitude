var r = require("redis"),
    redis = r.createClient(),
    mqtt = require("mqtt");
var request = require("request");
require('date-utils');

redis.on("error", function (err) {
    console.log("Error " + err);
});

var mqttClient = mqtt.createClient(8882, "127.0.0.1", {"username":"scrubber", "password":"scrubber"});



	  mqttClient.on('connect', function() {
 	  mqttClient.subscribe("/location/bucks/"),
console.log("subscribed");


		});

	  mqttClient.on('close', function() {
console.log("close");
	    process.exit(-1);
	  });

	  mqttClient.on('error', function(e) {
	console.log(e);
	    process.exit(-1);
	  });

	 	mqttClient.on('message', function(topic, message, etc) {
	 	console.log("%s: received %s:%s", Date.now() /1000 |0, topic, message);
		// var userid = 1; //todo

		// redis.incr("Position:id", function(err, positionId){

		// console.log("next position is: " + positionId);
var date = new Date();


		request({
		  uri: "http://192.168.8.2:9393/user/bucks/positions",
		  method: "POST",
		  form: {
		  	lat: message.split(":")[0],
		    long: message.split(":")[1],
		    timestamp: date.getTime(),
		    y: date.toFormat('YYYY'),
		    m: date.toFormat('M'),
		    d: date.toFormat('D'),
		  }
		}, function(error, response, body) {
		  console.log(body);
		});



		// redis.hmset("Position:"+positionId, "timestamp", Date.now()/1000 |0, "lat", message.split(":")[0], "long", message.split(":")[1]);
		// redis.sadd("Position:all", positionId);
		// redis.lpush("User:"+userid+":positions",positionId);
 });             
	

	//	self.emit('message', {topic: topic, payload: message, qos: etc.qos, retain: etc.retain, messageId: etc.messageId });
		// });





//client.set("string key", "string val", redis.print);
//client.hset("hash key", "hashtest 1", "some value", redis.print);
//client.hset(["hash key", "hashtest 2", "some other value"], redis.print);
//client.hkeys("hash key", function (err, replies) {
//   console.log(replies.length + " replies:");
//    replies.forEach(function (reply, i) {
//        console.log("    " + i + ": " + reply);
//    });
//    client.quit();
//});
