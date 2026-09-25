package io.github.giuig.auraninja;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;

import com.ryanheise.audioservice.AudioServiceActivity;

public class MainActivity extends AudioServiceActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Android 13+ keeps an app's notifications off until it asks, so the
        // playback notification (and its status-bar icon) never appeared;
        // only the media controls did, being exempt. Asking again after a
        // denial is harmless: Android stops showing the dialog itself once the
        // user has declined twice.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                        != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(
                    new String[] {Manifest.permission.POST_NOTIFICATIONS}, 1);
        }
    }
}
