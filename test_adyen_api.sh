#!/bin/bash

# Adyen API Testing Script
# This script demonstrates the complete payment flow: Authorize -> Capture -> Refund -> Recurring

# Load configuration from .env file
if [ -f .env ]; then
    echo "Loading configuration from .env file..."
    export $(grep -v '^#' .env | xargs)
else
    echo "❌ .env file not found. Please create one based on .env.example"
    exit 1
fi

# Validate required environment variables
required_vars=("ADYEN_API_KEY" "ADYEN_MERCHANT_ACCOUNT" "ADYEN_PAYMENTS_ENDPOINT")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    echo "❌ Missing required environment variables: ${missing_vars[*]}"
    echo "Please check your .env file and ensure all required variables are set."
    exit 1
fi

# Configuration from environment variables
API_KEY="${ADYEN_API_KEY}"
MERCHANT_ACCOUNT="${ADYEN_MERCHANT_ACCOUNT}"
BASE_URL="${ADYEN_PAYMENTS_ENDPOINT}"
ENVIRONMENT="${ADYEN_ENVIRONMENT:-test}"

# Generate unique identifiers
TIMESTAMP=$(date +%s%3N)
REFERENCE="Test_Payment_${TIMESTAMP}"
SHOPPER_REFERENCE="shopper_${TIMESTAMP}"

echo "=========================================="
echo "ADYEN API PAYMENT FLOW TEST"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Merchant Account: ${MERCHANT_ACCOUNT}"
echo "Payments Endpoint: ${BASE_URL}"
echo "API Key: ${API_KEY:0:10}...${API_KEY: -10}"
echo ""
echo "Reference: ${REFERENCE}"
echo "Shopper Reference: ${SHOPPER_REFERENCE}"
echo ""

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
    echo "❌ jq is required for JSON parsing but not installed."
    echo "Please install jq: brew install jq (on macOS) or apt-get install jq (on Ubuntu)"
    exit 1
fi

# Step 1: Authorize Payment and Tokenize Card
echo "STEP 1: AUTHORIZE PAYMENT (100 EUR) AND TOKENIZE CARD"
echo "======================================================"

echo "About to send the following request:"
echo ""
echo "curl -X POST \"${BASE_URL}/v71/payments\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-API-Key: ${API_KEY:0:10}...${API_KEY: -10}\" \\"
echo "  -d '{"
echo "    \"amount\": {"
echo "      \"currency\": \"EUR\","
echo "      \"value\": 10000"
echo "    },"
echo "    \"reference\": \"${REFERENCE}\","
echo "    \"paymentMethod\": {"
echo "      \"type\": \"scheme\","
echo "      \"number\": \"4111111111111111\","
echo "      \"expiryMonth\": \"03\","
echo "      \"expiryYear\": \"2030\","
echo "      \"cvc\": \"737\","
echo "      \"holderName\": \"John Smith\""
echo "    },"
echo "    \"merchantAccount\": \"${MERCHANT_ACCOUNT}\","
echo "    \"captureDelayHours\": 0,"
echo "    \"storePaymentMethod\": true,"
echo "    \"shopperReference\": \"${SHOPPER_REFERENCE}\","
echo "    \"shopperInteraction\": \"Ecommerce\","
echo "    \"recurringProcessingModel\": \"CardOnFile\""
echo "  }'"
echo ""
read -p "Press Enter to send this request (or Ctrl+C to cancel)..."

AUTH_RESPONSE=$(curl -s -X POST "${BASE_URL}/v71/payments" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${API_KEY}" \
  -d '{
    "amount": {
      "currency": "EUR",
      "value": 10000
    },
    "reference": "'${REFERENCE}'",
    "paymentMethod": {
      "type": "scheme",
      "number": "4111111111111111",
      "expiryMonth": "03",
      "expiryYear": "2030",
      "cvc": "737",
      "holderName": "John Smith"
    },
    "merchantAccount": "'${MERCHANT_ACCOUNT}'",
    "captureDelayHours": 0,
    "storePaymentMethod": true,
    "shopperReference": "'${SHOPPER_REFERENCE}'",
    "shopperInteraction": "Ecommerce",
    "recurringProcessingModel": "CardOnFile"
  }')

echo "Response: ${AUTH_RESPONSE}"
echo ""

