
package st.alr.mqttitude;

import st.alr.mqttitude.MqttService.MQTT_CONNECTIVITY;
import st.alr.mqttitude.support.Events;
import st.alr.mqttitude.support.Locator;
import st.alr.mqttitude.support.LocatorCallback;
import st.alr.mqttitude.support.Events.MqttConnectivityChanged;
import st.alr.mqttitude.R;
import android.content.Intent;
import android.location.Location;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import android.widget.TextView;
import de.greenrobot.event.EventBus;

public class MainActivity extends FragmentActivity {
    Button publish;
    TextView latitude;
    TextView longitude;
    
    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case R.id.menu_settings:
                Intent intent1 = new Intent(this, PreferencesActivity.class);
                startActivity(intent1);
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    public void onEventMainThread(MqttConnectivityChanged event) {
        updateViewVisibility();
    }

    @Override
    protected void onStart() {
        super.onStart();

        Intent service = new Intent(this, MqttService.class);
        startService(service);
    }

    private void updateViewVisibility() {
        if (MqttService.getConnectivity() == MQTT_CONNECTIVITY.CONNECTED) {
            publish.setVisibility(View.VISIBLE);
        } else {
            publish.setVisibility(View.INVISIBLE);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        updateViewVisibility();
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
    }

    @Override
    public boolean onCreateOptionsMenu(Menu menu) {
        getMenuInflater().inflate(R.menu.activity_main, menu);

        return true;
    }

    
    /**
     * @category START
     */
    @Override
    protected void onCreate(Bundle savedInstanceState) {

        super.onCreate(savedInstanceState);

        setContentView(R.layout.activity_main);

        publish = (Button) findViewById(R.id.publish);
        longitude = (TextView) findViewById(R.id.longitude);
        latitude = (TextView) findViewById(R.id.latitude);

        updateViewVisibility();

        EventBus.getDefault().register(this);
    }
    
    public void onEvent(Events.LocationUpdated e) {
        Log.v(this.toString(), "LocationUpdated: " + e.getLocation().getLatitude() + ":" + e.getLocation().getLongitude());
        longitude.setText(e.getLocation().getLongitude()+"");
        latitude.setText(e.getLocation().getLongitude()+"");
    }

    
    public void update(View view) {
        App.getInstance().updateLocation();        
    }
    public void publish(View view) {
        App.getInstance().publishLocation();
    }
}
