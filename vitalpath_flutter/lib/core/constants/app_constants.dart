class AppConstants {
  // Firestore collections
  static const colUsers = 'users';
  static const colPatients = 'patients';
  static const colDoctors = 'doctors';
  static const colAppointments = 'appointments';
  static const colPrescriptions = 'prescriptions';
  static const colMedicines = 'medicines';
  static const colMeals = 'meals';
  static const colActivityLogs = 'activity_logs';
  static const colNotifications = 'notifications';

  // User types
  static const typePatient = 'patient';
  static const typeDoctor = 'doctor';

  // Appointment status
  static const apptPending = 'pending';
  static const apptConfirmed = 'confirmed';
  static const apptCompleted = 'completed';
  static const apptCancelled = 'cancelled';

  // Medicine frequencies
  static const freqOnce = 'Once daily';
  static const freqTwice = 'Twice daily';
  static const freqThrice = 'Three times daily';
  static const freqAsNeeded = 'As needed';
  static const freqWeekly = 'Weekly';

  // Blood types
  static const bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  // Meal types
  static const mealBreakfast = 'Breakfast';
  static const mealLunch = 'Lunch';
  static const mealDinner = 'Dinner';
  static const mealSnack = 'Snack';

  // Storage paths
  static const storageProfilePhotos = 'profile_photos';
  static const storagePrescriptions = 'prescriptions';
  static const storageReports = 'reports';

  // Notification channels
  static const notifChannelMedicine = 'medicine_reminders';
  static const notifChannelAppointment = 'appointment_reminders';
  static const notifChannelGeneral = 'general';

  // SharedPreferences keys
  static const prefUserType = 'user_type';
  static const prefOnboardingDone = 'onboarding_done';
  static const prefFaceIdEnabled = 'face_id_enabled';
}
