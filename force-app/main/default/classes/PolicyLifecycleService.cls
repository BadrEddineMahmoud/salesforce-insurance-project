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

            Decimal premium = calculatePremium(dto.selectedCoverageIds);
            savePolicy(dto, premium);
            saveContract(dto, premium);
            
            // declar new list to hold Contract_Coverage__c records to insert
            List<Contract_Coverage__c> recordsToInsert = new List<Contract_Coverage__c>();
            for (Id coverage : dto.selectedCoverageIds) {
                recordsToInsert.add(new Contract_Coverage__c(
                    Inssurance_Contract__c = dto.contractId,
                    Coverage_Definition__c = coverage,
                    Status__c = 'Draft'
                ));
            }
            upsert recordsToInsert;
        }catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static Decimal calculatePremium(List<Id> coverages) {
        Decimal base = 1000;
        if (coverages != null) base *= coverages.size();
        return base;
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
            Id = dto.accId,
            RecordTypeId = getRt('Business Client'),
            Name = dto.businessName,
            Register_of_Commerce__c = dto.registerOfCommerce,
            //City__c = dto.city,
            Phone = dto.phoneNumber,
            Status__c = 'Draft'
            //ParentId = dto.brokerAccountId
            );
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
            //Premium__c = premium,
            Policy__c  = dto.policyId,
            Status__c  = 'Draft'
        );
        upsert contract;
        dto.contractId = contract.Id;
    }


}