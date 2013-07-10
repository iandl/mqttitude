    
package st.alr.mqttpositionlogger;
import java.util.HashMap;
import java.util.Set;
import st.alr.mqttpositionlogger.MqttService.MQTT_CONNECTIVITY;
import st.alr.mqttpositionlogger.support.Events;
import st.alr.mqttpositionlogger.support.Events.MqttConnectivityChanged;
import android.app.Application;
import de.greenrobot.event.EventBus;
import org.eclipse.paho.client.mqttv3.MqttMessage;


public class App extends Application {
    private static App instance;
    
    public static final String defaultsServerAddress = "192.168.8.2";
    public static final String defaultsServerPort = "1883";
    public static final String defaultsRoomName = "unassigned";

    
    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        EventBus.getDefault().register(this);
    }


    public static App getInstance() {
        return instance;
    }
    
    
    
    public void onEvent(MqttConnectivityChanged event) {
        


        
        if(event.getConnectivity() == MQTT_CONNECTIVITY.DISCONNECTED_WAITINGFORINTERNET 
        || event.getConnectivity() == MQTT_CONNECTIVITY.DISCONNECTED_USERDISCONNECT
        || event.getConnectivity() == MQTT_CONNECTIVITY.DISCONNECTED_DATADISABLED
        || event.getConnectivity() == MQTT_CONNECTIVITY.DISCONNECTED) {
            //TODO
        }
    }
    
    
}

