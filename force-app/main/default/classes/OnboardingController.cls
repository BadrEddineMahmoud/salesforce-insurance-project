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

            // STEP 1 – CLIENT TYPE + ACCOUNT (Both PERSON and BUSINESS)
            when 1 {
                system.debug('step 1 - Account');

                PolicyLifecycleService.getParentAccount(dto);
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

            // STEP 2 – VEHICLE (PERSON) or DRIVER (BUSINESS)
            when 2 {
                system.debug('step 2');
                if (dto.clientType == 'BUSINESS') {
                    // For business: Step 2 is Driver/Contact
                    PolicyLifecycleService.saveContact(dto);
                    System.debug('Saved contact with ID: ' + dto.contactId);
                } else {
                    // For person: Step 2 is Vehicle
                    PolicyLifecycleService.saveVehicle(dto);
                    System.debug('Saved vehicle with ID: ' + dto.vehicleId);
                }
            }

            // STEP 3 – REVIEW (PERSON) or VEHICLE (BUSINESS)
            when 3 {
                system.debug('step 3');
                if (dto.clientType == 'BUSINESS') {
                    // For business: Step 3 is Vehicle
                    PolicyLifecycleService.saveVehicle(dto);
                    system.debug('Saved vehicle with ID: ' + dto.vehicleId);
                } else {
                    // For person: Step 3 is Review (no processing needed)
                    system.debug('Review step - no processing');
                }
            }

            // STEP 4 – COVERAGES (PERSON) or REVIEW (BUSINESS)
            when 4 {
                system.debug('step 4');
                if (dto.clientType == 'BUSINESS') {
                    // For business: Step 4 is Review (no processing needed)
                    system.debug('Review step - no processing');
                } else {
                    // For person: Step 4 is Coverages (no DML, just selection)
                    PolicyLifecycleService.finalizeOnboarding(dto);
                    PolicyLifecycleService.populateDownloadDetails(dto);
                    system.debug('Coverages step - selectedCoverageIds already populated');
                }
            }

            // STEP 5 – FINALIZE (PERSON) or COVERAGES (BUSINESS)
            when 5 {
                system.debug('step 5');
                if (dto.clientType == 'BUSINESS') {
                    // For business: Step 5 is Coverages (no DML, just selection)
                    PolicyLifecycleService.finalizeOnboarding(dto);
                    PolicyLifecycleService.populateDownloadDetails(dto);
                    system.debug('Coverages step - selectedCoverageIds already populated');
                } else {
                    // For person: Step 5 is Finalize
                    PolicyLifecycleService.activateContract(dto);
                    system.debug('Finalized onboarding for person');
                }
            }

            // STEP 6 – FINALIZE (BUSINESS only)
            when 6 {
                system.debug('step 6');
                if (dto.clientType == 'BUSINESS') {
                    // For business: Step 6 is Finalize
                    PolicyLifecycleService.activateContract(dto);
                    //PolicyLifecycleService.populateDownloadDetails(dto);
                    system.debug('Finalized onboarding for business');
                } else {
                    system.debug('Download step for PERSON');
                }
            }

            // STEP 7 – DOWNLOAD (BUSINESS only)
            when 7 {
                system.debug('step 7');
                if (dto.clientType == 'BUSINESS') {
                    system.debug('Download step for BUSINESS');
                } else {
                    throw new AuraHandledException('Step 7 should not be reached for PERSON flow');
                }
            }

            when else {
                throw new AuraHandledException('Unknown onboarding step: ' + dto.currentStep);
            }
        }

        return dto;
    }
}