// Stored data
let paymentData = {};

// Logging utility
function logAction(action, data = null) {
    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] ACTION: ${action}`, data ? data : '');
}

function logError(error, context = '') {
    const timestamp = new Date().toISOString();
    console.error(`[${timestamp}] ERROR${context ? ' in ' + context : ''}: ${error}`);
}

function displayResponse(elementId, response, isError = false) {
    logAction('Displaying response', { elementId, isError, response });
    const element = document.getElementById(elementId);
    element.style.display = 'block';
    element.innerHTML = JSON.stringify(response, null, 2);
    element.style.color = isError ? '#ff4444' : '#00ff00';
}

function showStoredData(elementId, data) {
    logAction('Showing stored data', { elementId, data });
    const element = document.getElementById(elementId);
    element.style.display = 'block';
    const dataDiv = element.querySelector('div');
    dataDiv.innerHTML = Object.entries(data)
        .map(([key, value]) => `<strong>${key}:</strong> ${value}`)
        .join('<br>');
}

async function makeFlaskRequest(endpoint, payload) {
    logAction(`Making Flask request to ${endpoint}`, payload);
    try {
        const response = await fetch(endpoint, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(payload)
        });
        
        const data = await response.json();
        logAction(`Flask response from ${endpoint}`, { status: response.status, data });
        
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${data.error || 'Request failed'}`);
        }
        
        return data;
    } catch (error) {
        logError(error.message, `makeFlaskRequest to ${endpoint}`);
        return { success: false, error: error.message };
    }
}

async function authorizePayment() {
    const fullName = document.getElementById('fullName').value.trim();
    const authAmount = parseInt(document.getElementById('authAmount').value);
    const cardNumber = document.getElementById('cardNumber').value.trim();
    const cvc = document.getElementById('cvc').value.trim();
    const expiryMonth = document.getElementById('expiryMonth').value.trim();
    const expiryYear = document.getElementById('expiryYear').value.trim();
    
    logAction('Starting authorization', { fullName, authAmount, cardNumber: cardNumber.slice(0,4) + '****' });
    
    const btn = document.getElementById('authorizeBtn');
    btn.disabled = true;
    btn.textContent = '⏳ Processing...';
    logAction('Authorization button disabled, processing started');
    
    const payload = {
        fullName: fullName,
        authAmount: authAmount,
        cardNumber: cardNumber,
        cvc: cvc,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear
    };
    
    try {
        const result = await makeFlaskRequest('/api/authorize', payload);
        
        if (result.success) {
            const response = result.data;
            paymentData.pspReference = response.pspReference;
            
            // Check for recurring detail reference in additionalData (common location)
            paymentData.recurringDetailReference = response.recurringDetailReference || 
                                                (response.additionalData && response.additionalData['recurring.recurringDetailReference']) ||
                                                response.pspReference;
            
            paymentData.shopperReference = response.shopperReference;
            paymentData.reference = response.reference;
            
            // Debug: Log the full response to see available fields
            console.log('FULL AUTHORIZATION RESPONSE:', response);
            console.log('ADDITIONAL DATA:', response.additionalData);
            logAction('Authorization successful, payment data stored', paymentData);
            
            displayResponse('authResponse', response);
            showStoredData('storedData1', {
                'PSP Reference': paymentData.pspReference,
                'Recurring Detail Reference': paymentData.recurringDetailReference,
                'Shopper Reference': paymentData.shopperReference
            });
            
            // Enable next step
            document.getElementById('captureBtn').disabled = false;
            logAction('Capture button enabled');
        } else {
            logError(`Authorization failed: ${result.error}`, 'authorizePayment');
            displayResponse('authResponse', { error: result.error }, true);
        }
    } catch (error) {
        logError(error.message, 'authorizePayment');
        displayResponse('authResponse', { error: error.message }, true);
    }
    
    btn.disabled = false;
    btn.textContent = '💳 Authorize 100 EUR Payment';
    logAction('Authorization button re-enabled');
}