# Extract values from authorization response
PSP_REFERENCE=$(echo ${AUTH_RESPONSE} | jq -r '.pspReference')
RECURRING_DETAIL_REFERENCE=$(echo ${AUTH_RESPONSE} | jq -r '.additionalData."recurring.recurringDetailReference" // .pspReference')

echo "Extracted Data:"
echo "  PSP Reference: ${PSP_REFERENCE}"
echo "  Recurring Detail Reference: ${RECURRING_DETAIL_REFERENCE}"
echo ""

# Check if authorization was successful
RESULT_CODE=$(echo ${AUTH_RESPONSE} | jq -r '.resultCode')
if [ "${RESULT_CODE}" != "Authorised" ]; then
    echo "❌ Authorization failed with result: ${RESULT_CODE}"
    ERROR_MESSAGE=$(echo ${AUTH_RESPONSE} | jq -r '.message // "Unknown error"')
    echo "Error: ${ERROR_MESSAGE}"
    exit 1
fi

echo "✅ Step 1 Complete: Authorization successful"
echo ""

# Step 2: Capture Payment
echo "STEP 2: CAPTURE PAYMENT (50 EUR)"
echo "================================="

echo "About to send the following request:"
echo ""
echo "curl -X POST \"${BASE_URL}/v71/payments/${PSP_REFERENCE}/captures\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-API-Key: ${API_KEY:0:10}...${API_KEY: -10}\" \\"
echo "  -d '{"
echo "    \"amount\": {"
echo "      \"currency\": \"EUR\","
echo "      \"value\": 5000"
echo "    },"
echo "    \"reference\": \"${REFERENCE}_capture\","
echo "    \"merchantAccount\": \"${MERCHANT_ACCOUNT}\""
echo "  }'"
echo ""
read -p "Press Enter to send this request (or Ctrl+C to cancel)..."

CAPTURE_RESPONSE=$(curl -s -X POST "${BASE_URL}/v71/payments/${PSP_REFERENCE}/captures" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${API_KEY}" \
  -d '{
    "amount": {
      "currency": "EUR",
      "value": 5000
    },
    "reference": "'${REFERENCE}'_capture",
    "merchantAccount": "'${MERCHANT_ACCOUNT}'"
  }')

echo "Response: ${CAPTURE_RESPONSE}"
echo ""

# Extract capture reference
CAPTURE_REFERENCE=$(echo ${CAPTURE_RESPONSE} | jq -r '.pspReference')

echo "Extracted Data:"
echo "  Capture Reference: ${CAPTURE_REFERENCE}"
echo ""

# Check if capture was successful
CAPTURE_STATUS=$(echo ${CAPTURE_RESPONSE} | jq -r '.status')
if [ "${CAPTURE_STATUS}" != "received" ]; then
    echo "❌ Capture failed with status: ${CAPTURE_STATUS}"
    CAPTURE_ERROR=$(echo ${CAPTURE_RESPONSE} | jq -r '.message // "Unknown error"')
    echo "Error: ${CAPTURE_ERROR}"
    echo "Continuing anyway..."
else
    echo "✅ Step 2 Complete: Capture successful"
fi
echo ""

# Step 3: Refund Payment
echo "STEP 3: REFUND PAYMENT (50 EUR)"
echo "==============================="

echo "About to send the following request:"
echo ""
echo "curl -X POST \"${BASE_URL}/v71/payments/${PSP_REFERENCE}/refunds\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-API-Key: ${API_KEY:0:10}...${API_KEY: -10}\" \\"
echo "  -d '{"
echo "    \"amount\": {"
echo "      \"currency\": \"EUR\","
echo "      \"value\": 5000"
echo "    },"
echo "    \"reference\": \"${REFERENCE}_refund\","
echo "    \"merchantAccount\": \"${MERCHANT_ACCOUNT}\""
echo "  }'"
echo ""
read -p "Press Enter to send this request (or Ctrl+C to cancel)..."

REFUND_RESPONSE=$(curl -s -X POST "${BASE_URL}/v71/payments/${PSP_REFERENCE}/refunds" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${API_KEY}" \
  -d '{
    "amount": {
      "currency": "EUR",
      "value": 5000
    },
    "reference": "'${REFERENCE}'_refund",
    "merchantAccount": "'${MERCHANT_ACCOUNT}'"
  }')

