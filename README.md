# Adyen Payment Flow Demo

A complete demonstration of Adyen's payment processing flow including authorization, capture, refund, and recurring payments. Available as a Flask web application a command-line shell script with full customization and error handling capabilities and a Postman Collection.

> **⚠️ Demo Application Notice**: This is a demonstration application with **no client-side validation** - all parameters are passed directly to the Adyen API to showcase API error handling and response behavior. In production applications, implement proper input validation and sanitization before making API calls.

## 🚀 Features

- **Payment Authorization**: Authorize and tokenize payment methods with custom amounts
- **Payment Capture**: Partial or full capture of authorized payments  
- **Payment Refund**: Refund captured payments with flexible amounts
- **Recurring Payments**: Use stored payment tokens for recurring transactions
- **Comprehensive Logging**: Detailed console and server-side logging with API request/response tracking
- **Environment Configuration**: Secure credential management via environment variables
- **Customizable Parameters**: Full control over card details, amounts, and payment data
- **API Error Handling**: Direct API error responses with retry functionality (no client validation)
- **Interactive Testing**: Real-time parameter adjustment and error scenario testing

## 📋 Prerequisites

- **Python 3.7+**
- **jq** (for shell script JSON parsing)
- **Adyen Test Account** with API credentials

### Installing Dependencies

**macOS:**
```bash
brew install jq
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq
```

## ⚙️ Setup

### 1. Clone and Navigate
```bash
git clone <repository-url>
cd adyen_demo
```

### 2. Environment Configuration
```bash
# Copy the example environment file
cp .env.example .env

# Edit .env with your Adyen credentials
nano .env  # or your preferred editor
```

**Required environment variables:**
```bash
# Merchant Configuration
ADYEN_MERCHANT_ACCOUNT=your_merchant_account_here

# API Authentication
ADYEN_API_KEY=your_api_key_here

# API Endpoints
ADYEN_PAYMENTS_ENDPOINT=https://checkout-test.adyen.com
ADYEN_MANAGEMENT_ENDPOINT=https://management-test.adyen.com

# Optional: Web Service User (for Management API)
ADYEN_WS_USER=your_web_service_user_here
ADYEN_WS_PASSWORD=your_web_service_password_here

# Environment
ADYEN_ENVIRONMENT=test
```

### 3. Python Virtual Environment
```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## 🌐 Web Application

### Running the Flask App
```bash
# Ensure virtual environment is activated
source venv/bin/activate

# Start the Flask application
python app.py
```

The application will start on **http://localhost:8000**

### Using the Web Interface

1. **Open your browser** and navigate to `http://localhost:8000`
2. **Customize parameters** (or use defaults):
   - **Cardholder Name**: Your name for reference generation
   - **Authorization Amount**: Amount to authorize (in minor units)
   - **Card Details**: Number, CVC, expiry month/year
   - **Capture Amount**: Amount to capture from authorized payment
   - **Refund Amount**: Amount to refund from captured payment
   - **Recurring Amount**: Amount for recurring payment with stored token

3. **Follow the 4-step process:**
   - **Step 1**: Click "Authorize Payment" (creates payment + token)
   - **Step 2**: Click "Capture Funds" (captures specified amount)
   - **Step 3**: Click "Refund Money" (refunds specified amount)
   - **Step 4**: Click "Pay with Stored Token" (recurring payment)

### Web App Features
- **Real-time feedback**: See API responses immediately
- **Parameter customization**: Modify any payment parameter
- **Input validation**: Client and server-side validation with error messages
- **Visual progress**: Buttons enable/disable based on flow
- **Console logging**: Open browser console (F12) for detailed logs
- **Error handling**: Clear error messages with retry suggestions

## 🖥️ Shell Script

### Running the Command-Line Script
```bash
# Make script executable (first time only)
chmod +x test_adyen_api.sh

# Run the interactive payment flow
./test_adyen_api.sh
```

### Shell Script Features
- **Interactive parameter input**: Customize all payment parameters or use defaults
- **Full request preview**: Shows exact curl commands before execution
- **User confirmation**: Press Enter to proceed with each API call
- **Automatic retry logic**: Retry failed operations with user confirmation
- **Variable extraction**: Automatically parses and stores API responses
- **Error handling**: Detailed error messages with retry options
- **Summary report**: Complete transaction overview at the end

### Example Output
```
==========================================
ADYEN API PAYMENT FLOW TEST
==========================================
Environment: test
Merchant Account: AdyenRecruitmentCOM
Payments Endpoint: https://checkout-test.adyen.com

PARAMETER CUSTOMIZATION
=======================
Press Enter to use default values, or type new values to customize:

Cardholder Name [John Smith]: 
Authorization Amount (minor units) [10000]: 15000
Card Number [4111111111111111]: 
CVC [737]: 
Expiry Month (MM) [03]: 
Expiry Year (YYYY) [2030]: 
Capture Amount (minor units) [5000]: 7500
Refund Amount (minor units) [5000]: 3000
Recurring Amount (minor units) [5000]: 

Using Parameters:
  Cardholder: John Smith
  Auth Amount: 15000 (150.00 EUR)
  Card: 4111****
  CVC: 737
  Expiry: 03/2030
  Capture Amount: 7500 (75.00 EUR)
  Refund Amount: 3000 (30.00 EUR)
  Recurring Amount: 5000 (50.00 EUR)

STEP 1: AUTHORIZE PAYMENT (150.00 EUR) AND TOKENIZE CARD
======================================================
About to send the following request:
[Full curl command shown]

Press Enter to send this request (or Ctrl+C to cancel)...
Response: {"additionalData":{"recurring.recurringDetailReference":"..."}...}
✅ Step 1 Complete: Authorization successful

[... continues through all 4 steps with retry options ...]
```

