import { LightningElement, wire } from 'lwc';
import saveStep from '@salesforce/apex/OnboardingController.saveStep';
import getCoverages from '@salesforce/apex/PolicyLifecycleService.getCoverages';

export default class OnboardingNew extends LightningElement {
    isLoading = false;
    errorMessage = null;

    // Central DTO
    dto = {
        currentStep: null, // Will be set by flow
        clientType: null,
        accId: null,
        firstName: null,
        lastName: null,
        birthDate: null,
        phoneNumber: null,
        email: null,
        city: null,
        nationalId: null,
        driverLicense: null,
        businessName: null,
        registerOfCommerce: null,
        brokerAccountId: null,
        contactId: null,
        driverFirstName: null,
        driverLastName: null,
        categoryLicense: null,
        licenseIssuanceDate: null,
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
        contractPeriod: '12', // Default to 12 months
        policyId: null,
        contractId: null,
        premium: null,
        coveragePremiums: null,
        coverageNames: null,
        selectedCoverageIds: []
    };

    // Current step in the flow
    currentStepName = 'ACCOUNT';

    // ---------- FLOW DEFINITION ----------
    // Define the flow for each client type
    FLOWS = {
        PERSON: ['ACCOUNT', 'VEHICLE', 'REVIEW', 'COVERAGES', 'FINALIZE', 'DOWNLOAD'],
        BUSINESS: ['ACCOUNT', 'DRIVER', 'VEHICLE', 'REVIEW', 'COVERAGES', 'FINALIZE', 'DOWNLOAD']
    };

    // Map step names to Apex step numbers
    STEP_TO_APEX_NUMBER = {
        ACCOUNT: 1,
        DRIVER: 2,
        VEHICLE: 2, // For PERSON, or 3 for BUSINESS (handled dynamically)
        REVIEW: 3,
        COVERAGES: 4,
        FINALIZE: 5
    };

    // ---------- STEP HELPERS ----------
    get currentFlow() {
        return this.dto.clientType ? this.FLOWS[this.dto.clientType] : this.FLOWS.PERSON;
    }

    get currentStepIndex() {
        return this.currentFlow.indexOf(this.currentStepName);
    }

    get isFirstStep() {
        return this.currentStepIndex === 0;
    }

    get isLastStep() {
        return this.currentStepIndex === this.currentFlow.length - 1;
    }

    // Step visibility getters
    get isAccountStep() { return this.currentStepName === 'ACCOUNT'; }
    get isDriverStep() { return this.currentStepName === 'DRIVER'; }
    get isVehicleStep() { return this.currentStepName === 'VEHICLE'; }
    get isReviewStep() { return this.currentStepName === 'REVIEW'; }
    get isCoveragesStep() { return this.currentStepName === 'COVERAGES'; }
    get isFinalizeStep() { return this.currentStepName === 'FINALIZE'; }
    get isDownloadStep() { return this.currentStepName === 'DOWNLOAD'; }

    // Client type helpers
    get isBusiness() { return this.dto.clientType === 'BUSINESS'; }
    get isPerson() { return this.dto.clientType === 'PERSON'; }

    clientTypeOptions = [
        { label: 'Person', value: 'PERSON' },
        { label: 'Business', value: 'BUSINESS' }
    ];

    categoryLicenseOptions = [
        { label: 'A1', value: 'A1' },
        { label: 'B', value: 'B' },
        { label: 'C', value: 'C' },
        { label: 'D', value: 'D' },
        { label: 'EB', value: 'EB' },
        { label: 'EC', value: 'EC' },
        { label: 'ED', value: 'ED' }
    ];

    vehicleUsageOptions = [
        { label: 'Tourisme', value: 'Tourisme' },
        { label: 'Professional', value: 'Professional' }
    ];