echo "Response: ${REFUND_RESPONSE}"
echo ""

# Extract refund reference
REFUND_REFERENCE=$(echo ${REFUND_RESPONSE} | jq -r '.pspReference')

echo "Extracted Data:"
echo "  Refund Reference: ${REFUND_REFERENCE}"
echo ""

# Check if refund was successful
REFUND_STATUS=$(echo ${REFUND_RESPONSE} | jq -r '.status')
if [ "${REFUND_STATUS}" != "received" ]; then
    echo "❌ Refund failed with status: ${REFUND_STATUS}"
    REFUND_ERROR=$(echo ${REFUND_RESPONSE} | jq -r '.message // "Unknown error"')
    echo "Error: ${REFUND_ERROR}"
    echo "Continuing anyway..."
else
    echo "✅ Step 3 Complete: Refund successful"
fi
echo ""

# Step 4: Recurring Payment
echo "STEP 4: RECURRING PAYMENT (50 EUR) USING STORED TOKEN"
echo "====================================================="

echo "About to send the following request:"
echo ""
echo "curl -X POST \"${BASE_URL}/v71/payments\" \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -H \"X-API-Key: ${API_KEY:0:10}...${API_KEY: -10}\" \\"
echo "  -d '{"
echo "    \"amount\": {"
echo "      \"currency\": \"EUR\","
echo "      \"value\": 5000"
echo "    },"
echo "    \"reference\": \"${REFERENCE}\","
echo "    \"paymentMethod\": {"
echo "      \"type\": \"scheme\","
echo "      \"recurringDetailReference\": \"${RECURRING_DETAIL_REFERENCE}\""
echo "    },"
echo "    \"merchantAccount\": \"${MERCHANT_ACCOUNT}\","
echo "    \"shopperReference\": \"${SHOPPER_REFERENCE}\","
echo "    \"shopperInteraction\": \"ContAuth\","
echo "    \"recurringProcessingModel\": \"Subscription\""
echo "  }'"
echo ""
read -p "Press Enter to send this request (or Ctrl+C to cancel)..."

RECURRING_RESPONSE=$(curl -s -X POST "${BASE_URL}/v71/payments" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: ${API_KEY}" \
  -d '{
    "amount": {
      "currency": "EUR",
      "value": 5000
    },
    "reference": "'${REFERENCE}'",
    "paymentMethod": {
      "type": "scheme",
      "recurringDetailReference": "'${RECURRING_DETAIL_REFERENCE}'"
    },
    "merchantAccount": "'${MERCHANT_ACCOUNT}'",
    "shopperReference": "'${SHOPPER_REFERENCE}'",
    "shopperInteraction": "ContAuth",
    "recurringProcessingModel": "Subscription"
  }')

echo "Response: ${RECURRING_RESPONSE}"
echo ""

# Extract recurring payment reference
RECURRING_PSP_REFERENCE=$(echo ${RECURRING_RESPONSE} | jq -r '.pspReference')

echo "Extracted Data:"
echo "  Recurring Payment Reference: ${RECURRING_PSP_REFERENCE}"
echo ""

# Check if recurring payment was successful
RECURRING_RESULT=$(echo ${RECURRING_RESPONSE} | jq -r '.resultCode')
if [ "${RECURRING_RESULT}" != "Authorised" ]; then
    echo "❌ Recurring payment failed with result: ${RECURRING_RESULT}"
    RECURRING_ERROR=$(echo ${RECURRING_RESPONSE} | jq -r '.message // "Unknown error"')
    echo "Error: ${RECURRING_ERROR}"
else
    echo "✅ Step 4 Complete: Recurring payment successful"
fi
echo ""

echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Merchant Account: ${MERCHANT_ACCOUNT}"
echo "Original Reference: ${REFERENCE}"
echo "Authorization PSP Reference: ${PSP_REFERENCE}"
echo "Recurring Detail Reference: ${RECURRING_DETAIL_REFERENCE}"
echo "Capture Reference: ${CAPTURE_REFERENCE}"
echo "Refund Reference: ${REFUND_REFERENCE}"
echo "Recurring Payment Reference: ${RECURRING_PSP_REFERENCE}"
echo ""
echo "Payment flow complete!"