async function capturePayment() {
    const captureAmount = parseInt(document.getElementById('captureAmount').value);
    
    logAction('Starting capture payment', { pspReference: paymentData.pspReference, captureAmount });
    
    if (!paymentData.pspReference) {
        logError('PSP Reference missing', 'capturePayment validation');
        alert('Please complete authorization first');
        return;
    }
    
    const btn = document.getElementById('captureBtn');
    btn.disabled = true;
    btn.textContent = '⏳ Capturing...';
    logAction('Capture button disabled, processing started');
    
    const payload = {
        pspReference: paymentData.pspReference,
        reference: paymentData.reference,
        captureAmount: captureAmount
    };
    
    try {
        const result = await makeFlaskRequest('/api/capture', payload);
        
        if (result.success) {
            const response = result.data;
            paymentData.captureReference = response.pspReference;
            logAction('Capture successful', { captureReference: paymentData.captureReference });
            
            displayResponse('captureResponse', response);
            showStoredData('storedData2', {
                'Capture Reference': paymentData.captureReference,
                'Amount Captured': '50.00 EUR'
            });
            
            // Enable next steps
            document.getElementById('refundBtn').disabled = false;
            document.getElementById('recurringBtn').disabled = false;
            logAction('Refund and recurring buttons enabled');
        } else {
            logError(`Capture failed: ${result.error}`, 'capturePayment');
            displayResponse('captureResponse', { error: result.error }, true);
        }
    } catch (error) {
        logError(error.message, 'capturePayment');
        displayResponse('captureResponse', { error: error.message }, true);
    }
    
    btn.disabled = false;
    btn.textContent = '💰 Capture 50 EUR';
    logAction('Capture button re-enabled');
}

async function refundPayment() {
    const refundAmount = parseInt(document.getElementById('refundAmount').value);
    
    logAction('Starting refund payment', { captureReference: paymentData.captureReference, refundAmount });
    
    if (!paymentData.captureReference) {
        logError('Capture reference missing', 'refundPayment validation');
        alert('Please complete capture first');
        return;
    }
    
    const btn = document.getElementById('refundBtn');
    btn.disabled = true;
    btn.textContent = '⏳ Refunding...';
    logAction('Refund button disabled, processing started');
    
    const payload = {
        pspReference: paymentData.pspReference,
        reference: paymentData.reference,
        refundAmount: refundAmount
    };
    
    try {
        const result = await makeFlaskRequest('/api/refund', payload);
        
        if (result.success) {
            logAction('Refund successful', result.data);
            displayResponse('refundResponse', result.data);
        } else {
            logError(`Refund failed: ${result.error}`, 'refundPayment');
            displayResponse('refundResponse', { error: result.error }, true);
        }
    } catch (error) {
        logError(error.message, 'refundPayment');
        displayResponse('refundResponse', { error: error.message }, true);
    }
    
    btn.disabled = false;
    btn.textContent = '🔄 Refund 50 EUR';
    logAction('Refund button re-enabled');
}

async function recurringPayment() {
    const recurringAmount = parseInt(document.getElementById('recurringAmount').value);
    
    logAction('Starting recurring payment', { 
        recurringDetailReference: paymentData.recurringDetailReference,
        shopperReference: paymentData.shopperReference,
        recurringAmount: recurringAmount
    });
    
    if (!paymentData.recurringDetailReference) {
        logError('Recurring detail reference missing', 'recurringPayment validation');
        alert('Please complete authorization with tokenization first');
        return;
    }
    
    const btn = document.getElementById('recurringBtn');
    btn.disabled = true;
    btn.textContent = '⏳ Processing...';
    logAction('Recurring button disabled, processing started');
    
    const payload = {
        recurringDetailReference: paymentData.recurringDetailReference,
        shopperReference: paymentData.shopperReference,
        reference: paymentData.reference,
        recurringAmount: recurringAmount
    };
    
    try {
        const result = await makeFlaskRequest('/api/recurring', payload);
        
        if (result.success) {
            logAction('Recurring payment successful', result.data);
            displayResponse('recurringResponse', result.data);
        } else {
            logError(`Recurring payment failed: ${result.error}`, 'recurringPayment');
            displayResponse('recurringResponse', { error: result.error }, true);
        }
    } catch (error) {
        logError(error.message, 'recurringPayment');
        displayResponse('recurringResponse', { error: error.message }, true);
    }
    
    btn.disabled = false;
    btn.textContent = '🔁 Pay 50 EUR with Token';
    logAction('Recurring button re-enabled');
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    logAction('DOM Content Loaded - Initializing application');
    // Initialize with placeholder name - replace with your actual name
    document.getElementById('fullName').value = 'Mike Schwimmer';
    logAction('Default name set to Mike Schwimmer');
});