    bodyTypeOptions = [
        { label: 'Sedan', value: 'Sedan' },
        { label: 'Hatchback', value: 'Hatchback' },
        { label: 'Coupe', value: 'Coupe' },
        { label: 'Convertible', value: 'Convertible' },
        { label: 'SUV', value: 'SUV' },
        { label: 'Pickup', value: 'Pickup' },
        { label: 'Van', value: 'Van' },
        { label: 'Minibus', value: 'Minibus' },
        { label: 'Bus', value: 'Bus' },
        { label: 'Truck', value: 'Truck' },
        { label: 'Motorcycle', value: 'Motorcycle' },
        { label: 'Scooter', value: 'Scooter' }
    ];

    fuelTypeOptions = [
        { label: 'Essence', value: 'Essence' },
        { label: 'Diesel', value: 'Diesel' },
        { label: 'Electric', value: 'Electric' }
    ];

    makeOptions = [
        { label: 'Toyota', value: 'Toyota' },
        { label: 'Mercedes', value: 'Mercedes' },
        { label: 'Dacia', value: 'Dacia' },
        { label: 'Renault', value: 'Renault' },
        { label: 'Volkswagen', value: 'Volkswagen' },
        { label: 'BMW', value: 'BMW' },
        { label: 'Audi', value: 'Audi' },
        { label: 'Tesla', value: 'Tesla' }
    ];

    // Add after clientTypeOptions
    periodOptions = [
        { label: '6 Months', value: '6' },
        { label: '12 Months', value: '12' },
        { label: '24 Months', value: '24' }
    ];

    // Add these after your existing getters (around line 110)

    // Formatted values for review step
    get vehicleIsNewLabel() {
        return this.dto.vehicleIsNew ? 'Yes' : 'No';
    }

    get vehicleTrailerLabel() {
        return this.dto.vehicleTrailer ? 'Yes' : 'No';
    }

    get vehicleValueFormatted() {
        if (!this.dto.vehicleValue) return '-';
        return new Intl.NumberFormat('en-US', { 
            style: 'currency', 
            currency: 'MAD' 
        }).format(this.dto.vehicleValue);
    }

    get premiumFormatted() {
        if (!this.dto.premium) return '-';
        return new Intl.NumberFormat('en-US', { 
            style: 'currency', 
            currency: 'MAD' 
        }).format(this.dto.premium);
    }

    get coveragePremiumsArray() {
        if (!this.dto.coveragePremiums || !this.dto.coverageNames) return [];
        
        return Object.keys(this.dto.coveragePremiums).map(covId => {
            return {
                id: covId,
                name: this.dto.coverageNames[covId] || 'Unknown Coverage',
                premium: new Intl.NumberFormat('en-US', { 
                    style: 'currency', 
                    currency: 'MAD' 
                }).format(this.dto.coveragePremiums[covId])
            };
        });
    }

