package st.alr.mqttitude.support;

import android.graphics.Color;

import com.google.android.gms.maps.model.BitmapDescriptor;
import com.google.android.gms.maps.model.LatLng;

public class Friend {

	private int uid;
	private String name;
	private String mqqtUsername;
	private LatLng location;
	private String geocodedLocation;
	private BitmapDescriptor markerImage;
	private BitmapDescriptor staleMarkerImage;
	private Color color;
	
	public Friend(){
			
	}
	
	public int getUid() {
		return uid;
	}
	public void setUid(int uid) {
		this.uid = uid;
	}
	public String getName() {
		return name;
	}
	public void setName(String name) {
		this.name = name;
	}
	public String getMqqtUsername() {
		return mqqtUsername;
	}
	public void setMqqtUsername(String mqqtUsername) {
		this.mqqtUsername = mqqtUsername;
	}
	public LatLng getLocation() {
		return location;
	}
	public void setLocation(LatLng location) {
		this.location = location;
	}
	public String getGeocodedLocation() {
		return geocodedLocation;
	}
	public void setGeocodedLocation(String geocodedLocation) {
		this.geocodedLocation = geocodedLocation;
	}
	public BitmapDescriptor getMarkerImage() {
		return markerImage;
	}
	public void setMarkerImage(BitmapDescriptor markerImage) {
		this.markerImage = markerImage;
	}
	public BitmapDescriptor getStaleMarkerImage() {
		return staleMarkerImage;
	}
	public void setStaleMarkerImage(BitmapDescriptor staleMarkerImage) {
		this.staleMarkerImage = staleMarkerImage;
	}
	public Color getColor() {
		return color;
	}
	public void setColor(Color color) {
		this.color = color;
	}
	
	
	
}
