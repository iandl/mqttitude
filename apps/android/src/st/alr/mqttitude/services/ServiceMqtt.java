
package st.alr.mqttitude.services;

import java.io.BufferedInputStream;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyManagementException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Iterator;
import java.util.LinkedList;

import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManagerFactory;

import org.eclipse.paho.client.mqttv3.IMqttDeliveryToken;
import org.eclipse.paho.client.mqttv3.MqttCallback;
import org.eclipse.paho.client.mqttv3.MqttClient;
import org.eclipse.paho.client.mqttv3.MqttConnectOptions;
import org.eclipse.paho.client.mqttv3.MqttException;
import org.eclipse.paho.client.mqttv3.MqttMessage;
import org.eclipse.paho.client.mqttv3.MqttTopic;
import org.json.JSONException;
import org.json.JSONObject;

import st.alr.mqttitude.App;
import st.alr.mqttitude.R;
import st.alr.mqttitude.support.Defaults;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.MqttPublish;
import android.annotation.SuppressLint;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.ContentResolver;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.Uri;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.PowerManager;
import android.os.PowerManager.WakeLock;
import android.preference.PreferenceManager;
import android.provider.ContactsContract;
import android.provider.Settings.Secure;
import android.util.Log;
import de.greenrobot.event.EventBus;

public class ServiceMqtt extends ServiceBindable implements MqttCallback
{

    public static enum MQTT_CONNECTIVITY {
        INITIAL, CONNECTING, CONNECTED, DISCONNECTING, DISCONNECTED_WAITINGFORINTERNET, DISCONNECTED_USERDISCONNECT, DISCONNECTED_DATADISABLED, DISCONNECTED, DISCONNECTED_ERROR
    }

    private static MQTT_CONNECTIVITY mqttConnectivity = MQTT_CONNECTIVITY.DISCONNECTED;
    private short keepAliveSeconds;
    private String mqttClientId;
    private MqttClient mqttClient;
    private static SharedPreferences sharedPreferences;
    private static ServiceMqtt instance;
    private SharedPreferences.OnSharedPreferenceChangeListener preferencesChangedListener;
    private Thread workerThread;
    private LinkedList<DeferredPublishable> deferredPublishables;
    private static MqttException error;
    private HandlerThread pubThread;
    private Handler pubHandler;

    // An alarm for rising in special times to fire the
    // pendingIntentPositioning
    private AlarmManager alarmManagerPositioning;
    // A PendingIntent for calling a receiver in special times
    public PendingIntent pendingIntentPositioning;
    
    //handle any deferred subscriptions because of lack of connectivity
    private ArrayList<String> deferredSubscriptions = new ArrayList<String>();
    
    //contacts vars
    private Uri CONTENT_URI = ContactsContract.Contacts.CONTENT_URI;

    /**
     * @category SERVICE HANDLING
     */
    @Override
    public void onCreate()
    {
        super.onCreate();
        instance = this;
        workerThread = null;
        error = null;
        changeMqttConnectivity(MQTT_CONNECTIVITY.INITIAL);
        keepAliveSeconds = 15 * 60;
        sharedPreferences = PreferenceManager.getDefaultSharedPreferences(this);
        deferredPublishables = new LinkedList<DeferredPublishable>();
        EventBus.getDefault().register(this);
        
        pubThread = new HandlerThread("MQTTPUBTHREAD");
        pubThread.start();
        pubHandler = new Handler(pubThread.getLooper());

    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId)
    {
        doStart(intent, startId);
        return super.onStartCommand(intent, flags, startId);
    }

    private void doStart(final Intent intent, final int startId) {
        // init();

        Thread thread1 = new Thread() {
            @Override
            public void run() {
                handleStart(intent, startId);
                if (this == workerThread) // Clean up worker thread
                    workerThread = null;
            }

            @Override
            public void interrupt() {
                if (this == workerThread) // Clean up worker thread
                    workerThread = null;
                super.interrupt();
            }
        };
        thread1.start();
    }