    get contractStartDateFormatted() {
        if (!this.dto.contractStartDate) return '-';
        
        // Convert ISO string to Date object if needed
        const date = new Date(this.dto.contractStartDate);
        
        // Format as readable date/time
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    get contractEndDateFormatted() {
        if (!this.dto.contractEndDate) return '-';
        
        const date = new Date(this.dto.contractEndDate);
        
        return new Intl.DateTimeFormat('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        }).format(date);
    }

    // Coverage options
    coverageOptions = [];
    @wire(getCoverages)
    wiredCoverages({ data, error }) {
        if (data) {
            this.coverageOptions = data.map(c => ({ label: c.Name, value: c.Id }));
        } else if (error) {
            console.error('Coverages load error', error);
        }
    }

    // ---------- NAVIGATION ----------
    goToNextStep() {
        if (this.isLastStep) return;
        
        const nextIndex = this.currentStepIndex + 1;
        this.currentStepName = this.currentFlow[nextIndex];
        
        console.log('[onboardingNew] Navigated to step:', this.currentStepName);
    }

    goToPreviousStep() {
        if (this.isFirstStep) return;
        
        const prevIndex = this.currentStepIndex - 1;
        this.currentStepName = this.currentFlow[prevIndex];
        
        console.log('[onboardingNew] Navigated back to step:', this.currentStepName);
    }

    // ---------- INPUT HANDLERS ----------
    handleClientTypeChange(event) {
        const val = event?.detail?.value;
        console.log('[onboardingNew] clientType change:', val);
        
        this.dto = { ...this.dto, clientType: val };
        
        // Reset to first step when client type changes
        this.currentStepName = 'ACCOUNT';
        
        if (this.errorMessage) {
            this.errorMessage = null;
        }
    }

    handleInputChange(event) {
        const name = event.target.name;
        let value;
        
        if (event.target.type === 'checkbox') {
            value = event.target.checked;
        } else if (event.target.type === 'number') {
            value = event.target.value === '' ? null : event.target.value;
        } else if (event.target.type === 'date') {
            value = event.target.value === '' ? null : event.target.value;
        } else {
            value = event.target.value;
        }
        
        this.dto = { ...this.dto, [name]: value };
        console.log('[onboardingNew] input change:', name, '=>', value);
    }

    handleCoveragesChange(event) {
        this.dto = { ...this.dto, selectedCoverageIds: event.detail.value || [] };
    }

    handlePeriodChange(event) {
        this.dto = { ...this.dto, contractPeriod: event.detail.value };
        console.log('[onboardingNew] Contract period changed to:', event.detail.value);
    }

    handleDownload() {
        // Get the policy document content
        const element = this.template.querySelector('#policy-document');
        if (!element) return;

        // Create a printable version
        const printWindow = window.open('', '_blank');
        printWindow.document.write(`
            <html>
                <head>
                    <title>Policy ${this.dto.policyName}</title>
                    <style>
                        body { font-family: Arial, sans-serif; padding: 40px; }
                        h1 { text-align: center; }
                        h3 { border-bottom: 2px solid #333; padding-bottom: 5px; margin-top: 20px; }
                        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
                        table, th, td { border: 1px solid #ddd; }
                        th, td { padding: 8px; text-align: left; }
                        th { background-color: #f0f0f0; }
                        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
                    </style>
                </head>
                <body>
                    ${element.innerHTML}
                </body>
            </html>
        `);
        printWindow.document.close();
        printWindow.print();
    }

    handleDone() {
        // Navigate to home or show success message
        // For now, just show a message
        this.errorMessage = null;
        console.log('Policy onboarding completed successfully');
        
        // Optionally: navigate to the policy record
        // Or reset the form for a new onboarding
    }

    // ---------- APEX STEP NUMBER MAPPING ----------
    getApexStepNumber() {
        // Map named step to Apex step number based on client type
        if (this.currentStepName === 'ACCOUNT') return 1;
        if (this.currentStepName === 'DRIVER') return 2;
        if (this.currentStepName === 'VEHICLE') {
            return this.dto.clientType === 'PERSON' ? 2 : 3;
        }
        if (this.currentStepName === 'REVIEW') {
            return this.dto.clientType === 'PERSON' ? 3 : 4;
        }
        if (this.currentStepName === 'COVERAGES') {
            return this.dto.clientType === 'PERSON' ? 4 : 5;
        }
        if (this.currentStepName === 'FINALIZE') {
            return this.dto.clientType === 'PERSON' ? 5 : 6;
        }
        if (this.currentStepName === 'DOWNLOAD') {
            return this.dto.clientType === 'PERSON' ? 6 : 7;
        }
        return 1;
    }

    // ---------- PAYLOAD BUILDER ----------
    buildPayload() {
        const payload = {};
        
        const addField = (key, value, type) => {
            if (value === undefined) return;
            
            if (type === 'boolean') {
                if (value === true || value === false) {
                    payload[key] = value;
                }
            } else if (type === 'number') {
                if (value !== '' && value !== null && value !== undefined) {
                    payload[key] = value;
                }
            } else if (type === 'date') {
                if (value && value !== '') {
                    payload[key] = value;
                }
            } else {
                payload[key] = value;
            }
        };
        
        // Add the Apex step number
        addField('currentStep', this.getApexStepNumber(), 'number');
        
        // ACCOUNT / DRIVER
        addField('clientType', this.dto.clientType, 'string');
        addField('accId', this.dto.accId, 'string');
        addField('firstName', this.dto.firstName, 'string');
        addField('lastName', this.dto.lastName, 'string');
        addField('birthDate', this.dto.birthDate, 'date');
        addField('phoneNumber', this.dto.phoneNumber, 'string');
        addField('city', this.dto.city, 'string');
        addField('nationalId', this.dto.nationalId, 'string');
        addField('driverLicense', this.dto.driverLicense, 'string');
        addField('licenseIssuanceDate', this.dto.licenseIssuanceDate, 'date');
        addField('email', this.dto.email, 'string');  // Add after driverLicense
        addField('businessName', this.dto.businessName, 'string');
        addField('registerOfCommerce', this.dto.registerOfCommerce, 'string');
        addField('brokerAccountId', this.dto.brokerAccountId, 'string');
        addField('contactId', this.dto.contactId, 'string');
        addField('driverFirstName', this.dto.driverFirstName, 'string');
        addField('driverLastName', this.dto.driverLastName, 'string');
        addField('categoryLicense', this.dto.categoryLicense, 'string');
        
        // VEHICLE
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
        
        // POLICY / CONTRACT
        addField('policyId', this.dto.policyId, 'string');
        addField('contractId', this.dto.contractId, 'string');
        addField('premium', this.dto.premium, 'number');
        
        // COVERAGES
        addField('contractPeriod', this.dto.contractPeriod, 'string');
        addField('selectedCoverageIds', this.dto.selectedCoverageIds, 'array');

        console.log('[onboardingNew] buildPayload returning:', JSON.stringify(payload));
        return payload;
    }

    // ---------- VALIDATION ----------
    validateCurrentStep() {
        const step = this.currentStepName;
        
        if (step === 'ACCOUNT') {
            if (!this.dto.clientType) {
                this.errorMessage = 'Select a Client Type to proceed.';
                return false;
            }
            
            if (this.dto.clientType === 'PERSON' && (!this.dto.firstName || !this.dto.lastName)) {
                this.errorMessage = 'First Name and Last Name are required for Person accounts.';
                return false;
            }
            
            if (this.dto.clientType === 'BUSINESS' && !this.dto.businessName) {
                this.errorMessage = 'Business Name is required for Business accounts.';
                return false;
            }
        }
        
        if (step === 'DRIVER') {
            if (!this.dto.driverFirstName || !this.dto.driverLastName) {
                this.errorMessage = 'Driver First Name and Last Name are required.';
                return false;
            }
        }
        
        // Add more validations as needed
        
        return true;
    }

    // ---------- SAVE & NAVIGATE ----------
    async handleNext() {
        this.isLoading = true;
        this.errorMessage = null;

        try {
            // Validate current step
            if (!this.validateCurrentStep()) {
                this.isLoading = false;
                return;
            }

            const payload = this.buildPayload();
            console.log('[onboardingNew] CALL saveStep with payload:', JSON.stringify(payload));

            const result = await saveStep({ dtoJson: JSON.stringify(payload) });
            console.log('[onboardingNew] RESULT:', JSON.stringify(result));

            // Merge Apex-returned DTO
            this.dto = { ...this.dto, ...result };

            // Navigate to next step in flow
            this.goToNextStep();

            console.log('[onboardingNew] AFTER MERGE dto:', JSON.stringify(this.dto));
        } catch (err) {
            console.error('[onboardingNew] error in handleNext:', err);
            
            let errorMsg = 'Unexpected error';
            if (err.body) {
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
            console.error('[onboardingNew] Full error message:', errorMsg);
        } finally {
            this.isLoading = false;
        }
    }

    handleBack() {
        this.goToPreviousStep();
    }

    
}