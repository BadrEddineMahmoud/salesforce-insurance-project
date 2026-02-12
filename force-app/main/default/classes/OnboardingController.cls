public with sharing class OnboardingController {

    @AuraEnabled
    public static OnboardingDTO saveStep(String dtoJson) {
        System.debug('=== RAW JSON STRING ===');
        System.debug('dtoJson: ' + dtoJson);
        System.debug('======================');
        
        OnboardingDTO dto = (OnboardingDTO) JSON.deserialize(dtoJson, OnboardingDTO.class);
        
        System.debug('=== DESERIALIZED DTO ===');
        System.debug('DTO: ' + JSON.serialize(dto));
        System.debug('DTO.currentStep: ' + dto.currentStep);
        System.debug('DTO.clientType: ' + dto.clientType);
        System.debug('DTO.firstName: ' + dto.firstName);
        System.debug('DTO.lastName: ' + dto.lastName);
        System.debug('========================');

        if (dto == null) {
            system.debug('DTO is null');
            throw new AuraHandledException('DTO is null');
        }
        if (dto.currentStep == null) {
            dto.currentStep = 1;
            system.debug('Current step was null, set to 1');
        }

        switch on dto.currentStep {

            // STEP 1 – CLIENT TYPE + ACCOUNT
            when 1 {
                system.debug('step 1');
                if (String.isBlank(dto.clientType)) {
                    system.debug('Client type is null');
                    return dto;
                }

                if (dto.clientType == 'PERSON') {
                    PolicyLifecycleService.savePersonAccount(dto);
                    System.debug('Saved person account with ID: ' + dto.accId);
                }
                else if (dto.clientType == 'BUSINESS') {
                    PolicyLifecycleService.saveBusinessAccount(dto);
                    System.debug('Saved business account with ID: ' + dto.accId);
                }
                else {
                    system.debug('Invalid client type: ' + dto.clientType);
                    throw new AuraHandledException('Invalid client type: ' + dto.clientType);
                }
            }

            // STEP 2
            when 2 {
                system.debug('step 2');
                if (dto.clientType == 'BUSINESS') {
                    PolicyLifecycleService.saveContact(dto);
                    System.debug('Saved contact with ID: ' + dto.contactId);
                } else {
                    PolicyLifecycleService.saveVehicle(dto);
                    System.debug('Saved vehicle with ID: ' + dto.vehicleId);
                }
            }

            // STEP 3
            when 3 {
                system.debug('step 3');
                PolicyLifecycleService.saveVehicle(dto);
                system.debug('Saved vehicle with ID: ' + dto.vehicleId);
            }

            // STEP 4 – COVERAGES (NO DML)
            when 4 {
                system.debug('step 4');
                // selectedCoverageIds already populated
            }

            // STEP 5 – FINALIZE
            when 5 {
                system.debug('step 5');
                PolicyLifecycleService.finalizeOnboarding(dto);
            }

            when else {
                throw new AuraHandledException('Unknown onboarding step: ' + dto.currentStep);
            }
        }

        return dto;
    }
}