    void handleStart(Intent intent, int startId) {
        Log.v(this.toString(), "handleStart");

 
        // Respect user's wish to stay disconnected. Overwrite with startId == -1 to reconnect manually afterwards
        if ((mqttConnectivity == MQTT_CONNECTIVITY.DISCONNECTED_USERDISCONNECT) && startId != -1) {
            Log.d(this.toString(), "handleStart: respecting user disconnect ");

            return;
        }

        // No need to connect if we're already connecting
        if (isConnecting()) {
            Log.d(this.toString(), "handleStart: already connecting");
            return;
        }

        // Respect user's wish to not use data
        if (!isBackgroundDataEnabled()) {
            Log.e(this.toString(), "handleStart: !isBackgroundDataEnabled");
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED_DATADISABLED);
            return;
        }

        // Don't do anything unless we're disconnected
        if (isDisconnected())
        {
            Log.v(this.toString(), "handleStart: !isConnected");
            // Check if there is a data connection
            if (isOnline(true))
            {
                if (connect())
                {
                    Log.v(this.toString(), "handleStart: connec sucessfull");
                    onConnect();
                }
            }
            else
            {
                Log.e(this.toString(), "handleStart: !isOnline");
                changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED_WAITINGFORINTERNET);
            }
        } else {
            Log.d(this.toString(), "handleStart: already connected");

        }
    }
    
    private boolean isDisconnected(){
        return mqttConnectivity == MQTT_CONNECTIVITY.INITIAL || mqttConnectivity == MQTT_CONNECTIVITY.DISCONNECTED || mqttConnectivity == MQTT_CONNECTIVITY.DISCONNECTED_USERDISCONNECT || mqttConnectivity == MQTT_CONNECTIVITY.DISCONNECTED_WAITINGFORINTERNET || mqttConnectivity == MQTT_CONNECTIVITY.DISCONNECTED_ERROR;
    }

    /**
     * @category CONNECTION HANDLING
     */
    private void init()
    {
        Log.v(this.toString(), "initMqttClient");

        if (mqttClient != null) {
            return;
        }

        try
        {
            String brokerAddress = sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_HOST,
                    Defaults.VALUE_BROKER_HOST);
            String brokerPort = sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_PORT,
                    Defaults.VALUE_BROKER_PORT);
            String prefix = getBrokerSecurityMode() == Defaults.VALUE_BROKER_SECURITY_NONE ? "tcp"
                    : "ssl";

            mqttClient = new MqttClient(prefix + "://" + brokerAddress + ":" + brokerPort,
                    getClientId(), null);
            mqttClient.setCallback(this);

        } catch (MqttException e)
        {
            // something went wrong!
            mqttClient = null;
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED);
        }
    }

    private int getBrokerSecurityMode() {
        return sharedPreferences.getInt(Defaults.SETTINGS_KEY_BROKER_SECURITY,
                Defaults.VALUE_BROKER_SECURITY_NONE);
    }

    //
    private javax.net.ssl.SSLSocketFactory getSSLSocketFactory() throws CertificateException,
            KeyStoreException, NoSuchAlgorithmException, IOException, KeyManagementException {
        CertificateFactory cf = CertificateFactory.getInstance("X.509");
        // From https://www.washington.edu/itconnect/security/ca/load-der.crt
        InputStream caInput = new BufferedInputStream(new FileInputStream(
                sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_SECURITY_SSL_CA_PATH, "")));
        java.security.cert.Certificate ca;
        try {
            ca = cf.generateCertificate(caInput);
        } finally {
            caInput.close();
        }

        // Create a KeyStore containing our trusted CAs
        String keyStoreType = KeyStore.getDefaultType();
        KeyStore keyStore = KeyStore.getInstance(keyStoreType);
        keyStore.load(null, null);
        keyStore.setCertificateEntry("ca", ca);

        // Create a TrustManager that trusts the CAs in our KeyStore
        String tmfAlgorithm = TrustManagerFactory.getDefaultAlgorithm();
        TrustManagerFactory tmf = TrustManagerFactory.getInstance(tmfAlgorithm);
        tmf.init(keyStore);

        // Create an SSLContext that uses our TrustManager
        SSLContext context = SSLContext.getInstance("TLS");
        context.init(null, tmf.getTrustManagers(), null);

        return context.getSocketFactory();
    }

    private boolean connect()
    {
        workerThread = Thread.currentThread(); // We connect, so we're the
                                               // worker thread
        Log.v(this.toString(), "connect");

        init();

        try
        {
            changeMqttConnectivity(MQTT_CONNECTIVITY.CONNECTING);
            MqttConnectOptions options = new MqttConnectOptions();

            if (getBrokerSecurityMode() == Defaults.VALUE_BROKER_SECURITY_SSL_CUSTOMCACRT)
                options.setSocketFactory(this.getSSLSocketFactory());

            if (!sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_PASSWORD, "").equals(""))
                options.setPassword(sharedPreferences.getString(
                        Defaults.SETTINGS_KEY_BROKER_PASSWORD, "").toCharArray());

            if (!sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_USERNAME, "").equals(""))
                options.setUserName(sharedPreferences.getString(
                        Defaults.SETTINGS_KEY_BROKER_USERNAME, ""));

            //setWill(options);
            options.setKeepAliveInterval(keepAliveSeconds);
            options.setConnectionTimeout(30);
            

            mqttClient.connect(options);

            Log.d(this.toString(), "No error during connect");
            changeMqttConnectivity(MQTT_CONNECTIVITY.CONNECTED);
            
    
            //TODO: Set subscribe topic properly from UI shared prefs
            //sharedPreferences.getString(Defaults.SETTINGS_KEY_TOPIC, Defaults.VALUE_TOPIC)
            
            //we subscribe to our own channel based on username.. it will be unqiue to that user
            String topic = sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_USERNAME, "anonymous");
	        mqttClient.subscribe("/mqttitude/" + topic, 1);
			
	        //Add the stored subscriptions from the user preferences, we currently also parse this strng in the UI
	        //and I need to change it so we have an event that the UI parses to say we have a new subscription
	        /*String tmp = sharedPreferences.getString(Defaults.SETTING_PEER_USERNAMES, "");
	        
	        if(tmp.contains(",")){
	        
	        	String[] usernames = tmp.split(",");
		        for(String u: usernames){
		        	
		        	String peername = u.substring(u.lastIndexOf("/")+1);
		        	
		        	//this is hacky and just a postback to self via the event bus
		        	//Events.NewPeerAdded msg = new Events.NewPeerAdded(peername);
		            //EventBus.getDefault().post(msg);
		        }
	        }     	*/
	        
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
		        		 	    }
	        		 	    }
	        		 	} 
	        		 	imCur.close();

	 	        	}
	            }
	        }

            return true;

        } catch (MqttException e) { // Catch paho and socket factory exceptions
            Log.e(this.toString(), e.toString());
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED_ERROR, e);
            return false;
        } catch (Exception e) {
            e.printStackTrace();
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED);
            return false;
        }

    }

    private void setWill(MqttConnectOptions m) {
        StringBuffer payload = new StringBuffer();
        
      //added unique ID for this app
        String uid = sharedPreferences.getString(Defaults.SETTINGS_KEY_BROKER_USERNAME, "unknown");
        
        
        payload.append("{");
        payload.append("\"type\": ").append("\"").append("_lwt").append("\"");
        payload.append(", \"tst\": ").append("\"").append((int) (new Date().getTime() / 1000))
                .append("\"");
        payload.append(", \"usr\": ").append("\"").append(uid).append("\"");
        payload.append("}");

        m.setWill(mqttClient.getTopic(sharedPreferences.getString(Defaults.SETTINGS_KEY_TOPIC,
                Defaults.VALUE_TOPIC)), payload.toString().getBytes(), 0, false);

    }

    private void onConnect() {

        if (!isConnected())
            Log.e(this.toString(), "onConnect: !isConnected");
    }

    public void disconnect(boolean fromUser)
    {
        Log.v(this.toString(), "disconnect");
        if (fromUser)
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED_USERDISCONNECT);

        try
        {
            if (isConnected())
                mqttClient.disconnect();
        } catch (Exception e) {
            e.printStackTrace();
        } finally {
            mqttClient = null;

            if (workerThread != null) {
                workerThread.interrupt();
            }

        }
    }

    @SuppressLint("Wakelock")
    // Lint check derps with the wl.release() call.
    @Override
    public void connectionLost(Throwable t)
    {
        Log.e(this.toString(), "error: " + t.toString());
        // we protect against the phone switching off while we're doing this
        // by requesting a wake lock - we request the minimum possible wake
        // lock - just enough to keep the CPU running until we've finished
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        WakeLock wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "MQTT");
        wl.acquire();

        if (!isOnline(true))
        {
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED_WAITINGFORINTERNET);
        }
        else
        {
            changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED);
        }
        wl.release();
    }

    public void reconnect() {
        disconnect(true);
        doStart(null, -1);
    }

    public void messageArrived(MqttTopic topic, MqttMessage message) throws MqttException {
    	
    	String msg = new String(message.getPayload());
    	
    	try {
			JSONObject jObject = new JSONObject(msg);
			String lat  = jObject.getString("lat");
			String lng  = jObject.getString("lon");
			String acc  = jObject.getString("acc");
			String tst  = jObject.getString("tst");
			String alt  = jObject.getString("alt");
			String gca = "Not sent";
			try{
				gca  = jObject.getString("gca");
			} catch (JSONException e){
				//catch other clients who don't publish Geocoded Addresses
			
			}
			//strip the /mqqtitude/ from the topic to get the username
			Events.UpdatedPeerLocation updatedPeerLoc = new Events.UpdatedPeerLocation(lng,lat,tst,alt,topic.getName().substring(topic.getName().lastIndexOf("/")+1),acc,gca);
	    	
	    	EventBus.getDefault().post(updatedPeerLoc);
			
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	
    }

    public void onEvent(Events.MqttConnectivityChanged event) {
        mqttConnectivity = event.getConnectivity();

        if (event.getConnectivity() == MQTT_CONNECTIVITY.CONNECTED){
            publishDeferrables();
            subscribeDeferrables();
            
            
        }

    }
    
    /**
     * Incoming event when a new peer/friend is added
     * here we subsribe to their topic     * 
     */

    public void onEvent(Events.NewPeerAdded newPeer){
    	
    	if(mqttConnectivity == MQTT_CONNECTIVITY.CONNECTED ){
    	
	    	try {
				mqttClient.subscribe("/mqttitude/" + newPeer.getPeerUserName(), 1);
			} catch (MqttException e) {
				// TODO Auto-generated catch block
				// TODO: Throw some UI if we fail to subscribe... could be ACL issues here?
				// TODO: could also be a disconnected broker
				e.printStackTrace();
				
				//defer the subscription
				deferredSubscriptions.add("/mqttitude/" + newPeer.getPeerUserName());
			}
    
    	} else{
    		
    		//defer the subscription
    		
    		deferredSubscriptions.add("/mqttitude/" + newPeer.getPeerUserName());
    	}
    }
    
    /**
     * @category CONNECTIVITY STATUS
     */
    private void changeMqttConnectivity(MQTT_CONNECTIVITY newConnectivity, MqttException e) {
        error = e; 
        changeMqttConnectivity(newConnectivity);
    }
    
    private void changeMqttConnectivity(MQTT_CONNECTIVITY newConnectivity) {
        Log.d(this.toString(), "Connectivity changed to: " + newConnectivity);
        EventBus.getDefault().post(new Events.MqttConnectivityChanged(newConnectivity));
        mqttConnectivity = newConnectivity;
        if(newConnectivity == MQTT_CONNECTIVITY.DISCONNECTED) {
            Log.e(this.toString(), " disconnect");
            
        }
    }

    private boolean isOnline(boolean shouldCheckIfOnWifi)
    {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(CONNECTIVITY_SERVICE);
        NetworkInfo netInfo = cm.getActiveNetworkInfo();

        return netInfo != null
                // && (!shouldCheckIfOnWifi || (netInfo.getType() ==
                // ConnectivityManager.TYPE_WIFI))
                && netInfo.isAvailable()
                && netInfo.isConnected();
    }

    public boolean isConnected()
    {
        return ((mqttClient != null) && (mqttClient.isConnected() == true));
    }
    
    public static boolean isErrorState(MQTT_CONNECTIVITY c) {
        return c == MQTT_CONNECTIVITY.DISCONNECTED_ERROR;
    }
    
    public static boolean hasError(){
        return error != null;
    }

    public boolean isConnecting() {
        return (mqttClient != null) && mqttConnectivity == MQTT_CONNECTIVITY.CONNECTING;
    }

    private boolean isBackgroundDataEnabled() {
        return isOnline(false);
    }

    public static MQTT_CONNECTIVITY getConnectivity() {
        return mqttConnectivity;
    }

    /**
     * @category MISC
     */
    public static ServiceMqtt getInstance() {
        return instance;
    }

    private String getClientId()
    {
        if (mqttClientId == null)
        {
            mqttClientId = Secure.getString(getContentResolver(), Secure.ANDROID_ID);

            // MQTT specification doesn't allow client IDs longer than 23 chars
            if (mqttClientId.length() > 22)
                mqttClientId = mqttClientId.substring(0, 22);
        }

        return mqttClientId;
    }


    @Override
    public void onDestroy()
    {
        // disconnect immediately
        disconnect(false);

        changeMqttConnectivity(MQTT_CONNECTIVITY.DISCONNECTED);

        sharedPreferences.unregisterOnSharedPreferenceChangeListener(preferencesChangedListener);

        if (this.alarmManagerPositioning != null)
            this.alarmManagerPositioning.cancel(pendingIntentPositioning);

        super.onDestroy();
    }



    public static String getConnectivityText() {
        MQTT_CONNECTIVITY c = getConnectivity();
        if(isErrorState(c) && hasError())
            return error.toString();
        
        switch (c) {
            case CONNECTED:
                return App.getInstance().getString(R.string.connectivityConnected);
            case CONNECTING:
                return App.getInstance().getString(R.string.connectivityConnecting);
            case DISCONNECTING:
                return App.getInstance().getString(R.string.connectivityDisconnecting);
            default:
                return App.getInstance().getString(R.string.connectivityDisconnected);
        }

    }
    
    private void deferPublish(final DeferredPublishable p) {
        p.wait(deferredPublishables, new Runnable() {

            @Override
            public void run() {
                deferredPublishables.remove(p);
                if(!p.isPublishing())//might happen that the publish is in progress while the timeout occurs.
                    p.publishFailed();
            }
        });
    }

    public void publish(String topic, String payload) {
        publish(topic, payload, false, 0, 0, null, null);
    }

    public void publish(String topic, String payload, boolean retained) {
        publish(topic, payload, retained, 0, 0, null, null);
    }

    public void publish(final String topic, final String payload, final boolean retained, final int qos, final int timeout,
            final MqttPublish callback, final Object extra) {
        
        
                      publish(new DeferredPublishable(topic, payload, retained, qos, timeout, callback, extra));
                
    }

    private void publish(final DeferredPublishable p) {
  
        
        pubHandler.post(new Runnable() {
            
            @Override
            public void run() {

        if(Looper.getMainLooper().getThread() == Thread.currentThread()){
            Log.e(this.toString(), "PUB ON MAIN THREAD");
        } else {
            Log.d(this.toString(), "pub on background thread");
        }
        
        
        if (!isOnline(false) || !isConnected()) {
            Log.d(this.toString(), "pub deferred");
            deferPublish(p);
            return;
        }

        try
        {
            p.publishing();
            mqttClient.getTopic(p.getTopic()).publish(p);
            p.publishSuccessfull();
        } catch (MqttException e)
        {
            Log.e(this.toString(), e.getMessage());
            e.printStackTrace();
            p.cancelWait();
            p.publishFailed();
        }
            }
        });

    }

    private void publishDeferrables() {        
        for (Iterator<DeferredPublishable> iter = deferredPublishables.iterator(); iter.hasNext(); ) {
            DeferredPublishable p = iter.next();
            iter.remove();
            publish(p);
        }
    }
    
    private void subscribeDeferrables(){
    
    	 for (Iterator<String> iter = deferredSubscriptions.iterator(); iter.hasNext(); ) {
             String s = iter.next();
             iter.remove();
             try {
				mqttClient.subscribe(s,1);
			} catch (MqttException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
				deferredSubscriptions.add(s);
			}
         }
    	
    	
				//deferredSubscriptions.add(s);
			
    	
    
    }

    private class DeferredPublishable extends MqttMessage {
        private Handler timeoutHandler;
        private MqttPublish callback;
        private String topic;
        private int timeout = 0;
        private boolean isPublishing;
        private Object extra;
        
        public DeferredPublishable(String topic, String payload, boolean retained, int qos,
                int timeout, MqttPublish callback, Object extra) {
            
            super(payload.getBytes());
            this.setQos(qos);
            this.setRetained(retained);
            this.extra = extra;
            this.callback = callback;
            this.topic = topic;
            this.timeout = timeout;
        }

        public void publishFailed() {
            if (callback != null)
                callback.publishFailed(extra);
        }

        public void publishSuccessfull() {
            if (callback != null)
                callback.publishSuccessfull(extra);
            cancelWait();

        }

        public void publishing() {
            isPublishing = true;
            if (callback != null)
                callback.publishing(extra);
        }
        
        public boolean isPublishing(){
            return isPublishing;
        }

        public String getTopic() {
            return topic;
        }
        
        public void cancelWait(){
            if(timeoutHandler != null)
                this.timeoutHandler.removeCallbacksAndMessages(this);
        }

        public void wait(LinkedList<DeferredPublishable> queue, Runnable onRemove) {
            if (timeoutHandler != null) {
                Log.d(this.toString(), "This DeferredPublishable already has a timeout set");
                return;
            }

            // No need signal waiting for timeouts of 0. The command will be
            // failed right away
            if (callback != null && timeout > 0)
                callback.publishWaiting(extra);

            queue.addLast(this);
            this.timeoutHandler = new Handler();
            this.timeoutHandler.postDelayed(onRemove, timeout * 1000);
        }
    }

    @Override
    public void messageArrived(String topic, MqttMessage message) throws Exception {
    	
    	
    	
        String msg = new String(message.getPayload());
    	
    	try {
			JSONObject jObject = new JSONObject(msg);
			String lat  = jObject.getString("lat");
			String lng  = jObject.getString("lon");
			String acc  = jObject.getString("acc");
			String tst  = jObject.getString("tst");
			String alt  = jObject.getString("alt");
			String gca  = jObject.getString("gca");
			
			//strip the /mqqtitude/ from the topic to get the username
			Events.UpdatedPeerLocation updatedPeerLoc = new Events.UpdatedPeerLocation(lng,lat,tst,alt,topic.substring(topic.lastIndexOf("/")+1),acc,gca);
	    	
	    	EventBus.getDefault().post(updatedPeerLoc);
			
		} catch (JSONException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
    	
    	//post event
    	
    			
    }

    @Override
    public void deliveryComplete(IMqttDeliveryToken token) {}

    @Override
    protected void onStartOnce() {}

}
