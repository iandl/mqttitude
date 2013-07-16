    
package st.alr.mqttitude;
import java.util.HashMap;
import java.util.Set;

import st.alr.mqttitude.MqttService.MQTT_CONNECTIVITY;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.Locator;
import st.alr.mqttitude.support.LocatorCallback;
import st.alr.mqttitude.support.Events.MqttConnectivityChanged;
import android.app.Application;
import android.location.Location;
import android.util.Log;
import de.greenrobot.event.EventBus;
import org.eclipse.paho.client.mqttv3.MqttMessage;


public class App extends Application {
    private static App instance;
    private Locator locator;
    
    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        locator = new Locator(this);
    }

    public static App getInstance() {
        return instance;
    }
    

    
    public Locator getLocator() {
        return locator;
    }

    public void publishLocation() {
        locator.get(new LocatorCallback() {
            
            @Override
            public void onLocationRespone(Location location) {
                Log.v(this.toString(), "onLocationRespone: " + location.getLatitude() + ":" + location.getLongitude());
                
            }
        });
    
    }
    
    
}

