# Android VPN lifecycle soak test

Use this checklist before a public Android release and after changes to the VPN
service, network monitor, notifications, split tunneling, or `libbox.aar`.

## Test setup

- Test a release or profile APK on at least:
  - one Android 8–12 device;
  - one Android 13–14 device;
  - one Android 15–16 device when available;
  - one Xiaomi/HyperOS or realme device when available.
- Keep both Wi-Fi and mobile data available.
- Use a subscription with at least two confirmed working servers.
- Record the selected profile, selected server, split-tunnel mode, Android
  version, device model, and battery optimization mode.
- Clear logs immediately before the run:

```powershell
adb logcat -c
```

Run the Android unit regression suite before the device test:

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest
```

## Required 30–60 minute scenario

1. Cold-start Etonify and connect to a known working server.
2. Verify VPN traffic, the persistent status notification, selected server,
   latency refresh, and traffic counters.
3. Press Home, turn the screen off for at least 10 minutes, then verify that a
   background app still receives data before reopening Etonify.
4. Open Android recents and swipe Etonify away while the VPN is active.
   Confirm that:
   - the Android VPN indicator stays visible;
   - the Etonify foreground notification stays visible;
   - traffic continues without reopening Etonify;
   - reopening Etonify only restores UI state and does not restart a healthy
     tunnel.
5. Repeat Wi-Fi → mobile data → Wi-Fi three times. On every handover:
   - the same selected server remains selected;
   - traffic recovers without pressing Connect;
   - the UI and notification recover within 15 seconds;
   - no stale Wi-Fi network remains pinned on mobile data.
6. Disable both Wi-Fi and mobile data for 60 seconds. Etonify must show the
   offline state without reporting fake latency. Restore either network and
   confirm automatic recovery to the selected server.
7. Lock and unlock the device several times, including one unlock immediately
   after a network handover. Recovery requests must coalesce instead of
   repeatedly restarting the runtime.
8. From the foreground notification:
   - refresh latency several times quickly and confirm only the latest result
     becomes visible;
   - stop the VPN and confirm both the tunnel and notification disappear;
   - reopen Etonify and confirm the stopped VPN does not resurrect itself.
9. Start and stop the VPN from the Quick Settings tile.
10. Test split tunneling in all supported modes:
    - disabled;
    - selected apps through VPN;
    - selected apps bypass VPN.
    Confirm the selected and unselected apps follow the expected route after a
    Wi-Fi/mobile handover.
11. Enable proxy-only mode and verify the local proxy address, authentication,
    password changes, traffic, stop, and subsequent VPN-mode start.
12. While connected, repeat:
    - 20 connect/disconnect cycles;
    - 20 profile switches;
    - 20 selected-server switches;
    - several full latency checks;
    - subscription refresh.
    No operation may leave the client permanently in “building config”,
    “restoring”, or “stopping”.

## Stop acknowledgement regression checks

- An error event with `running=false` is not a stop acknowledgement. Verify that
  a full restart stays blocked while status reports an active native owner or
  a recorded live service. Delayed state events must not override current status.
- Normal stop, terminal timeout recovery and core restart share one
  `NativeServiceCloseTask` per native lifetime. Repeated stop requests must not
  call `closeService()` concurrently. A wait timeout does not cancel JNI/Go work.
- After a slow close eventually succeeds, cleanup must finish and ownership must
  be released without a second native close or a manual retry. This also applies
  if Android already called the hosting service's `onDestroy()`.
- Start/reload must remain blocked across both VPN/proxy service instances while
  an earlier native close is unconfirmed. Do not clear ownership, DNS cache or
  stop waiters as successful merely to remove a stuck notification.
- If native close throws or never returns, stop remains unconfirmed. This is a
  deliberate safety failure, not successful recovery; a fresh application
  process may be required. Do not replace the original close result with the
  result of an independently retried `closeService()` call.
- No native cleanup waits may run on the Android main looper.

Automated coverage: `NativeServiceCloseTaskTest`, `VpnServiceLifecyclePolicyTest`
and `test/runtime_lifecycle_controller_test.dart`. Device soak testing is still
required for actual JNI/TUN shutdown and Android service recreation.

## Runtime sampling

Capture a baseline after the VPN has been stable for two minutes, then sample
every five minutes:

```powershell
$package = "com.etonify.meow_client"
1..13 | ForEach-Object {
  Get-Date
  adb shell dumpsys meminfo $package |
    Select-String "TOTAL PSS|TOTAL RSS|TOTAL SWAP PSS"
  adb shell dumpsys activity services $package |
    Select-String "MeowVpnService|MeowProxyService|foreground"
  Start-Sleep -Seconds 300
}
```

For a debuggable build, also record file descriptors before and after the
connect/disconnect loop:

```powershell
adb shell "run-as com.etonify.meow_client sh -c 'ls /proc/`$(pidof com.etonify.meow_client)/fd | wc -l'"
```

Keep a separate log capture running during the scenario:

```powershell
$pid = (adb shell pidof com.etonify.meow_client).Trim()
adb logcat --pid=$pid -v threadtime
```

If Android replaces the process, restart the PID-filtered log command and note
the time of replacement.

## Pass criteria

- No crash, ANR, fatal Go error, panic, or unrecoverable JNI timeout.
- Background traffic works before Etonify is reopened.
- Removing the task does not stop an active VPN and does not restart a VPN that
  the user stopped.
- Wi-Fi/mobile handovers and restored connectivity recover automatically.
- The foreground notification and Android VPN indicator match the real runtime.
- Split-tunnel and proxy-only routes remain correct after lifecycle events.
- PSS, RSS, file descriptors, and CPU settle after activity; they must not show
  monotonic growth across repeated cycles.
- No duplicate foreground services, notifications, command clients, or network
  callbacks remain after stop.

Attach the exported Etonify diagnostics, device details, exact scenario step,
and memory samples to every failure report.
