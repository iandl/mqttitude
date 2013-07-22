$(document).ready(function() {
	var locations = $('#locations');

	(function initialize() {	  
	  google.maps.visualRefresh = true;
	  map = new google.maps.Map(document.getElementById('map'), {
	    																													zoom: 14,
	    																													center: new google.maps.LatLng(52.3699, 9.7353),
	    																													mapTypeId: google.maps.MapTypeId.ROADMAP
	  																													}
	  );
	})();

});