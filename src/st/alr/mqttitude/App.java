    
package st.alr.mqttitude;
import java.util.Calendar;
import java.util.HashMap;
import java.util.Set;

import st.alr.mqttitude.services.ServiceMqtt;
import st.alr.mqttitude.services.ServiceMqtt.MQTT_CONNECTIVITY;
import st.alr.mqttitude.support.Defaults;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.Locator;
import st.alr.mqttitude.support.LocatorCallback;
import st.alr.mqttitude.support.Events.MqttConnectivityChanged;
import android.app.AlarmManager;
import android.app.Application;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.SharedPreferences;
import android.location.Location;
import android.preference.PreferenceManager;
import android.util.Log;
import de.greenrobot.event.EventBus;
import org.eclipse.paho.client.mqttv3.MqttMessage;


public class App extends Application {
    private static App instance;
    private Locator locator;
    private BroadcastReceiver receiver; 
    
    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        locator = new Locator(this);
        receiver = new UpdateReceiver();
        registerReceiver(receiver, new IntentFilter(st.alr.mqttitude.support.Defaults.UPDATE_INTEND_ID));
        scheduleNextUpdate();
        EventBus.getDefault().register(this);
    }

    public static App getInstance() {
        return instance;
    }
    

    
    public Locator getLocator() {
        return locator;
    }
    
    
    public void onEvent(Events.LocationUpdated e) {
        Log.v(this.toString(), "LocationUpdated: " + e.getLocation().getLatitude() + ":" + e.getLocation().getLongitude());
    }

    public void updateLocation(final boolean publish) {
        
        locator.get(new LocatorCallback() {
            
            @Override
            public void onLocationRespone(Location location) {
                EventBus.getDefault().postSticky(new Events.LocationUpdated(location));
                if(publish) {
                    Intent service = new Intent(App.getInstance(), ServiceMqtt.class);
                    startService(service);                    
                    ServiceMqtt.getInstance().publishWithTimeout(PreferenceManager.getDefaultSharedPreferences(App.getInstance()).getString("location_topic", null), location.getLatitude()+":"+location.getLongitude(), true, 20);
                }
                    
            }
        });
    }
    
    private void scheduleNextUpdate()
    {
        PendingIntent pendingIntent = PendingIntent.getBroadcast(this, 0, new Intent(st.alr.mqttitude.support.Defaults.UPDATE_INTEND_ID), PendingIntent.FLAG_UPDATE_CURRENT);

        Calendar wakeUpTime = Calendar.getInstance();
        wakeUpTime.add(Calendar.MINUTE, Integer.parseInt(PreferenceManager.getDefaultSharedPreferences(this).getString("updateIntervall", st.alr.mqttitude.support.Defaults.VALUE_UPDATE_INTERVAL)));

        AlarmManager aMgr = (AlarmManager) getSystemService(ALARM_SERVICE);
        aMgr.set(AlarmManager.RTC_WAKEUP, wakeUpTime.getTimeInMillis(), pendingIntent);
    }

    private class UpdateReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context arg0, Intent intent) {
            if(intent.getAction() != null && intent.getAction().equals(Defaults.UPDATE_INTEND_ID)){

            Log.v(this.toString(), "Updating");
            updateLocation(true);
            scheduleNextUpdate();
            }
        }
        
    }
    
    
}

