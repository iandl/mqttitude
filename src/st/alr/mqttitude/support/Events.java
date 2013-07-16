package st.alr.mqttitude.support;

import android.location.Location;
import st.alr.mqttitude.MqttService;

public class Events {
    public static class LocationUpdated {
        Location l; 
        
        public LocationUpdated(Location l) {
            this.l = l;
        }

        public Location getLocation() {
            return l;
        }
        
        
    }
    public static class MqttConnectivityChanged {
		private MqttService.MQTT_CONNECTIVITY connectivity;

		public MqttConnectivityChanged(
				MqttService.MQTT_CONNECTIVITY connectivity) {
			this.connectivity = connectivity;
		}

		public MqttService.MQTT_CONNECTIVITY getConnectivity() {
			return connectivity;
		}
	}
}
