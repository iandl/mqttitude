$(document).ready(function() {
	var map;

  var bounds;

	(function initialize() {	  
		console.log("map init");
	  google.maps.visualRefresh = true;
	  map = new google.maps.Map(document.getElementById('map'), {
	    																													zoom: 14,
	    																													center: new google.maps.LatLng(52.3699, 9.7353),
	    																													mapTypeId: google.maps.MapTypeId.ROADMAP
	  																													}
	  );
	  bounds = new google.maps.LatLngBounds();
	})();


function addMarker(latitude, longitude, title) {

    var myLatLng = new google.maps.LatLng(latitude, longitude);
    var marker = new google.maps.Marker({
      position: myLatLng,
      map: map,
      title: title,
    });
    bounds.extend(myLatLng);

  map.fitBounds(bounds);
}



	$("#positions > li").click(function(e) {
		console.log("clicked")
		var latitude = $(this).data('lat');
		var longitude = $(this).data('long'); 
		var timestamp = $(this).data('timestamp');
		addMarker(latitude, longitude, "asdf");
		// console.log("Showing %s %s %s", latitude, longitude, timestamp);


  // 	var marker = new google.maps.Marker({
  //     position: new google.maps.LatLng(latitude, longitude) ,
  //     map: map,
  //     title: timestamp
  // });


	});


});