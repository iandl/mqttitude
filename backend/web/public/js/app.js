// $(document).ready(function() {
// 	var map;

//   var bounds;

// 	(function initialize() {	  
// 		console.log("map init");
// 	  google.maps.visualRefresh = true;
// 	  map = new google.maps.Map(document.getElementById('map'), {
// 	    																													zoom: 14,
// 	    																													center: new google.maps.LatLng(52.3699, 9.7353),
// 	    																													mapTypeId: google.maps.MapTypeId.ROADMAP
// 	  																													}
// 	  );
// 	  bounds = new google.maps.LatLngBounds();
// 	})();


// function addMarker(latitude, longitude, title) {

//     var myLatLng = new google.maps.LatLng(latitude, longitude);
//     var marker = new google.maps.Marker({
//       position: myLatLng,
//       map: map,
//       title: title,
//     });
//     bounds.extend(myLatLng);

//   map.fitBounds(bounds);
// }



// 	$("#positions > li").click(function(e) {
// 		console.log("clicked")
// 		var latitude = $(this).data('lat');
// 		var longitude = $(this).data('long'); 
// 		var timestamp = $(this).data('timestamp');
// 		addMarker(latitude, longitude, "asdf");
// 		// console.log("Showing %s %s %s", latitude, longitude, timestamp);


//   // 	var marker = new google.maps.Marker({
//   //     position: new google.maps.LatLng(latitude, longitude) ,
//   //     map: map,
//   //     title: timestamp
//   // });


// 	});


// });





