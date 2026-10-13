/// Application string constants for localization support
class AppStrings {
  AppStrings._();

  // App Info
  static const String appName = 'HRMS';
  static const String poweredBy = 'Powered By';
  static const String companyName = 'Info Quest';

  // Login Screen
  static const String welcomeBack = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue to your account';
  static const String username = 'Username';
  static const String password = 'Password';
  static const String login = 'Login';
  static const String loginFailed = 'Login failed. Please check your credentials.';
  static const String usernameRequired = 'Username is required';
  static const String passwordRequired = 'Password is required';
  static const String passwordMinLength = 'Password must be at least 6 characters';

  // Landing Screen
  static const String verificationTasks = 'Verification Tasks';
  static const String pullToRefresh = 'Pull to refresh';
  static const String noTasksFound = 'No verification tasks found';
  static const String noTasksSubtitle = 'Check back later for new assignments';

  // Profile Details
  static const String profileDetails = 'Profile Details';
  static const String personalInfo = 'Personal Information';
  static const String locationInfo = 'Location Information';
  static const String verificationStatus = 'Verification Status';
  static const String targetLocation = 'Target Location';
  static const String currentLocation = 'Your Current Location';
  static const String distance = 'Distance';

  // Location Validation
  static const String locationValidated = 'Location validated successfully';
  static const String locationOutOfRange = 'You must be at the verification location';
  static const String withinRange = 'You are within the allowed radius';
  static const String checkingLocation = 'Checking your location...';
  static const String locationPermissionRequired = 'Location permission is required';
  static const String enableLocationServices = 'Please enable location services';

  // Photo Capture
  static const String capturePhoto = 'Capture Photo';
  static const String retakePhoto = 'Retake Photo';
  static const String photoPreview = 'Photo Preview';
  static const String photoCaptured = 'Photo captured successfully';
  static const String photoRequired = 'Please capture a photo first';

  // Submission
  static const String submit = 'Submit Verification';
  static const String submitSuccess = 'Verification submitted successfully';
  static const String submitFailed = 'Failed to submit verification';
  static const String remarks = 'Remarks (Optional)';
  static const String addRemarks = 'Add any additional notes here...';

  // Additional Info
  static const String additionalInfoRequired = 'Additional Information Required';
  static const String enterMessage = 'Enter your message';
  static const String sendMessage = 'Send Message';
  static const String messageSent = 'Message sent successfully';

  // Status Labels
  static const String statusPending = 'Pending';
  static const String statusSubmitted = 'Submitted';
  static const String statusNeedInfo = 'Need Info';
  static const String statusApproved = 'Approved';
  static const String statusRejected = 'Rejected';

  // General
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String ok = 'OK';
  static const String save = 'Save';
  static const String logout = 'Logout';
  static const String logoutConfirmation = 'Are you sure you want to logout?';
  static const String networkError = 'Network error. Please check your connection.';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
}

