public with sharing class PolicyLifecycleService {

    

    // =============================
    // HELPERS
    // =============================

    // get coverages to display in onboarding
    @AuraEnabled(cacheable=true)
    public static List<Coverage_Definition__c> getCoverages() {
    return [
        SELECT Id, Name
        FROM Coverage_Definition__c
        //WHERE Is_Active__c = true
        ];
    }

    public static void finalizeOnboarding(OnboardingDTO dto) {
        Savepoint sp = Database.setSavepoint();
        try{

            Decimal premium = calculatePremium(dto);
            savePolicy(dto, premium);
            saveContract(dto, premium);
            
            // declar new list to hold Contract_Coverage__c records to insert
            List<Contract_Coverage__c> recordsToInsert = new List<Contract_Coverage__c>();
            for (Id coverage : dto.selectedCoverageIds) {
                recordsToInsert.add(new Contract_Coverage__c(
                    Inssurance_Contract__c = dto.contractId,
                    Coverage_Definition__c = coverage,
                    Premium_ht__c = dto.coveragePremiums.get(coverage),
                    Status__c = 'Draft'
                ));
            }
            upsert recordsToInsert;
        }catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static Id getRt(String name) {
        return [
            SELECT Id FROM RecordType
            WHERE SObjectType = 'Account'
            AND Name = :name
            LIMIT 1
        ].Id;
    }

    // insert update person account
    public static void savePersonAccount(OnboardingDTO dto) {
        
        Id personRecordTypeId = getRt('Person Account');
        
        // Upsert PERSON ACCOUNT (Account fields only)
        Account acc = new Account(
            RecordTypeId = personRecordTypeId,
            FirstName = dto.firstName,
            LastName  = dto.lastName,
            PersonBirthdate = dto.birthDate,
            PersonEmail = dto.email,
            Phone = dto.phoneNumber,
            Status__c = 'Draft'
        );
        
        // Only set Id if we're updating an existing account
        if (dto.accId != null) {
            acc.Id = dto.accId;
        }
        // Only set ParentId if broker exists
        if (dto.brokerAccountId != null) {
            acc.Broker__c = dto.brokerAccountId;
        }

        try {
            upsert acc;
            dto.accId = acc.Id;
            System.debug('Person Account upserted successfully with ID: ' + acc.Id);
        } catch (DmlException e) {
            System.debug('DML Exception: ' + e.getMessage());
            System.debug('Fields: ' + e.getDmlFieldNames(0));
            System.debug('Status Code: ' + e.getDmlStatusCode(0));
            throw new AuraHandledException('Error saving account: ' + e.getMessage());
        }

        Id personConId = [SELECT Id FROM Contact WHERE AccountId = :acc.Id LIMIT 1].Id;
        // Update related CONTACT (Contact-only fields)
        Contact con = new Contact(
            Id = personConId,
            Driver_License__c = dto.driverLicense,
            license_issuance_date__c = dto.licenseIssuanceDate,
            Category_License__c = dto.categoryLicense,
            Identity_Card__c  = dto.nationalId,
            City__c           = dto.city
        );

        update con;
        dto.contactId = con.Id;
        System.debug('Saved person account with ID: ' + acc.Id + ' and contact ID: ' + con.Id);
    }

    // upsert business account
    public static OnboardingDTO saveBusinessAccount(OnboardingDTO dto){
        Account acc = new Account(
            RecordTypeId = getRt('Business Client'),
            Name = dto.businessName,
            Register_of_Commerce__c = dto.registerOfCommerce,
            //City__c = dto.city,
            Phone = dto.phoneNumber,
            Status__c = 'Draft'
            );

        if (dto.accId != null) {
            acc.Id = dto.accId;
        }
        // Only set ParentId if broker exists
        if (dto.brokerAccountId != null) {
            acc.Broker__c = dto.brokerAccountId;
        }
        upsert acc;
        dto.accId = acc.Id;
        System.debug('Saved business account with ID: ' + acc.Id);
        return dto;
    }
    //Save contact (driver)
    public static void saveContact(OnboardingDTO dto){
        Contact con = new Contact(
            Id = dto.contactId,
            AccountId = dto.accId,
            FirstName = dto.driverFirstName,
            LastName  = dto.driverLastName,
            Identity_Card__c = dto.nationalId,
            Phone = dto.phoneNumber,
            Email = dto.email,
            Driver_License__c = dto.driverLicense,
            license_issuance_date__c = dto.licenseIssuanceDate,
            Category_License__c = dto.categoryLicense,
            Birthdate = dto.birthDate,
            City__c = dto.city
        );
        upsert con;
        dto.contactId = con.Id;
        system.debug('Saved contact with ID: ' + con.Id);
    }
    //save vehicle
    public static void saveVehicle(OnboardingDTO dto){
        Vehicle__c vehicle = new Vehicle__c(
            Id = dto.vehicleId,
            Account__c = dto.accId,
            Name = dto.vehiclePlate,
            Is_New__c = dto.vehicleIsNew,
            Start_Date_of_Circulation__c = dto.vehicleStartDateOfCirculation,
            Body_Type__c = dto.vehicleBodyType,
            Number_of_Passengers__c = dto.vehicleNumberOfPassengers,
            Brand__c    = dto.vehicleBrand,
            Cylinder__c = dto.vehicleCylinder,
            Fiscal_Horsepower__c = dto.vehicleFiscalHorsepower,
            Vehicle_Usage__c = dto.vehicleUsage,
            Make__c    = dto.vehicleMake,
            Model__c   = dto.vehicleModel,
            Fuel_Type__c = dto.vehicleFuelType,
            Trailer__c = dto.vehicleTrailer,
            Value__c    = dto.vehicleValue
        );
        upsert vehicle;
        dto.vehicleId = vehicle.Id;
        system.debug('Saved vehicle with ID: ' + vehicle.Id); 
    }

    //save policy
    private static void savePolicy(OnboardingDTO dto, Decimal premium){
        Policy__c policy = new Policy__c(
            Id = dto.policyId,
            Account__c = dto.accId,
            Vehicle__c = dto.vehicleId,
            Status__c     = 'Draft'
        );
        upsert policy;
        dto.policyId = policy.Id;
    }

    //save contract
    private static void saveContract(OnboardingDTO dto, Decimal premium){
        Inssurance_Contract__c contract = new Inssurance_Contract__c(
            Id = dto.contractId,
            Account__c = dto.accId,
            Contact__c = dto.contactId,
            Vehicle__c = dto.vehicleId,
            Premium__c = premium,
            Policy__c  = dto.policyId,
            Status__c  = 'Draft'
        );
        upsert contract;
        dto.contractId = contract.Id;
    }


    // =============================
    // PREMIUM CALCULATION
    // =============================
    private static Decimal getRC(Integer hp){
        if(hp < 6){
            hp = 6;
        }
        List<RC_base__mdt> rclist = [
            SELECT Cheuveaux__c, Base__c FROM RC_base__mdt
            WHERE Cheuveaux__c <= :hp
            ORDER BY Cheuveaux__c DESC
            LIMIT 1
        ];
        
        if (rclist.isEmpty()) {
            return 6; // or throw error
        }
        
        return rclist[0].Base__c;
    }

    private static Decimal getDriverExperienceFactor(Integer yearsOfExperience){
        List<Driver_Experience__mdt> factors = [
            SELECT Years_of_experience__c, Factor__c
            FROM Driver_Experience__mdt
            WHERE Years_of_experience__c <= :yearsOfExperience
            ORDER BY Years_of_experience__c DESC
            LIMIT 1
        ];

        if (factors.isEmpty()) {
            return 1; // default neutral factor
        }

        return factors[0].Factor__c;
    }

    public static Decimal getHpFactor(Integer hp) {
        List<Coverage_Factor_hp__mdt> factors = [
            SELECT hp__c, Factor__c
            FROM Coverage_Factor_hp__mdt
            WHERE hp__c <= :hp
            ORDER BY hp__c DESC
            LIMIT 1
        ];

        if (factors.isEmpty()) {
            return 1; // neutral default
        }

        return factors[0].Factor__c;
    }

    public static Decimal getUsageFactor(String usage) {
        List<Coverage_Factor_usage__mdt> factors = [
            SELECT Usage__c, Factor__c
            FROM Coverage_Factor_usage__mdt
            WHERE Usage__c = :usage
            LIMIT 1
        ];

        if (factors.isEmpty()) {
            return 1; // neutral default
        }

        return factors[0].Factor__c;
    }

    public static Decimal calculatePremium(OnboardingDTO dto) {
        // Declare variables
        Integer hp;
        String usage;
        Integer yearsOfExperience;
        Decimal vehicleCurrentValue;
        
        // Query vehicle data
        List<Vehicle__c> vehicles = [
            SELECT Fiscal_Horsepower__c, Vehicle_Usage__c, Current_Value__c 
            FROM Vehicle__c 
            WHERE Id = :dto.vehicleId
            LIMIT 1
        ];
        
        if (vehicles.isEmpty()) {
            throw new AuraHandledException('Vehicle not found: ' + dto.vehicleId);
        }
        
        Vehicle__c vehicle = vehicles[0];
        hp = vehicle.Fiscal_Horsepower__c != null ? Integer.valueOf(vehicle.Fiscal_Horsepower__c) : 6;
        usage = vehicle.Vehicle_Usage__c;
        vehicleCurrentValue = vehicle.Current_Value__c != null ? vehicle.Current_Value__c : 0;
        
        // Query contact data
        List<Contact> contacts = [
            SELECT Years_of_experience__c 
            FROM Contact 
            WHERE Id = :dto.contactId
            LIMIT 1
        ];
        
        if (contacts.isEmpty()) {
            throw new AuraHandledException('Contact not found: ' + dto.contactId);
        }
        
        yearsOfExperience = contacts[0].Years_of_experience__c != null ? Integer.valueOf(contacts[0].Years_of_experience__c) : 6;
        
        // Calculate factors
        Decimal basePremium = getRC(hp);
        Decimal hpFactor = getHpFactor(hp);
        Decimal usageFactor = getUsageFactor(usage);
        Decimal experienceFactor = getDriverExperienceFactor(yearsOfExperience);
        
        // Query coverages
        List<Coverage_Definition__c> coverages = [
            SELECT Id, Name, Base__c
            FROM Coverage_Definition__c
            WHERE Id IN :dto.selectedCoverageIds
        ];
        
        // Sum Base__c percentages
        Decimal totalBaseCov = 0;
        for (Coverage_Definition__c cov : coverages) {
            totalBaseCov += cov.Base__c != null ? cov.Base__c : 0;
        }
        
        // Calculate premium (you may want to apply the factors here)
        Decimal optCovFactor = hpFactor*usageFactor*experienceFactor;
        Decimal premium = basePremium + ((vehicleCurrentValue * totalBaseCov)*optCovFactor);

        Map<Id, Decimal> coveragePremiums = new Map<Id, Decimal>();
        Map<String, String> coverageNames = new Map<String, String>();
        for (Coverage_Definition__c cov : coverages) {
            Decimal coverageBase = 0;
            Decimal covPremium = 0;
            if (cov.Base__c == null){
                covPremium = basePremium;
            } else {
                coverageBase = cov.Base__c != null ? cov.Base__c : 0; // NULL SAFETY
                covPremium = (vehicleCurrentValue * coverageBase)*optCovFactor;
            }
            coveragePremiums.put(cov.Id, covPremium);
            coverageNames.put(String.valueOf(cov.Id), cov.Name);
        }
        dto.coveragePremiums = coveragePremiums;
        dto.coverageNames = coverageNames;
        dto.premium = premium;  

        
        // Optional: Apply factors to premium
        
        
        System.debug('Premium calculation: base=' + basePremium + ', totalBaseCov=' + totalBaseCov + ', optCovFactor=' + optCovFactor + ', result=' + premium);
        
        return premium;
    }

    public static void activateContract(OnboardingDTO dto) {
        Inssurance_Contract__c contract = [SELECT Id, Name, Status__c FROM Inssurance_Contract__c WHERE Id = :dto.contractId LIMIT 1];
        if (contract == null) {
            throw new AuraHandledException('Contract not found: ' + dto.contractId);
        }
        contract.Status__c = 'Active';
        update contract;
    }

    public static void populateDownloadDetails(OnboardingDTO dto) {
        // Get Policy Name
        Policy__c policy = [SELECT Name FROM Policy__c WHERE Id = :dto.policyId LIMIT 1];
        dto.policyName = policy.Name;

        // Get Contract Name
        Inssurance_Contract__c contract = [SELECT Name FROM Inssurance_Contract__c WHERE Id = :dto.contractId LIMIT 1];
        dto.contractName = contract.Name;

        // Get Coverage Details with Limits
        List<Contract_Coverage__c> contractCoverages = [
            SELECT Id, Coverage_Definition__c, Coverage_Definition__r.Name, 
                Coverage_Definition__r.Limite__c, Premium_ht__c
            FROM Contract_Coverage__c
            WHERE Inssurance_Contract__c = :dto.contractId
        ];
        
        dto.coverageDetails = new List<OnboardingDTO.CoverageDetail>();
        for (Contract_Coverage__c cc : contractCoverages) {
            OnboardingDTO.CoverageDetail detail = new OnboardingDTO.CoverageDetail();
            detail.coverageName = cc.Coverage_Definition__r.Name;
            detail.coverageLimit = cc.Coverage_Definition__r.Limite__c;
            detail.coveragePremium = cc.Premium_ht__c;
            dto.coverageDetails.add(detail);
        }
        
        System.debug('Populated download details for policy: ' + dto.policyName);
    }

    public static void getParentAccount(OnboardingDTO dto) {
        // Get current user with account info
        List<User> users = [
            SELECT AccountId, Account.RecordType.Name, Account.Name
            FROM User 
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        
        if (users.isEmpty()) {
            throw new AuraHandledException('User not found');
        }
        
        User currentUser = users[0];
        
        // Check if user has an associated account
        if (currentUser.AccountId == null) {
            // Internal user (not associated with any account)
            dto.brokerAccountId = null;
            dto.brokerName = 'Intern';
            System.debug('Internal user - no broker account');
            return;
        }
        
        // Check if account is a Broker
        if (currentUser.Account.RecordType.Name == 'Broker') {
            dto.brokerAccountId = currentUser.AccountId;
            dto.brokerName = currentUser.Account.Name;
            System.debug('Broker account: ' + dto.brokerName);
        } else {
            // User has an account but it's not a Broker (e.g., other partner types)
            dto.brokerAccountId = null;
            dto.brokerName = 'Intern';
            System.debug('Non-broker account - treating as Intern');
        }
    }
}