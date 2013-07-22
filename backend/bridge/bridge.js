var r = require("redis"),
    redis = r.createClient(),
    mqtt = require("mqtt");

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
		var userid = 1; //todo

		redis.incr("Position:id", function(err, positionId){

		console.log("next position is: " + positionId);
		redis.hmset("Position:"+positionId, "timestamp", Date.now()/1000 |0, "lat", message.split(":")[0], "long", message.split(":")[1]);
		redis.sadd("Position:all", positionId);
		redis.lpush("User:"+userid+":positions",positionId);
 });             
	

	//	self.emit('message', {topic: topic, payload: message, qos: etc.qos, retain: etc.retain, messageId: etc.messageId });
		});





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