## 🧪 Test Card Details

### Default Test Card (Successful)
- **Card Number**: `4111111111111111`
- **CVV**: `737`
- **Expiry**: `03/30`
- **Name**: Any name (configurable)

### Error Testing Cards
Test different error scenarios by using these cards:
- **Insufficient Funds**: `4000000000000002`
- **Invalid Card**: `4000000000000101` 
- **Expired Card**: Use any past expiry date
- **Invalid CVC**: Use `000` or wrong length
- **Invalid Amount**: Try amounts > authorized amount for capture/refund

### Amount Testing
- **Authorization**: Any amount (default 10000 = 100.00 EUR)
- **Capture**: Must be ≤ authorization amount  
- **Refund**: Must be ≤ captured amount
- **Recurring**: Any amount (independent)

## 📊 API Testing with Postman

### Direct Adyen API Collection

**File**: `Adyen_Direct_API.postman_collection.json`

**🚀 Ready to Use - No Setup Required:**
1. **Import Collection**: Import the collection into Postman
2. **Run Sequential Flow**: Execute requests in order: Authorize → Capture → Refund → Recurring
3. **Demo credentials pre-configured** - start testing immediately!

**✨ Collection Features:**
- **Direct API calls**: Calls Adyen's API endpoints directly (bypasses any middleware)
- **Demo credentials included**: API key and merchant account pre-configured
- **Auto-populated variables**: PSP references and tokens automatically extracted between requests
- **Real Adyen responses**: See actual API responses, error codes, and validation behavior
- **Comprehensive logging**: Detailed console output for each step with success/error details
- **Error scenario testing**: Perfect for testing edge cases and API validation
- **No client validation**: Showcases pure Adyen API behavior and error handling

**📝 Pre-configured Demo Setup:**
- **API Endpoint**: `https://checkout-test.adyen.com` (Adyen test environment)
- **Merchant Account**: `AdyenRecruitmentCOM` (demo account)
- **Test Credentials**: Fully functional demo API key included

### Individual Endpoint Testing

**Base URL**: `http://localhost:8000` (Flask app must be running)

#### 1. Authorization
```http
POST /api/authorize
Content-Type: application/json

{
    "fullName": "John Smith",
    "authAmount": 10000,
    "cardNumber": "4111111111111111",
    "cvc": "737",
    "expiryMonth": "03",
    "expiryYear": "2030"
}
```

#### 2. Capture
```http
POST /api/capture
Content-Type: application/json

{
    "pspReference": "YOUR_PSP_REFERENCE",
    "reference": "YOUR_REFERENCE",
    "captureAmount": 5000
}
```

#### 3. Refund
```http
POST /api/refund
Content-Type: application/json

{
    "pspReference": "YOUR_PSP_REFERENCE", 
    "reference": "YOUR_REFERENCE",
    "refundAmount": 5000
}
```

#### 4. Recurring Payment
```http
POST /api/recurring
Content-Type: application/json

{
    "recurringDetailReference": "YOUR_RECURRING_DETAIL_REFERENCE",
    "shopperReference": "YOUR_SHOPPER_REFERENCE",
    "reference": "YOUR_REFERENCE",
    "recurringAmount": 5000
}
```

## 📁 Project Structure

```
adyen_demo/
├── app.py                                   # Flask application
├── test_adyen_api.sh                       # Shell script for command-line testing
├── Adyen_Direct_API.postman_collection.json # Postman collection for direct API testing
├── requirements.txt                        # Python dependencies
├── .env                                    # Environment variables (your credentials)
├── .env.example                            # Environment template
├── .gitignore                              # Git ignore rules
├── templates/
│   └── index.html                          # Web interface
├── static/
│   ├── script.js                           # Frontend JavaScript with logging
│   └── styles.css                          # Styling (black/white/grey theme)
└── README.md                               # This file
```

## 🔍 Debugging

### Flask App Logging
- **Server logs**: Check terminal where Flask is running
- **Browser logs**: Open Developer Tools → Console (F12)
- **API requests**: Full request/response logging in server terminal

### Shell Script Debugging
- **Verbose output**: All API requests and responses shown
- **Error messages**: Clear validation and error reporting
- **JSON parsing**: Requires `jq` - install if missing

### Common Issues

1. **Missing environment variables**:
   ```
   ❌ Missing required environment variables: ADYEN_API_KEY
   ```
   **Solution**: Check your `.env` file has all required variables

2. **jq not found** (shell script):
   ```
   ❌ jq is required for JSON parsing but not installed
   ```
   **Solution**: Install jq using `brew install jq` or `apt-get install jq`

3. **Port 5000 in use** (Flask):
   **Solution**: App runs on port 8000 by default, or change port in `app.py`

4. **Authorization fails**:
   **Solution**: Verify API key and merchant account in `.env`


## 🚀 Production Deployment

For production the following changes need to be made at minimum:
1. **Update endpoints** to live Adyen URLs
2. **Use production credentials** in environment variables
3. **Implement HTTPS** for all communications
4. **Add authentication** to protect API endpoints
5. **Use proper logging** and monitoring
6. **Follow PCI compliance** requirements

## 📞 Support

- **Adyen Documentation**: https://docs.adyen.com/
- **Test Cards**: https://docs.adyen.com/development-resources/test-cards/
- **API Reference**: https://docs.adyen.com/api-explorer/

## 📄 License

This project is for demonstration purposes only. 
