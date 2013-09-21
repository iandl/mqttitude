
package st.alr.mqttitude;

import java.io.IOException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

import st.alr.mqttitude.preferences.ActivityPreferences;
import st.alr.mqttitude.services.ServiceBindable;
import st.alr.mqttitude.services.ServiceLocator;
import st.alr.mqttitude.support.Defaults;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.Friend;
import st.alr.mqttitude.support.GeocodableLocation;
import st.alr.mqttitude.support.ReverseGeocodingTask;
//import android.app.DialogFragment;
//import android.app.Fragment;
//import android.app.FragmentManager;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.content.SharedPreferences;
import android.content.SharedPreferences.Editor;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorFilter;
import android.graphics.Paint;
import android.location.Address;
import android.location.Geocoder;
import android.location.Location;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Handler;
import android.os.IBinder;
import android.os.Message;
import android.preference.PreferenceManager;
import android.provider.ContactsContract;
import android.support.v4.app.DialogFragment;
import android.support.v4.widget.DrawerLayout;
import android.text.format.DateFormat;
import android.util.Config;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.SimpleAdapter;
import android.widget.TextView;

import com.google.android.gms.maps.CameraUpdate;
import com.google.android.gms.maps.CameraUpdateFactory;
import com.google.android.gms.maps.GoogleMap;
import com.google.android.gms.maps.model.BitmapDescriptor;
import com.google.android.gms.maps.model.BitmapDescriptorFactory;
import com.google.android.gms.maps.model.Circle;
import com.google.android.gms.maps.model.CircleOptions;
import com.google.android.gms.maps.model.LatLng;
import com.google.android.gms.maps.model.Marker;
import com.google.android.gms.maps.model.MarkerOptions;

import de.greenrobot.event.EventBus;

public class ActivityMain extends android.support.v4.app.FragmentActivity  {
    MenuItem publish;
    TextView location;
    TextView statusLocator;
    TextView statusLastupdate;
    TextView statusServer;
    private GoogleMap mMap;

    private TextView locationPrimary;
    private TextView locationMeta;
    private LinearLayout locationAvailable;
    private LinearLayout locationUnavailable;

    private Marker mMarker;
    private Circle mCircle;
    private ServiceLocator serviceLocator;
    private ServiceConnection locatorConnection;
    private static Handler handler;
    
    private SimpleAdapter mPeers;
    private ArrayList<HashMap<String, String>> mylist;
    private Map<String,Integer> userMappings = new HashMap<String,Integer>();
    //private Map<String,BitmapDescriptor> userMarkerIcons = new HashMap<String,BitmapDescriptor>();
    //private Map<String,BitmapDescriptor> userHistoryMarkerIcons = new HashMap<String,BitmapDescriptor>();
    private DrawerLayout mDrawerLayout;
    private ListView mDrawerList;
    
    private Map<String,LinkedList<Marker>> userMarkerHistory = new HashMap<String,LinkedList<Marker>>();
    private SharedPreferences sharedPreferences;
    
    private Map<String,Friend> friends = new HashMap<String,Friend>();

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        int itemId = item.getItemId();
        
