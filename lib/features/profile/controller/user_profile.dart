/// The user's identity inside the app.
///
/// [name] stays null until the first-launch intro is completed.
/// [isLoaded] distinguishes "not read from storage yet" from "no name set",
/// so routing decisions never race the preferences load.
class UserProfile {
  final String? name;
  final bool isLoaded;

  const UserProfile({this.name, this.isLoaded = false});

  bool get hasName => name != null && name!.isNotEmpty;

  UserProfile copyWith({String? name, bool? isLoaded}) {
    return UserProfile(
      name: name ?? this.name,
      isLoaded: isLoaded ?? this.isLoaded,
    );
  }
}
