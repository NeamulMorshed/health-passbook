import json, urllib.request, urllib.error

PROJECT = "health-passbook-9a0df"
BASE = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"

PATIENT_UID = "PL1LJjhLeqeLAmhcL2obcFQrY992"
DOCTOR_UID  = "Y0j9xzBBsfMfntroX2h9IDB5Pm72"
FAMILY_UID  = "4J8aapB0fjaCfKjjZo2kL1YPfXd2"

def refresh_token():
    with open("/Users/nahid/.config/configstore/firebase-tools.json") as f:
        d = json.load(f)
    rt = d["tokens"]["refresh_token"]
    data = urllib.parse.urlencode({
        "client_id": "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
        "client_secret": "j9iVZfS8kkCEFUPaAeJV0sAi",
        "refresh_token": rt,
        "grant_type": "refresh_token"
    }).encode()
    req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())["access_token"]

import urllib.parse

TOKEN = refresh_token()

def write(path, fields):
    url = f"{BASE}/{path}"
    payload = json.dumps({"fields": fields}).encode()
    req = urllib.request.Request(url, data=payload, method="PATCH")
    req.add_header("Authorization", f"Bearer {TOKEN}")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as r:
            d = json.loads(r.read())
            print(f"  OK  {path}")
    except urllib.error.HTTPError as e:
        body = json.loads(e.read())
        print(f"  ERR {path}: {body.get('error',{}).get('message','')}")

def s(v): return {"stringValue": v}
def b(v): return {"booleanValue": v}
def n(v): return {"doubleValue": v}
def arr(*vals): return {"arrayValue": {"values": [s(x) for x in vals]}}

print("Writing user documents...")
write(f"users/{PATIENT_UID}", {"uid":s(PATIENT_UID),"displayName":s("Test Patient"),"email":s("omra.test.patient@gmail.com"),"userType":s("patient"),"onboardingComplete":b(True)})
write(f"users/{DOCTOR_UID}",  {"uid":s(DOCTOR_UID), "displayName":s("Dr. Test Doctor"),"email":s("omra.test.doctor@gmail.com"),"userType":s("doctor"),"onboardingComplete":b(True)})
write(f"users/{FAMILY_UID}",  {"uid":s(FAMILY_UID), "displayName":s("Test Family Member"),"email":s("omra.test.family@gmail.com"),"userType":s("caregiver"),"onboardingComplete":b(True)})

print("Writing patient profile...")
write(f"patients/{PATIENT_UID}", {
    "uid":s(PATIENT_UID),"name":s("Test Patient"),"dateOfBirth":s("1990-01-01"),
    "bloodType":s("O+"),"height":n(170),"weight":n(70),
    "allergies":arr("Penicillin"),"chronicConditions":arr("Hypertension"),"onboardingComplete":b(True)
})

print("Writing doctor profile...")
write(f"doctors/{DOCTOR_UID}", {
    "uid":s(DOCTOR_UID),"name":s("Dr. Test Doctor"),
    "specialty":s("General Practitioner"),"hospital":s("Test Medical Centre"),
    "phone":s("+880123456789"),"onboardingComplete":b(True)
})

print("Writing medicine for patient...")
write(f"patients/{PATIENT_UID}/medicines/test-med-1", {
    "patientId":s(PATIENT_UID),"name":s("Amlodipine"),"dosage":s("5mg"),
    "frequency":s("Once daily"),"times":arr("08:00"),"active":b(True),
    "notes":s("Take with water in the morning")
})

print("Writing vital for patient...")
write(f"vitals/test-vital-1", {
    "patientId":s(PATIENT_UID),"type":s("bloodPressure"),
    "systolic":{"integerValue":120},"diastolic":{"integerValue":80},"unit":s("mmHg")
})

print("\nAll done! Test accounts ready.")
