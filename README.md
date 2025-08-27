# Adyen Payment Flow Demo

A complete demonstration of Adyen's payment processing flow including authorization, capture, refund, and recurring payments. Available as both a Flask web application and a command-line shell script.

## 🚀 Features

- **Payment Authorization**: Authorize and tokenize payment methods (100 EUR)
- **Payment Capture**: Partial capture of authorized payments (50 EUR)
- **Payment Refund**: Refund captured payments (50 EUR)
- **Recurring Payments**: Use stored payment tokens for recurring transactions (50 EUR)
- **Comprehensive Logging**: Detailed console and server-side logging
- **Environment Configuration**: Secure credential management via environment variables

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
2. **Enter your name** in the "Full Name" field
3. **Follow the 4-step process:**
   - **Step 1**: Click "Authorize 100 EUR Payment" 
   - **Step 2**: Click "Capture 50 EUR" (enabled after step 1)
   - **Step 3**: Click "Refund 50 EUR" (enabled after step 2)
   - **Step 4**: Click "Pay 50 EUR with Token" (enabled after step 2)

### Web App Features
- **Real-time feedback**: See API responses immediately
- **Visual progress**: Buttons enable/disable based on flow
- **Console logging**: Open browser console (F12) for detailed logs
- **Error handling**: Clear error messages for debugging

## 🖥️ Shell Script

### Running the Command-Line Script
```bash
# Make script executable (first time only)
chmod +x test_adyen_api.sh

# Run the complete payment flow
./test_adyen_api.sh
```

### Shell Script Features
- **Automated flow**: Runs all 4 steps sequentially
- **Variable extraction**: Automatically parses and stores API responses
- **Error handling**: Validates each step before proceeding
- **Detailed logging**: Shows full requests and responses
- **Summary report**: Complete transaction overview at the end

### Example Output
```
==========================================
ADYEN API PAYMENT FLOW TEST
==========================================
Environment: test
Merchant Account: AdyenRecruitmentCOM
Payments Endpoint: https://checkout-test.adyen.com
API Key: AQEyhmfxLY...d)u9Lpt<ZD

STEP 1: AUTHORIZE PAYMENT (100 EUR) AND TOKENIZE CARD
======================================================
Response: {"additionalData":{"recurring.recurringDetailReference":"..."}...}
✅ Step 1 Complete: Authorization successful

[... continues through all 4 steps ...]

SUMMARY
==========================================
Authorization PSP Reference: ABC123XYZ789
Recurring Detail Reference: DEF456UVW012
Capture Reference: GHI789RST345
Refund Reference: JKL012EFG678
Recurring Payment Reference: MNO345QRS901
```

## 🧪 Test Card Details

The application uses Adyen's test card:
- **Card Number**: `4111111111111111`
- **CVV**: `737`
- **Expiry**: `03/30`
- **Name**: Any name (configurable in web app)

## 📊 API Testing with Postman

### Individual Endpoint Testing

**Base URL**: `http://localhost:8000` (Flask app must be running)

#### 1. Authorization
```http
POST /api/authorize
Content-Type: application/json

{
    "fullName": "John Smith"
}
```

#### 2. Capture
```http
POST /api/capture
Content-Type: application/json

{
    "pspReference": "YOUR_PSP_REFERENCE",
    "reference": "YOUR_REFERENCE"
}
```

#### 3. Refund
```http
POST /api/refund
Content-Type: application/json

{
    "pspReference": "YOUR_PSP_REFERENCE", 
    "reference": "YOUR_REFERENCE"
}
```

#### 4. Recurring Payment
```http
POST /api/recurring
Content-Type: application/json

{
    "recurringDetailReference": "YOUR_RECURRING_DETAIL_REFERENCE",
    "shopperReference": "YOUR_SHOPPER_REFERENCE",
    "reference": "YOUR_REFERENCE"
}
```

## 📁 Project Structure

```
adyen_demo/
├── app.py                  # Flask application
├── test_adyen_api.sh      # Shell script for command-line testing
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables (your credentials)
├── .env.example          # Environment template
├── .gitignore            # Git ignore rules
├── templates/
│   └── index.html        # Web interface
├── static/
│   ├── script.js         # Frontend JavaScript with logging
│   └── styles.css        # Styling (black/white/grey theme)
└── README.md             # This file
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

## 🔒 Security Notes

- **Never commit `.env`** - Contains sensitive credentials
- **Use test environment** - This demo uses Adyen's test endpoints
- **Rotate credentials** - Change API keys regularly
- **Environment separation** - Use different credentials for test/production

## 🚀 Production Deployment

For production use:
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

This project is for demonstration purposes only. Use in accordance with Adyen's terms of service.