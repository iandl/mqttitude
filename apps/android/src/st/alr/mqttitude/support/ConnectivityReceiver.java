package st.alr.mqttitude.support;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;
import android.net.NetworkInfo.State;

public class ConnectivityReceiver extends BroadcastReceiver {
    
    public static interface OnNetworkAvailableListener {
        public void onNetworkAvailable();
        public void onNetworkUnavailable();
    }
    
    private final ConnectivityManager connectivityManager;
    private OnNetworkAvailableListener onNetworkAvailableListener;
    private boolean connection = false;
    
    public ConnectivityReceiver(Context context) {
        connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        checkConnectionOnDemand();
    }
    
    public void bind(Context context) {
        IntentFilter filter = new IntentFilter();
        filter.addAction(ConnectivityManager.CONNECTIVITY_ACTION);
        context.registerReceiver(this, filter);
        checkConnectionOnDemand();
    }
    
    public void unbind(Context context) {
        context.unregisterReceiver(this);
    }

    private void checkConnectionOnDemand() {
        final NetworkInfo info = connectivityManager.getActiveNetworkInfo();
        if (info == null || info.getState() != State.CONNECTED) {
            if (connection == true) {
                connection = false;
                if (onNetworkAvailableListener != null) onNetworkAvailableListener.onNetworkUnavailable();
            }
        }
        else {
            if (connection == false) {
                connection = true;
                if (onNetworkAvailableListener != null) onNetworkAvailableListener.onNetworkAvailable();
            }
        }
    }
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (connection == true && intent.getBooleanExtra(ConnectivityManager.EXTRA_NO_CONNECTIVITY, false)) {
            connection = false;
            if (onNetworkAvailableListener != null) {
                onNetworkAvailableListener.onNetworkUnavailable();
            }
        }
        else if (connection == false && !intent.getBooleanExtra(ConnectivityManager.EXTRA_NO_CONNECTIVITY, false)) {
            connection = true;
            if (onNetworkAvailableListener != null) {
                onNetworkAvailableListener.onNetworkAvailable();
            }
        }
    }
    
    public boolean hasConnection() {
        return connection;
    }
    
    public void setOnNetworkAvailableListener(OnNetworkAvailableListener listener) {
        this.onNetworkAvailableListener = listener;
    }

}