$(function(){


  var TreeItem = Backbone.Model.extend({
  	 getParentOfType: function(type) {
  	 	if(this instanceof type)
	  	 	return this;
  		else 
  			return this.getParent()	.getParentOfType(type);
  	 },

  	 getParent: function(){
  	 	  return this.get('parent');
  	 },

  	 getChildren: function(callback){
 			if(this.children.length > 0)
  	 		callback(this.children);
 			else
  	 		this.children.fetch({success: callback});
  	 },
  });



  var Year = TreeItem.extend({


  	initialize: function() {
  	 	this.children = new MonthCollection();
  		this.children.parent = this; 
  	},

	 getChildrenUrl: function(){
  		return "/users/bucks/dates/years/" + this.id + "/months";
  	},

  	getParent: function(){
  		return this; 
  	},

  });


  var Month = TreeItem.extend({
  	initialize: function() {
  		this.children = new DayCollection();
  		this.children.parent = this;
  	},

  getChildrenUrl: function(){
  		return "/users/bucks/dates/years/" + this.getParentOfType(Year).id + "/months/" + this.id + "/days";
  	},
  });

  var Day = TreeItem.extend({
  	initialize: function() {
			this.children = new PositionCollection();
  		this.children.parent = this;
  	},

		getChildrenUrl: function(){
  		return "/users/bucks/positions/" + this.getParentOfType(Year).id + "/" + this.getParentOfType(Month).id + "/" + this.getParentOfType(Day).id;
  	}
  });

    var Position = Backbone.Model.extend({

    });



  var TreeLeaves = Backbone.Collection.extend({
  	parse: function(response, options) {
			if (response) {		
				var listSource = new Array();
				var self = this;
				_.each(response, function(element, index, list) {listSource.push(self.newModelFromElement(element))});
				return listSource.sort(function(a, b){

				});
			} else {
				return [];
			}
  	},

  	getParent: function(){
  		return this.parent;
  	},

  	url: function(){
  		return this.getParent().getChildrenUrl();
  	}

	});

  var YearCollection = TreeLeaves.extend({
  	model: Year,

  	url: function(){
  		return "/users/bucks/dates/years";
  	},

  	initialize: function(){
  		this.fetchFirst();
  	},

		fetchFirst: function(){
			this.fetch({success: function(collection, response, options){
				collection.at(0).getChildren();
			}});
		},

  	newModelFromElement: function(element) {
  		return new Year({id: element, parent: this.parent}) 
  	}

  });
  var MonthCollection = TreeLeaves.extend({
  	model: Month,

  	newModelFromElement: function(element) {
  		return new Month({id: element, parent: this.parent});
  	}

  });



  var DayCollection = TreeLeaves.extend({
  	model: Day, 

  	newModelFromElement: function(element) {
  		return new Day({id: element, parent: this.parent});
  	}
  });

  var PositionCollection = TreeLeaves.extend({
  	model: Position,
		comparator: function(item) {
		  return item.timestamp;
		},
  	newModelFromElement: function(element) {
  		return new Position({parent: self.parent, latitude: element.lat, longitude: element.long, timestamp: element.ts});
  	}
  });




  var GenericListItem = Backbone.View.extend({
  	tagName: "li",

  	events: {
	    "click": "listItemClicked",
		},

  	render: function(){
  		var $el = $(this.el);
  		$el.html(this.model.id);
  		return this; 
  	},

  	listItemClicked: function(item){
  		this.options.parent.showNextDetailView(this.model);
  	}
  });

  var YearListItem = GenericListItem.extend({
    render: function(){
  	  this.$el.html(this.model.id);
  		return this; 
    }, 

    getDetailView: function(item, children) {
    	return new MonthView({model: children});
    }
  });

  var MonthListItem = GenericListItem.extend({

  	render: function(){
  	  this.$el.html(this.model.id);
  		return this; 
    }, 

    getDetailView: function(item, children) {
    	return new DayView({model: children});
    }
  });
  var DayListItem = GenericListItem.extend({

  	render: function(){
  	  this.$el.html(this.model.id);
  		return this; 
    }, 

    getDetailView: function(item, children) {
    	return new LocationView({model: children});
    },
  });
  var LocationListItem = GenericListItem.extend({

  	render: function(){
  	  this.$el.html(this.model.get("timestamp"));
  		return this; 
    }, 

    listItemClicked: function(item) {
    	console.log("Selected location %s:%s @ %s", this.model.get("latitude"), this.model.get("longitude"), this.model.get("timestamp"))
    }

  });




	var GenericMasterDetailView = Backbone.View.extend({
    tagName: 'ul',

    initialize: function() {
      this.listItems = [];
      this.nextDetailView = undefined;
      					this.model.on('add', this.addItemView, this);

      this.delegateEvents(this.events);
    },

    autoexpand: function(){
    	console.log("autoexpand")

    	if(this.model.size > 0){
				self.showNextDetailView(this.model.get(0), function(detailView) {detailView.autoexpand()});

    	} else {
    		self = this; 
				this.model.on('add', function(item){
					self.model.off();
					self.showNextDetailView(item, function(detailView) {detailView.autoexpand()});
					self.model.on('add', this.addItemView, this);
				}, this);
    	}
    },

		close: function(){
			console.log("GenericMasterDetailView -close")
			if(this.nextDetailView != undefined) {// recurse down to clean up deeper hierarchies 
				this.nextDetailView.close(); 
			}

			$(this.outer).addClass('hidden');

		  if (this.onClose) //For custom handlers to clean up events bound to anything else than this.model and this.collection
		    this.onClose();
		  if (this.model)
		    this.model.off(null, null, this);
		  if (this.collection)
		    this.collection.off(null, null, this);

		  this.off();
		  $(this.el).remove();
		  console.log("removed from dom")
		  this.unbind();
		},

		showNextDetailView: function(model, callback){
  		console.log("GenericMasterDetailView -showNextDetailView.");

  		if(this.nextDetailView != undefined) {			
				this.nextDetailView.close();
			}
			
			var self = this; 

    	model.getChildren(function(children){
    		var detailView = self.getDetailView(children);
    		detailView.render();

    		self.nextDetailView = detailView;
    		$(self.nextDetailView.outer).removeClass('hidden');
    		if(callback) {
					console.log("showNextDetailView -callback")
	    		callback(self.nextDetailView);
				}
    	})
		},

    render: function(){
    	this.$el = $(this.el);

      for (var i = 0, l = this.model.length; i < l; i++)
          this.addItemView(this.model.models[i]);

      $(this.outer).html(this.$el);
    }, 

    addItemView: function(item){
    	var itemView = this.getNewItemView(item);
    	this.listItems.push(itemView);
      this.$el.append(itemView.render().el);
    },

    getNewItemView: function(item){
    	return new GenericListItem({model: item, parent: this});
    }
	});

	var YearView = GenericMasterDetailView.extend({
		initialize: function(options){
			this.outer = "#md1";
      this.constructor.__super__.initialize.apply(this, [options])
   },

    getDetailView: function(children) {
    	return new MonthView({model: children});
    },

		getNewItemView: function(item){
    	return new YearListItem({model: item, parent: this});
    },
	});


	var MonthView = GenericMasterDetailView.extend({
		initialize: function(options){
			this.outer = "#md2";
      this.constructor.__super__.initialize.apply(this, [options])
   },

     getDetailView: function(children) {
    	return new DayView({model: children});
    },

		getNewItemView: function(item){
    	return new MonthListItem({model: item, parent: this});
    },
	});

	var DayView = GenericMasterDetailView.extend({
		initialize: function(options){
			this.outer = "#md3";
      this.constructor.__super__.initialize.apply(this, [options])
   },

     getDetailView: function(children) {
    	return new LocationView({model: children});
    },


		getNewItemView: function(item){
    	return new DayListItem({model: item, parent: this});
    },
	});
	var LocationView = GenericMasterDetailView.extend({
		initialize: function(options){
			this.outer = "#md4";
      this.constructor.__super__.initialize.apply(this, [options])
   },

		getNewItemView: function(item){
    	return new LocationListItem({model: item});
    },
	});
  /* BASE APPLICATION LOGIC */
  var Application = Backbone.View.extend({
    el: $("body"),
    sidebar: $("#left"),
    map: $("#map"),
    



    initialize: function() {
    	this.render(); 
    },

    render: function(){
    	this.$el.append("foo");
    	var yearView = new YearView({model: Years});
    	yearView.autoexpand();
    	yearView.render();
    }


  });

  var Years = new YearCollection;
    var App = new Application;

});
