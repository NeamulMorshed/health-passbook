/**
 * Creates 3 test accounts in Firebase Auth + Firestore for Play Store review.
 * Run once: node scripts/create_test_accounts.js
 */

const admin = require('firebase-admin');

// Uses Application Default Credentials (firebase CLI login)
admin.initializeApp({ projectId: 'health-passbook-9a0df' });

const auth = admin.auth();
const db = admin.firestore();

const TEST_PASSWORD = 'OmraTest@2024';

const accounts = [
  {
    email: 'omra.test.patient@gmail.com',
    displayName: 'Test Patient',
    userType: 'patient',
    uid: null,
  },
  {
    email: 'omra.test.doctor@gmail.com',
    displayName: 'Dr. Test Doctor',
    userType: 'doctor',
    uid: null,
  },
  {
    email: 'omra.test.family@gmail.com',
    displayName: 'Test Family Member',
    userType: 'caregiver',
    uid: null,
  },
];

async function createAccounts() {
  console.log('Creating test accounts...\n');

  for (const account of accounts) {
    try {
      // Try to get existing user first
      let userRecord;
      try {
        userRecord = await auth.getUserByEmail(account.email);
        console.log(`[SKIP] ${account.email} already exists (uid: ${userRecord.uid})`);
      } catch {
        userRecord = await auth.createUser({
          email: account.email,
          password: TEST_PASSWORD,
          displayName: account.displayName,
          emailVerified: true,
        });
        console.log(`[OK]   Created ${account.email} (uid: ${userRecord.uid})`);
      }
      account.uid = userRecord.uid;
    } catch (err) {
      console.error(`[ERR]  ${account.email}: ${err.message}`);
      process.exit(1);
    }
  }

  console.log('\nWriting Firestore user documents...\n');

  const patientAccount = accounts.find(a => a.userType === 'patient');
  const doctorAccount  = accounts.find(a => a.userType === 'doctor');
  const familyAccount  = accounts.find(a => a.userType === 'caregiver');

  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  // ── Patient user doc ──────────────────────────────────────────────────────
  batch.set(db.collection('users').doc(patientAccount.uid), {
    uid: patientAccount.uid,
    displayName: 'Test Patient',
    email: patientAccount.email,
    userType: 'patient',
    onboardingComplete: true,
    createdAt: now,
  }, { merge: true });

  // ── Patient health profile ────────────────────────────────────────────────
  batch.set(db.collection('patients').doc(patientAccount.uid), {
    uid: patientAccount.uid,
    name: 'Test Patient',
    dateOfBirth: '1990-01-01',
    bloodType: 'O+',
    height: 170,
    weight: 70,
    allergies: ['Penicillin'],
    chronicConditions: ['Hypertension'],
    emergencyContact: 'Test Family Member',
    onboardingComplete: true,
    updatedAt: now,
  }, { merge: true });

  // ── Sample medicine for patient ───────────────────────────────────────────
  const medRef = db.collection('patients').doc(patientAccount.uid)
    .collection('medicines').doc('test-medicine-1');
  batch.set(medRef, {
    patientId: patientAccount.uid,
    name: 'Amlodipine',
    dosage: '5mg',
    frequency: 'Once daily',
    times: ['08:00'],
    startDate: admin.firestore.Timestamp.now(),
    active: true,
    notes: 'Take with water in the morning',
    createdAt: now,
  }, { merge: true });

  // ── Sample vital for patient ──────────────────────────────────────────────
  batch.set(db.collection('vitals').doc('test-vital-1'), {
    patientId: patientAccount.uid,
    type: 'bloodPressure',
    systolic: 120,
    diastolic: 80,
    unit: 'mmHg',
    recordedAt: admin.firestore.Timestamp.now(),
    createdAt: now,
  }, { merge: true });

  // ── Doctor user doc ───────────────────────────────────────────────────────
  batch.set(db.collection('users').doc(doctorAccount.uid), {
    uid: doctorAccount.uid,
    displayName: 'Dr. Test Doctor',
    email: doctorAccount.email,
    userType: 'doctor',
    onboardingComplete: true,
    createdAt: now,
  }, { merge: true });

  batch.set(db.collection('doctors').doc(doctorAccount.uid), {
    uid: doctorAccount.uid,
    name: 'Dr. Test Doctor',
    specialty: 'General Practitioner',
    hospital: 'Test Medical Centre',
    phone: '+880123456789',
    onboardingComplete: true,
    updatedAt: now,
  }, { merge: true });

  // ── Family member user doc ────────────────────────────────────────────────
  batch.set(db.collection('users').doc(familyAccount.uid), {
    uid: familyAccount.uid,
    displayName: 'Test Family Member',
    email: familyAccount.email,
    userType: 'caregiver',
    onboardingComplete: true,
    createdAt: now,
  }, { merge: true });

  await batch.commit();
  console.log('[OK]   Firestore documents written.\n');

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('TEST ACCOUNTS READY — paste into Play Console:');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  console.log('PATIENT:');
  console.log(`  Email:    ${patientAccount.email}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log(`  UID:      ${patientAccount.uid}`);
  console.log('');
  console.log('DOCTOR:');
  console.log(`  Email:    ${doctorAccount.email}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log(`  UID:      ${doctorAccount.uid}`);
  console.log('');
  console.log('FAMILY MEMBER:');
  console.log(`  Email:    ${familyAccount.email}`);
  console.log(`  Password: ${TEST_PASSWORD}`);
  console.log(`  UID:      ${familyAccount.uid}`);
  console.log('');
  console.log('NOTE: These are Gmail addresses — make sure they');
  console.log('exist as real Google accounts, or use Firebase');
  console.log('password sign-in (email/password auth) in the app.');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  process.exit(0);
}

createAccounts().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
