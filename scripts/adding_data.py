from faker import Faker

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from dotenv import load_dotenv
import os
import pyodbc
import random


load_dotenv()

credential = DefaultAzureCredential(
    exclude_environment_credential=False,
    exclude_managed_identity_credential=False,
    exclude_shared_token_cache_credential=True,  # skip local cache
    exclude_visual_studio_code_credential=True,
)

key_vault = SecretClient(vault_url=os.environ["KEYVAULT_URL"], credential=credential)


# Azure SQL database connection details

server = key_vault.get_secret("azure-sql-server").value
database = key_vault.get_secret(
    "azure-sql-database"
).value  # Replace with your database name
username = key_vault.get_secret(
    "azure-sql-username"
).value  # Replace with your username
password = key_vault.get_secret(
    "azure-sql-password"
).value  # Replace with your password
driver = "{ODBC Driver 18 for SQL Server}"  # Or your ODBC driver


print("Working")
# Initialize Faker
fake = Faker()

# Number of fake records to generate
num_records = 10000

# SQL connection string
cnxn_str = (
    f"DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password}"
)


def generate_blood_pressure():
    systolic = random.randint(90, 160)  # Realistic Systolic range
    diastolic = random.randint(60, 100)  # Realistic Diastolic range
    return f"{systolic}/{diastolic} mmHg"


print(cnxn_str)

cnxn = pyodbc.connect(cnxn_str)

try:

    cursor = cnxn.cursor()

    # Create table if it doesn't exist (using the CREATE TABLE statement from above)
    cursor.execute(
        """
        IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME = 'PatientMedicalData')
        CREATE TABLE PatientMedicalData (
            PatientID INT PRIMARY KEY IDENTITY,
            FirstName VARCHAR(100),
            LastName VARCHAR(100),
            DateOfBirth DATE,
            Gender VARCHAR(20),
            ContactNumber VARCHAR(100),
            EmailAddress VARCHAR(100),
            Address VARCHAR(255),
            City VARCHAR(100),
            PostalCode VARCHAR(20),
            Country VARCHAR(100),
            MedicalCondition VARCHAR(255),
            Medications VARCHAR(255),
            Allergies VARCHAR(255),
            BloodType VARCHAR(10),
            LastVisitDate DATE,
            SmokingStatus VARCHAR(50),
            AlcoholConsumption VARCHAR(50),
            ExerciseFrequency VARCHAR(50),
            Occupation VARCHAR(100),
            Height_cm DECIMAL(5, 2),
            Weight_kg DECIMAL(5, 2),
            BloodPressure VARCHAR(20),
            HeartRate_bpm INT,
            Temperature_C DECIMAL(3, 1),
            Notes VARCHAR(MAX)
        )
    """
    )
    cnxn.commit()

    # Generate and insert fake data
    for _ in range(num_records):
        first_name = fake.first_name()
        last_name = fake.last_name()
        dob = fake.date_of_birth(minimum_age=18, maximum_age=85)  # Adjusted max age
        gender = fake.random_element(elements=("Male", "Female", "Other"))
        contact_number = fake.phone_number()
        email = fake.email()
        address = fake.address()
        city = fake.city()
        postal_code = fake.postcode()
        country = fake.country()
        medical_condition = fake.random_element(
            elements=(
                "Hypertension",
                "Type 2 Diabetes",
                "Asthma",
                "Migraine",
                "Anxiety",
                "Depression",
                "Arthritis",
                "None",
                "Hyperlipidemia",
                None,
            )
        )  # Added None for no condition
        medications = fake.random_element(
            elements=(
                "Lisinopril",
                "Metformin",
                "Albuterol",
                "Ibuprofen",
                "Sertraline",
                "Acetaminophen",
                "Aspirin",
                "None",
                "Atorvastatin",
                None,
            )
        )  # Added None for no medication
        allergies = fake.random_element(
            elements=(
                "Penicillin",
                "Pollen",
                "Latex",
                "Shellfish",
                "Nuts",
                "Dust Mites",
                "None",
                "Sulfa Drugs",
                None,
            )
        )  # Added None for no allergies
        blood_type = fake.random_element(
            elements=("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")
        )
        last_visit_date = fake.date_between(start_date="-2y", end_date="today")
        smoking_status = fake.random_element(
            elements=(
                "Never Smoker",
                "Former Smoker",
                "Current Smoker",
                "Occasional Smoker",
                "",
            )
        )  # Added empty string for unknown
        alcohol_consumption = fake.random_element(
            elements=(
                "Non-drinker",
                "Light drinker",
                "Social drinker",
                "Moderate drinker",
                "Heavy drinker",
                "",
            )
        )  # Added empty string for unknown
        exercise_frequency = fake.random_element(
            elements=(
                "Daily",
                "3-4 times a week",
                "1-2 times a week",
                "Rarely",
                "Never",
                "",
            )
        )  # Added empty string for unknown
        occupation = fake.job()
        height_cm = fake.pydecimal(
            min_value=150, max_value=200, right_digits=1, positive=True
        )
        weight_kg = fake.pydecimal(
            min_value=50, max_value=150, right_digits=1, positive=True
        )
        blood_pressure = generate_blood_pressure()
        heart_rate_bpm = fake.random_int(
            min=55, max=95
        )  # Adjusted heart rate range to be more realistic resting
        temperature_c = fake.pydecimal(
            min_value=36.0, max_value=37.6, right_digits=1, positive=True
        )  # Adjusted temp range to be more typical normal
        notes = fake.paragraph()

        sql_insert = """
            INSERT INTO PatientMedicalData (FirstName, LastName, DateOfBirth, Gender, ContactNumber, EmailAddress,
                                            Address, City, PostalCode, Country, MedicalCondition, Medications,
                                            Allergies, BloodType, LastVisitDate, SmokingStatus, AlcoholConsumption,
                                            ExerciseFrequency, Occupation, Height_cm, Weight_kg, BloodPressure,
                                            HeartRate_bpm, Temperature_C, Notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        cursor.execute(
            sql_insert,
            (
                first_name,
                last_name,
                dob,
                gender,
                contact_number,
                email,
                address,
                city,
                postal_code,
                country,
                medical_condition,
                medications,
                allergies,
                blood_type,
                last_visit_date,
                smoking_status,
                alcohol_consumption,
                exercise_frequency,
                occupation,
                height_cm,
                weight_kg,
                blood_pressure,
                heart_rate_bpm,
                temperature_c,
                notes,
            ),
        )

        print(f"Executed {_}th row")

    cnxn.commit()
    print(
        f"{num_records} records of realistic fake patient medical data inserted successfully into PatientMedicalData."
    )

except pyodbc.Error as ex:
    sqlstate = ex.args[0]
    if sqlstate == "28000":
        print(
            "Authentication error. Please check your username, password, server, and database."
        )
    else:
        print(f"Error connecting to database or inserting data: {ex}")

finally:
    if cnxn:
        cnxn.close()
