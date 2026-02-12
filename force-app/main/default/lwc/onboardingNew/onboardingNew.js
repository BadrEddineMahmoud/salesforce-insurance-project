import { LightningElement, wire } from 'lwc';
import saveStep from '@salesforce/apex/OnboardingController.saveStep';
import getCoverages from '@salesforce/apex/PolicyLifecycleService.getCoverages';

export default class OnboardingNew extends LightningElement {
    isLoading = false;
    errorMessage = null;

    // Central DTO matching OnboardingDTO
    dto = {
        // Tracking
        currentStep: 1,

        // STEP 1 – ACCOUNT / DRIVER
        clientType: null, // PERSON | BUSINESS
        accId: null,
        firstName: null,
        lastName: null,
        birthDate: null,
        phoneNumber: null,
        city: null,
        nationalId: null,
        driverLicense: null,

        // Business account
        businessName: null,
        registerOfCommerce: null,
        brokerAccountId: null,

        // Contact (driver when not owner)
        contactId: null,
        driverFirstName: null,
        driverLastName: null,
        categoryLicense: null,

        // STEP 2 – VEHICLE
        vehicleId: null,
        vehiclePlate: null,
        vehicleIsNew: false,
        vehicleStartDateOfCirculation: null,
        vehicleBodyType: null,
        vehicleNumberOfPassengers: null,
        vehicleBrand: null,
        vehicleCylinder: null,
        vehicleFiscalHorsepower: null,
        vehicleUsage: null,
        vehicleMake: null,
        vehicleModel: null,
        vehicleFuelType: null,
        vehicleTrailer: false,
        vehicleValue: null,

        // STEP 3 – POLICY / CONTRACT
        policyId: null,
        contractId: null,
        premium: null,

        // STEP 4 – COVERAGES
        selectedCoverageIds: []
    };

    // ---------- STEP HELPERS ----------
    get isStep1() { return this.dto.currentStep === 1; }
    get isStep2() { return this.dto.currentStep === 2; }
    get isStep3() { return this.dto.currentStep === 3; }
    get isStep4() { return this.dto.currentStep === 4; }
    get isStep5() { return this.dto.currentStep === 5; }

    get isBusiness() { return this.dto.clientType === 'BUSINESS'; }
    get isPerson() { return this.dto.clientType === 'PERSON'; }

    clientTypeOptions = [
        { label: 'Person', value: 'PERSON' },
        { label: 'Business', value: 'BUSINESS' }
    ];

    // Coverage options via LDS-backed Apex (cacheable=true)
    coverageOptions = [];
    @wire(getCoverages)
    wiredCoverages({ data, error }) {
        if (data) {
            this.coverageOptions = data.map(c => ({ label: c.Name, value: c.Id }));
        } else if (error) {
            // keep UI resilient; show later if needed
            // eslint-disable-next-line no-console
            console.error('Coverages load error', error);
        }
    }

    // ---------- INPUT HANDLERS ----------
    handleClientTypeChange(event) {
        const raw = event?.detail?.value;
        const val = raw === undefined || raw === null ? null : String(raw);
        // eslint-disable-next-line no-console
        console.log('[onboardingNew] clientType change raw:', raw, 'coerced:', val);
        this.dto = { ...this.dto, clientType: val };
        // clear any prior error when user selects a value
        if (this.errorMessage) {
            this.errorMessage = null;
        }
        // eslint-disable-next-line no-console
        console.log('[onboardingNew] dto after clientType change:', JSON.stringify(this.dto));
    }

    handleInputChange(event) {
        const name = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.dto = { ...this.dto, [name]: value };
        // eslint-disable-next-line no-console
        console.log('[onboardingNew] input change:', name, '=>', value);
    }

    handleCoveragesChange(event) {
        this.dto = { ...this.dto, selectedCoverageIds: event.detail.value || [] };
    }

