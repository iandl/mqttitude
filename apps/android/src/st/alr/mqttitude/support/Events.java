package st.alr.mqttitude.support;


import java.util.Date;

import android.location.Location;
import st.alr.mqttitude.services.ServiceMqtt;

public class Events {
    public static class PublishSuccessfull {
        Object extra;
        Date date;
        public PublishSuccessfull(Object extra) {
            this.extra = extra;
            this.date = new Date();
        }
        public Object getExtra() {
            return extra;
        }
        public Date getDate() {
            return date;
        }

    }
    
    //Notification when new peer/friend added in UI
    public static class NewPeerAdded {
        String _peerusername;
        
        public NewPeerAdded(String peerUserName) {
            this._peerusername = peerUserName;
            
        }
        public String getPeerUserName() {
            return _peerusername;
        }
        

    }
    
    public static class UpdatedPeerLocation{
    	
    	String lng;
    	String lat;
    	String tst;
    	String alt;
    	String usr;
    	String acc;
    	String gca;
    	
    	public UpdatedPeerLocation(String _lng, String _lat, String _tst, String _alt, String _usr, String _acc, String _gca){
    		this.lng = _lng;
    		this.lat = _lat;
    		this.tst = _tst;
    		this.alt = _alt;
    		this.usr = _usr;
    		this.acc = _acc;
    		this.gca = _gca;
    	}
    	
    	public String getLng(){
    		return lng;
    	}
    	
    	public String getLat(){
    		return lat;
    	}
    	
    	public String getTst(){
    		return tst;
    	}
    	
    	public String getAlt(){
    		return alt;
    	}
    	
    	public String getUsr(){
    		return usr;
    	}
    	
    	public String getAcc(){
    		return acc;
    	}
    	
    	public String getGca(){
    		return gca;
    	}
    	
    	
    }
    
    public static class LocationUpdated {
        GeocodableLocation l; 
        
        public LocationUpdated(GeocodableLocation l) {
            this.l = l;
        }

        public GeocodableLocation getGeocodableLocation() {
            return l;
        }
        
        
    }
    public static class MqttConnectivityChanged {
		private ServiceMqtt.MQTT_CONNECTIVITY connectivity;

		public MqttConnectivityChanged(
				ServiceMqtt.MQTT_CONNECTIVITY connectivity) {
			this.connectivity = connectivity;
		}

		public ServiceMqtt.MQTT_CONNECTIVITY getConnectivity() {
			return connectivity;
		}
	}
    
    public static class StateChanged {}
}
