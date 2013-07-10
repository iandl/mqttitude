
package st.alr.mqttpositionlogger;

import st.alr.mqttpositionlogger.MqttService.MQTT_CONNECTIVITY;
import st.alr.mqttpositionlogger.support.Events.MqttConnectivityChanged;
import android.content.Intent;
import android.os.Bundle;
import android.support.v4.app.FragmentActivity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.RelativeLayout;
import de.greenrobot.event.EventBus;

public class MainActivity extends FragmentActivity {
    RelativeLayout disconnectedLayout;
    LinearLayout connectedLayout;

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
            connectedLayout.setVisibility(View.VISIBLE);
            disconnectedLayout.setVisibility(View.INVISIBLE);
        } else {
            connectedLayout.setVisibility(View.INVISIBLE);
            disconnectedLayout.setVisibility(View.VISIBLE);
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

        disconnectedLayout = (RelativeLayout) findViewById(R.id.disconnectedLayout);
        connectedLayout = (LinearLayout) findViewById(R.id.connectedLayout);

        updateViewVisibility();

        EventBus.getDefault().register(this);
    }
}