        if (itemId == R.id.menu_settings) {
            Intent intent1 = new Intent(this, ActivityPreferences.class);
            startActivity(intent1);
            return true;
        }  else if (itemId == R.id.menu_status) {
                Intent intent1 = new Intent(this, ActivityStatus.class);
                startActivity(intent1);
                return true;
        } else if (itemId == R.id.menu_publish) {           
            if(serviceLocator != null)
                serviceLocator.publishLastKnownLocation();
            return true;
        } else if (itemId == R.id.menu_share) {
            if(serviceLocator != null)
                this.share(null);
            return true;
        } else {
            return super.onOptionsItemSelected(item);
        }
    }

    private void setUpMapIfNeeded() {
        if (mMap == null) {
            mMap = ((com.google.android.gms.maps.SupportMapFragment) getSupportFragmentManager()
                    .findFragmentById(R.id.map)).getMap();
            if (mMap != null) {
                setUpMap();
            }
        }
    }

    private void setUpMap() {
        // Hide the zoom controls as the button panel will cover it.
        mMap.getUiSettings().setZoomControlsEnabled(false);
        mMap.setMyLocationEnabled(false);
        mMap.setTrafficEnabled(false);
    }

    @Override
    protected void onStart() {
        super.onStart();
        
        Log.v(this.toString(), "binding");

        
        locatorConnection = new ServiceConnection() {
            
            @Override
            public void onServiceDisconnected(ComponentName name) {
                serviceLocator = null;                
            }
            
            @Override
            public void onServiceConnected(ComponentName name, IBinder service) {
                Log.v(this.toString(), "bound");

                serviceLocator = (ServiceLocator) ((ServiceBindable.ServiceBinder)service).getService();                
            }
        };
        
        bindService(new Intent(this, App.getServiceLocatorClass()), locatorConnection, Context.BIND_AUTO_CREATE);
        EventBus.getDefault().register(this);
        
        
        if(serviceLocator != null)
            serviceLocator.enableForegroundMode();

        
        
        
        
        
    }
    
    @Override
    public void onStop() {
        unbindService(locatorConnection);
        EventBus.getDefault().unregister(this);

        if(serviceLocator != null)
            serviceLocator.enableBackgroundMode();

        super.onStop();
    }
    
    @Override
    protected void onResume() {
        super.onResume();
        setUpMapIfNeeded();
    }

    @Override
    protected void onPause() {
        super.onPause();
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_main, menu);
    
        if (App.getInstance().isDebugBuild())
                menu.findItem(R.id.menu_status).setVisible(true);
        return true;
    }

    /**
     * @category START
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        setUpMapIfNeeded();

        serviceLocator = null;
        locationAvailable = (LinearLayout) findViewById(R.id.locationAvailable);
        locationUnavailable = (LinearLayout) findViewById(R.id.locationUnavailable);
        locationPrimary = (TextView) findViewById(R.id.locationPrimary);
        locationMeta = (TextView) findViewById(R.id.locationMeta);

        // Handler for updating text fields on the UI like the lat/long and address.
        handler = new Handler() {
            public void handleMessage(Message msg) {
                onHandlerMessage(msg);
            }
        };

        showLocationUnavailable();       
        
        //NAVIGATION DRAW for tracking peers
        String[] mPlanetTitles = getResources().getStringArray(R.array.planets_array);
        mDrawerLayout = (DrawerLayout) findViewById(R.id.drawer_layout);
        mDrawerList = (ListView) findViewById(R.id.left_drawer);


         mylist = new ArrayList<HashMap<String, String>>();  
        HashMap<String, String> map = new HashMap<String, String>();
        
       
        
        parseContacts();
        
        
        for(Friend f: friends.values()){
        	
        	map = new HashMap<String, String>();
            map.put("Peer", f.getName());
            map.put("Location", "");
            map.put("Time", "");
            map.put("Username", f.getMqqtUsername());
            
            mylist.add(map);
            
            userMappings.put(f.getMqqtUsername(), mylist.size()-1);
            
            
        }
        
        //mylist.add(map);
        
        mPeers = new SimpleAdapter(this, mylist, R.layout.draw_list_item,
        		new String[] {"Peer", "Location", "Time"}, new int[] 
        		   {R.id.listviewmaintext, R.id.listviewsubtext, R.id.listviewminortext});

        mDrawerList.setAdapter(mPeers);
        
        // Set the adapter for the list view
        //mDrawerList.setAdapter(new ArrayAdapter<String>(this,
        //        R.layout.draw_list_item, mPlanetTitles));
        // Set the list's click listener
        mDrawerList.setOnItemClickListener(new DrawerItemClickListener());
    }
    
    private class DrawerItemClickListener implements ListView.OnItemClickListener {
        @Override
        public void onItemClick(AdapterView parent, View view, int position, long id) {
        	
        	
            selectItem(position);
        }
    }

    /** Swaps fragments in the main content view */
    private void selectItem(int position) {
        // Create a new fragment and specify the planet to show based on position
        
        // Highlight the selected item, update the title, and close the drawer
        mDrawerList.setItemChecked(position, true);
        
        String peer = mylist.get(position).get("Peer");
        
        
        	setTitle(peer);
        	//need to zoom to the peer
        	
        	//get the index into the hasmap for the named peer (we don't trust the drawer index as there could be future UI elements
            //int idx = userMappings.get("/mqttitude/"+peer);
            HashMap<String,String> peerhmap = mylist.get(position);
        	
            try{
	            LatLng latlng = new LatLng(Double.parseDouble(peerhmap.get("Latitude")),Double.parseDouble(peerhmap.get("Longitude")));
	            
	        	CameraUpdate center = CameraUpdateFactory.newLatLng(latlng);
	            CameraUpdate zoom = CameraUpdateFactory.zoomTo(15);
	
	            mMap.moveCamera(center);
	            mMap.animateCamera(zoom);

            } catch (NullPointerException e){
            	//we failed to find a valid long/lat
            
            }
        
        mDrawerLayout.closeDrawer(mDrawerList);
    }
    
    @Override
    public void setTitle(CharSequence title) {
        //mTitle = title;
        getActionBar().setTitle(title);
    }
    
  private void onHandlerMessage(Message msg) {
        switch (msg.what) {
            case ReverseGeocodingTask.GEOCODER_RESULT:
                Log.v(this.toString(), "Geocoder result_ " + ((GeocodableLocation) msg.obj).getGeocoder());
                locationPrimary.setText(((GeocodableLocation) msg.obj).getGeocoder());
                break;
            case ReverseGeocodingTask.GEOCODER_NORESULT:
                break;

        }
    }   
    
    

    public void onEvent(Events.LocationUpdated e) {
        setLocation(e.getGeocodableLocation());
    }

    Marker peer = null;
    
    //handle new peer location
    public void onEventMainThread(Events.UpdatedPeerLocation e){
    	
    	LatLng latlong = new LatLng(Double.parseDouble(e.getLat()),Double.parseDouble(e.getLng()));
    	
    	setPeerLocation(latlong,e.getUsr(),e.getGca(),e.getTst());
    	
    }
    
    public void setPeerLocation(LatLng latlong, String user, String geoAddress, String time){
    	//need to put pin on the UI or update
    	
    	//TODO: should put double parsing into event code
    	
    	//BitmapFactory.decodeResource(getResources(), R.drawable.marker);
    	
    	LinkedList<Marker> thisUserMarkerHistory = null;
    	
    	//first lets see if there is a existng marker and turn in grey
    	if (userMarkerHistory.containsKey(user)){
    		//get the old marker and change it's icon
    		thisUserMarkerHistory = userMarkerHistory.get(user);
    		Marker lastMarker = thisUserMarkerHistory.removeLast();
    		lastMarker.setIcon(friends.get(user).getStaleMarkerImage()); // userHistoryMarkerIcons.get(user));
    		thisUserMarkerHistory.add(lastMarker);
    		
    	}else{
    		//the user doesn't have a history so create a blank one
    		//userMarkerHistory.put(user, new LinkedList<Marker>());
    		thisUserMarkerHistory = new LinkedList<Marker>();
    	}
    	
    	
    	MarkerOptions ms = new MarkerOptions();
    	ms.icon(friends.get(user).getMarkerImage()); //userMarkerIcons.get(user));
    	ms.title(user);
    	ms.position(latlong);
    	ms.snippet("Some Text");
    	
    	peer = mMap.addMarker(ms);
    	
    	thisUserMarkerHistory.add(peer); 
    	//update the table
    	userMarkerHistory.put(user,thisUserMarkerHistory);
    
    	//need to update the hashmap
    	int idx = userMappings.get(user);
    	
    	
    	
    	HashMap<String,String> elem = mylist.get(idx);
    	
    	long millis = Long.parseLong(time);
    	millis = millis * 1000;
    	
    	SimpleDateFormat formatter = new SimpleDateFormat("dd/MM/yyyy HH:mm");

        // Create a calendar object that will convert the date and time value in milliseconds to date. 
         Calendar calendar = Calendar.getInstance();
         calendar.setTimeInMillis(millis);
         String dateFormatted = formatter.format(calendar.getTime());


    	
    	
    	
    	elem.put("Location", geoAddress);//"Lat/Lng: " + latlong.latitude + " " + latlong.longitude);
    	elem.put("Time", dateFormatted);
    	elem.put("Latitude",""+latlong.latitude);
    	elem.put("Longitude",""+ latlong.longitude);
    	
    	
    	mylist.set(idx, elem);
    	
    	mPeers = new SimpleAdapter(this, mylist, R.layout.draw_list_item,
        		new String[] {"Peer", "Location", "Time"}, new int[] 
        		   {R.id.listviewmaintext, R.id.listviewsubtext, R.id.listviewminortext});

        mDrawerList.setAdapter(mPeers);
    	
    }
    
    public void setLocation(GeocodableLocation location) {
       Location l = location.getLocation();
       if(l == null) {
           showLocationUnavailable();
           return;
       } 
       
        LatLng latlong = new LatLng(l.getLatitude(), l.getLongitude());
        CameraUpdate center = CameraUpdateFactory.newLatLng(latlong);
        CameraUpdate zoom = CameraUpdateFactory.zoomTo(15);

        if (mMarker != null)
            mMarker.remove();

        if (mCircle != null)
            mCircle.remove();

        
        mMarker = mMap.addMarker(new MarkerOptions().position(latlong).icon(BitmapDescriptorFactory.fromResource(R.drawable.marker)));

         if(l.getAccuracy() >= 50) {
                 mCircle = mMap.addCircle(new
                 CircleOptions().center(latlong).radius(l.getAccuracy()).strokeColor(0xff1082ac).fillColor(0x1c15bffe).strokeWidth(3));
         }

        mMap.moveCamera(center);
        mMap.animateCamera(zoom);

        locationPrimary.setText(l.getLatitude() + " / " + l.getLongitude());
        locationMeta.setText(App.getInstance().formatDate(new Date()));
        showLocationAvailable();
        
        if (Geocoder.isPresent())
            (new ReverseGeocodingTask(this, handler)).execute(new GeocodableLocation[] {location});
        
    }

    private void showLocationAvailable() {
        locationUnavailable.setVisibility(View.GONE);
        if(!locationAvailable.isShown())
            locationAvailable.setVisibility(View.VISIBLE);
    }

    private void showLocationUnavailable(){
        locationAvailable.setVisibility(View.GONE);
        if(!locationUnavailable.isShown())          
            locationUnavailable.setVisibility(View.VISIBLE);        
    }
    
    public void share(View view) {
        GeocodableLocation l = serviceLocator.getLastKnownLocation();
        Intent sendIntent = new Intent();
        sendIntent.setAction(Intent.ACTION_SEND);
        sendIntent.putExtra(
                Intent.EXTRA_TEXT,
                "http://maps.google.com/?q=" + Double.toString(l.getLatitude()) + ","
                        + Double.toString(l.getLongitude()));
        sendIntent.setType("text/plain");
        startActivity(Intent.createChooser(sendIntent,
                getResources().getText(R.string.shareLocation)));

    }

    public void upload(View view) {
            serviceLocator.publishLastKnownLocation();
    }
    
    /*
     * Here we parse the contacts and build a list of known MQTTITUDE users
     * we then use this elsewhere to a) produce UI and b) to pass to the service to 
     * create subscriptions
     */
    
    public void parseContacts(){
    	//new friends user ids by using android contacts, 
        //TODO: put in fn
        ContentResolver cr = getContentResolver();

        Cursor cur = cr.query(ContactsContract.Contacts.CONTENT_URI,
                null, null, null, null);
        if (cur.getCount() > 0) {
        	while (cur.moveToNext()) {
        		String id = cur.getString(cur.getColumnIndex(ContactsContract.Contacts._ID));
        		String name = cur.getString(cur.getColumnIndex(ContactsContract.Contacts.DISPLAY_NAME));
	        
        		if (Integer.parseInt(cur.getString(cur.getColumnIndex(ContactsContract.Contacts.HAS_PHONE_NUMBER))) > 0) {
        			//Query IM details
        			String imWhere = ContactsContract.Data.CONTACT_ID + " = ? AND " + ContactsContract.Data.MIMETYPE + " = ?"; 
        		 	String[] imWhereParams = new String[]{id, 
        		 	    ContactsContract.CommonDataKinds.Im.CONTENT_ITEM_TYPE}; 
        		 	Cursor imCur = cr.query(ContactsContract.Data.CONTENT_URI, 
        		            null, imWhere, imWhereParams, null); 
        		 	if (imCur.moveToFirst()) { 
        		 	    String imName = imCur.getString(imCur.getColumnIndex(ContactsContract.CommonDataKinds.Im.DATA));
        		 	    String imType;
        		 	    imType = imCur.getString(imCur.getColumnIndex(ContactsContract.CommonDataKinds.Im.TYPE));
        		 	    
        		 	    String label = imCur.getString(imCur.getColumnIndex(ContactsContract.CommonDataKinds.Im.CUSTOM_PROTOCOL));
        		 	    
        		 	    if(imType.equalsIgnoreCase("3")){
	        		 	    //TODO: CHange hard coded string
	        		 	    if(label.equalsIgnoreCase("MQTTITUDE")){
	        		 	    	
	        		 	    	Events.NewPeerAdded msg = new Events.NewPeerAdded(imName);
	        		            EventBus.getDefault().post(msg);
	        		            
	        		            //create a friend object
	        		            Friend friend = new Friend();
	        		            
	        		            friend.setMqqtUsername(imName);
	        		            friend.setName(name);
	        		            
	        		            friend.setMarkerImage(createCustomMarker(friends.size()-1,1.0f));
	        		        	friend.setStaleMarkerImage(createCustomMarker(friends.size()-1,0.5f));
	        		        	
	        		        	friends.put(imName, friend);
	        		        	
	        		            
	        		            
	        		 	    }
        		 	    }
        		 	} 
        		 	imCur.close();

 	        	}
            }
        }	
    
    }
    
    /*
     * We use this to generate markers for each of the different peers/friends
     * we can use a solid colour for each then alter the apha for historical markers
     */
    private BitmapDescriptor createCustomMarker(int colour, float alpha){
    	
    	
        
        float[] hsv = new float[3]; 
        
        hsv[0] = (colour * 50) % 360; //mod 365 so we get variation
        hsv[1] = 1;
        hsv[2] = alpha;
        
    	
    	Bitmap bm = Bitmap.createBitmap(40, 40, Bitmap.Config.ARGB_8888);
    	Canvas c = new Canvas();
    	c.setBitmap(bm);
    	    	
    	Paint p = new Paint();
    	p.setColor(Color.HSVToColor(hsv));
    	
    	
    	c.drawCircle(20, 20, 10, p);
    	
    	return BitmapDescriptorFactory.fromBitmap(bm);
    	
    }
}
