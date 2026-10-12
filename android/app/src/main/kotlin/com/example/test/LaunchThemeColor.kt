package com.example.test

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log

/**
 * The brand colour the native launch screen paints with, read from the very
 * store the Appearance screen writes to.
 *
 * There is no second store and no platform channel: `Apply Theme` already
 * persists the colour through `AppearanceLocalDataSource`, and this reads that
 * same record. The whole feature hinges on pinning down exactly where
 * `SharedPreferences.getInstance()` puts things on Android, which is worth
 * stating because both of the obvious guesses are wrong.
 *
 * Verified against `shared_preferences` 2.5.6 and `shared_preferences_android`
 * 2.4.28:
 *
 * 1. `AppearanceLocalDataSource.savePreference` calls `setInt`, which stores
 *    the ARGB integer under `appearance.seed_color`.
 * 2. `SharedPreferences._setValue` prefixes every key with `flutter.`, giving
 *    `flutter.appearance.seed_color`.
 * 3. That goes through the *legacy* pigeon API, handled by
 *    `LegacySharedPreferencesPlugin`, whose `setInt` is `putLong` — so the
 *    stored type is `Long`, and reading it with `getInt` would throw.
 * 4. That plugin holds
 *    `context.getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)`.
 *
 * Step 4 is the one that matters. It is a dedicated file, *not* the app's
 * default preferences (`<packageName>_preferences`), which is what
 * `PreferenceManager.getDefaultSharedPreferences` and `SharedPreferencesBackend`
 * use for the newer DataStore-backed async API. Reading the default file finds
 * nothing, silently returns the fallback colour, and the splash appears stuck
 * on the brand blue no matter what was applied.
 *
 * The record is plain XML by the time this runs, so it is readable with no
 * Flutter engine, no plugin registration and no method channel — which is what
 * allows a read in `attachBaseContext`, long before Dart exists.
 *
 * Only an *applied* colour is ever stored: previewing a swatch writes nothing,
 * and `resetPreference` removes the keys. An unapplied choice therefore cannot
 * reach the launch screen, and a reset correctly falls back to [DEFAULT].
 */
internal object LaunchThemeColor {

    /** Mirrors `AppColorSeeds.defaultSeed` and `colors.xml#launch_background`. */
    const val DEFAULT: Int = 0xFF2563EB.toInt()

    private const val TAG = "LaunchThemeColor"

    /** `appearance.seed_color`, with the prefix `shared_preferences` applies. */
    private const val KEY_SEED_COLOR = "flutter.appearance.seed_color"

    /**
     * `SHARED_PREFERENCES_NAME` from `SharedPreferencesPlugin.kt`, the file the
     * legacy API actually uses. Hardcoded rather than imported because the
     * plugin's constants are not published on the app's compile classpath.
     */
    private const val PLUGIN_PREFERENCES = "FlutterSharedPreferences"

    /**
     * The applied colour, or [DEFAULT] when nothing is stored.
     *
     * Every failure path lands on the default rather than throwing: a missing
     * file, an unreadable one, a value of an unexpected type, or an alpha that
     * would render the launch screen invisible. The activity cannot afford to
     * fail to start over a cosmetic colour.
     */
    fun read(context: Context): Int {
        // The plugin's own file first; the default file second, so a plugin
        // change of store costs a degraded splash rather than a wrong one.
        val candidates = listOf(
            store(context, PLUGIN_PREFERENCES),
            store(context, "${context.packageName}_preferences"),
        )
        for (prefs in candidates) {
            val stored = try {
                prefs?.all?.get(KEY_SEED_COLOR)
            } catch (_: Throwable) {
                null
            }
            when (stored) {
                // putLong, so this is the branch that runs in practice.
                is Long -> return sanitise(stored.toInt())
                // Defensive: a plugin writing putInt must not lose the colour.
                is Int -> return sanitise(stored)
                else -> Unit
            }
        }
        Log.d(TAG, "No applied brand colour stored; using the default.")
        return DEFAULT
    }

    private fun store(context: Context, name: String): SharedPreferences? = try {
        context.getSharedPreferences(name, Context.MODE_PRIVATE)
    } catch (_: Throwable) {
        null
    }

    /**
     * Forces full opacity.
     *
     * A translucent stored value would let whatever sits behind the launch
     * screen show through, which is the flash this feature exists to remove.
     * The Appearance screen only stores opaque colours; this guards the stored
     * value rather than trusting it.
     */
    private fun sanitise(argb: Int): Int = Color.argb(
        255,
        Color.red(argb),
        Color.green(argb),
        Color.blue(argb),
    )
}