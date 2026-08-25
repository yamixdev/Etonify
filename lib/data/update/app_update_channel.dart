enum AppUpdateChannel { stable, beta }

extension AppUpdateChannelX on AppUpdateChannel {
  bool get acceptsPrereleases => this == AppUpdateChannel.beta;
}
