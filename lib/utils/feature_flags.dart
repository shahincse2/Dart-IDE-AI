/// Features that are built but switched off in the current release.
///
/// Git (push to GitHub / GitLab) needs the internet and stores access tokens.
/// It stays off in v1.0, which is fully offline, and comes back in v1.1 together
/// with the internet permission, a new privacy policy and a new Data Safety
/// form. See test/release_policy_test.dart.
const bool kGitEnabled = false;