    // ---------- SAFE PAYLOAD BUILDER ----------
    buildPayload() {
        // Build payload and clean it for Apex deserialization
        const payload = {};
        
        // Helper function to safely add a value
        const addField = (key, value, type) => {
            if (value === undefined) {
                return; // Skip undefined
            }
            
            if (type === 'boolean') {
                // For booleans: only add if explicitly true/false, skip null
                if (value === true || value === false) {
                    payload[key] = value;
                }
                // If null/undefined, don't include the field at all
            } else if (type === 'number') {
                // For numbers: convert empty string to null, skip if null
                if (value === '' || value === null || value === undefined) {
                    // Don't include the field
                } else {
                    payload[key] = value;
                }
            } else if (type === 'date') {
                // For dates: skip if empty/null
                if (value && value !== '') {
                    payload[key] = value;
                }
            } else {
                // For strings and IDs: include even if null (Apex handles this)
                payload[key] = value;
            }
        };
        
        // Tracking
        addField('currentStep', Number(this.dto.currentStep) || 1, 'number');
        
        // STEP 1 - ACCOUNT / DRIVER
        addField('clientType', this.dto.clientType, 'string');
        addField('accId', this.dto.accId, 'string');
        addField('firstName', this.dto.firstName, 'string');
        addField('lastName', this.dto.lastName, 'string');
        addField('birthDate', this.dto.birthDate, 'date');
        addField('phoneNumber', this.dto.phoneNumber, 'string');
        addField('city', this.dto.city, 'string');
        addField('nationalId', this.dto.nationalId, 'string');
        addField('driverLicense', this.dto.driverLicense, 'string');
        addField('businessName', this.dto.businessName, 'string');
        addField('registerOfCommerce', this.dto.registerOfCommerce, 'string');
        addField('brokerAccountId', this.dto.brokerAccountId, 'string');
        addField('contactId', this.dto.contactId, 'string');
        addField('driverFirstName', this.dto.driverFirstName, 'string');
        addField('driverLastName', this.dto.driverLastName, 'string');
        addField('categoryLicense', this.dto.categoryLicense, 'string');
        
        // STEP 2 - VEHICLE
        addField('vehicleId', this.dto.vehicleId, 'string');
        addField('vehiclePlate', this.dto.vehiclePlate, 'string');
        addField('vehicleIsNew', this.dto.vehicleIsNew, 'boolean');
        addField('vehicleStartDateOfCirculation', this.dto.vehicleStartDateOfCirculation, 'date');
        addField('vehicleBodyType', this.dto.vehicleBodyType, 'string');
        addField('vehicleNumberOfPassengers', this.dto.vehicleNumberOfPassengers, 'number');
        addField('vehicleBrand', this.dto.vehicleBrand, 'string');
        addField('vehicleCylinder', this.dto.vehicleCylinder, 'number');
        addField('vehicleFiscalHorsepower', this.dto.vehicleFiscalHorsepower, 'number');
        addField('vehicleUsage', this.dto.vehicleUsage, 'string');
        addField('vehicleMake', this.dto.vehicleMake, 'string');
        addField('vehicleModel', this.dto.vehicleModel, 'string');
        addField('vehicleFuelType', this.dto.vehicleFuelType, 'string');
        addField('vehicleTrailer', this.dto.vehicleTrailer, 'boolean');
        addField('vehicleValue', this.dto.vehicleValue, 'number');
        
        // STEP 3 - POLICY / CONTRACT
        addField('policyId', this.dto.policyId, 'string');
        addField('contractId', this.dto.contractId, 'string');
        addField('premium', this.dto.premium, 'number');
        
        // STEP 4 - COVERAGES
        addField('selectedCoverageIds', this.dto.selectedCoverageIds, 'array');

        // eslint-disable-next-line no-console
        console.log('[onboardingNew] buildPayload returning:', JSON.stringify(payload));
        return payload;
    }

    // ---------- NAVIGATION / SAVE ----------
    async handleNext() {
        this.isLoading = true;
        this.errorMessage = null;

        try {
            // Strong logging: snapshot DTO before any guards
            // eslint-disable-next-line no-console
            console.log('[onboardingNew] BEFORE GUARDS dto:', JSON.stringify(this.dto));

            // Front-end guard: Step 1 requires client type
            const step = Number(this.dto.currentStep) || 1;
            if (step === 1 && !this.dto.clientType) {
                this.errorMessage = 'Select a Client Type to proceed.';
                // eslint-disable-next-line no-console
                console.warn('[onboardingNew] blocked: missing clientType at step 1');
                this.isLoading = false;
                return;
            }

            if (!this.dto.currentStep) {
                this.dto = { ...this.dto, currentStep: 1 };
                // eslint-disable-next-line no-console
                console.log('[onboardingNew] normalized step to 1');
            }

            // Extra check: if clientType somehow falsy, log and continue (server will early-return at step 1)
            if (!this.dto.clientType) {
                // eslint-disable-next-line no-console
                console.warn('[onboardingNew] WARNING: clientType is falsy before payload build');
            }

            // Step 5 finalizes; do not auto-increment beyond 5
            const payload = this.buildPayload();

            // Validate payload keys and types explicitly
            // eslint-disable-next-line no-console
            console.log('[onboardingNew] PAYLOAD KEYS:', Object.keys(payload));
            // eslint-disable-next-line no-console
            console.log('[onboardingNew] PAYLOAD.clientType typeof=', typeof payload.clientType, 'value=', payload.clientType);
            // eslint-disable-next-line no-console
            console.log('[onboardingNew] CALL saveStep');

            const result = await saveStep({ dtoJson: JSON.stringify(payload) });

            // eslint-disable-next-line no-console
            console.log('[onboardingNew] RESULT:', JSON.stringify(result));

            // Merge Apex-returned DTO; increment step unless we are already at 5
            const nextStep = Math.min((this.dto.currentStep || 1) + 1, 5);
            this.dto = { ...this.dto, ...result, currentStep: nextStep };

            // eslint-disable-next-line no-console
            console.log('[onboardingNew] AFTER MERGE dto:', JSON.stringify(this.dto));
        } catch (err) {
            // eslint-disable-next-line no-console
            console.error('[onboardingNew] error in handleNext:', err);
            
            // Extract detailed error information
            let errorMsg = 'Unexpected error';
            if (err.body) {
                // eslint-disable-next-line no-console
                console.error('[onboardingNew] err.body:', JSON.stringify(err.body));
                
                if (err.body.pageErrors && err.body.pageErrors.length > 0) {
                    errorMsg = err.body.pageErrors[0].message;
                } else if (err.body.message) {
                    errorMsg = err.body.message;
                } else if (err.body.fieldErrors) {
                    errorMsg = JSON.stringify(err.body.fieldErrors);
                }
            } else if (err.message) {
                errorMsg = err.message;
            }
            
            this.errorMessage = errorMsg;
            // eslint-disable-next-line no-console
            console.error('[onboardingNew] Full error message:', errorMsg);
        
        } finally {
            // eslint-disable-next-line no-console
            console.log('[onboardingNew] handleNext() finally; isLoading=false');
            this.isLoading = false;
        }
    }

    handleBack() {
        if ((this.dto.currentStep || 1) > 1) {
            this.dto = { ...this.dto, currentStep: this.dto.currentStep - 1 };
        }
    }
}
