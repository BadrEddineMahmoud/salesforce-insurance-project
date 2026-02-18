public class OnboardingDTO {

    // =============================
    // STEP 1 – ACCOUNT / DRIVER
    // =============================
    @AuraEnabled public String clientType; // PERSON | BUSINESS
    @AuraEnabled public Id accId;
    @AuraEnabled public String firstName;
    @AuraEnabled public String lastName;
    @AuraEnabled public Date birthDate;
    @AuraEnabled public String phoneNumber;
    @AuraEnabled public String city;
    @AuraEnabled public String nationalId;
    @AuraEnabled public String driverLicense;
    @AuraEnabled public String email;

    // Business account
    @AuraEnabled public String businessName;
    @AuraEnabled public String registerOfCommerce;
    @AuraEnabled public Id brokerAccountId;

    // Contact (driver when not owner)
    @AuraEnabled public Id contactId;
    @AuraEnabled public String driverFirstName;
    @AuraEnabled public String driverLastName;
    @AuraEnabled public String categoryLicense;
    @AuraEnabled public Date licenseIssuanceDate;

    // =============================
    // STEP 2 – VEHICLE
    // =============================
    @AuraEnabled public Id vehicleId;
    @AuraEnabled public String vehiclePlate;
    @AuraEnabled public Boolean vehicleIsNew;
    @AuraEnabled public Date vehicleStartDateOfCirculation;
    @AuraEnabled public String vehicleBodyType;
    @AuraEnabled public Integer vehicleNumberOfPassengers;
    @AuraEnabled public String vehicleBrand;
    @AuraEnabled public Integer vehicleCylinder;
    @AuraEnabled public Integer vehicleFiscalHorsepower;
    @AuraEnabled public String vehicleUsage;
    @AuraEnabled public String vehicleMake;
    @AuraEnabled public String vehicleModel;
    @AuraEnabled public String vehicleFuelType;
    @AuraEnabled public Boolean vehicleTrailer;
    @AuraEnabled public Decimal vehicleValue;

    // =============================
    // STEP 3 – POLICY / CONTRACT
    // =============================
    @AuraEnabled public Id policyId;
    @AuraEnabled public Id contractId;
    @AuraEnabled public Decimal premium;
    @AuraEnabled public Map<Id, Decimal> coveragePremiums; 
    @AuraEnabled public Map<String, String> coverageNames; // Optional: to display names in summary 

    // =============================
    // STEP 4 – COVERAGES
    // =============================
    @AuraEnabled public List<Id> selectedCoverageIds;

    // Optional: tracking
    @AuraEnabled public Integer currentStep;


    // Policy/Contract details for download
    @AuraEnabled public String policyName;
    @AuraEnabled public String contractName;
    @AuraEnabled public List<CoverageDetail> coverageDetails;

    // Inner class for coverage details
    public class CoverageDetail {
        @AuraEnabled public String coverageName;
        @AuraEnabled public Decimal coverageLimit;
        @AuraEnabled public Decimal coveragePremium;
    }

    @AuraEnabled public String brokerName;
    @AuraEnabled public String contractPeriod; // Period in months: 6, 12, 24
    @AuraEnabled public Datetime contractStartDate;
    @AuraEnabled public Datetime contractEndDate;
}