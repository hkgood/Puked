bool isNewer(String latest, String current) {
  try {
    List<int> latestParts = latest.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      int l = i < latestParts.length ? latestParts[i] : 0;
      int c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
  } catch (e) {
    return latest != current;
  }
  return false;
}

void main() {
  String githubVersion = "1.0.4";
  String localVersion = "1.0.3";
  
  print("Github Version: \$githubVersion");
  print("Local Version: \$localVersion");
  print("Update needed? \${isNewer(githubVersion, localVersion)}");
  
  localVersion = "1.0.4";
  print("\nLocal Version: \$localVersion");
  print("Update needed? \${isNewer(githubVersion, localVersion)}");
}
