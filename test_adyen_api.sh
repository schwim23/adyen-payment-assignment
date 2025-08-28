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

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local input
    
    read -p "${prompt} [${default}]: " input
    if [ -z "$input" ]; then
        echo "$default"
    else
        echo "$input"
    fi
}

# Function to show request and get confirmation
show_request_and_confirm() {
    local step_name="$1"
    local method="$2"
    local url="$3"
    local payload="$4"
    
    echo ""
    echo "About to send ${step_name}:"
    echo ""
    echo "curl -X ${method} \"${url}\" \\"
    echo "  -H \"Content-Type: application/json\" \\"
    echo "  -H \"X-API-Key: ${API_KEY:0:10}...${API_KEY: -10}\" \\"
    echo "  -d '${payload}'"
    echo ""
    read -p "Press Enter to send this request (or Ctrl+C to cancel)..."
}

# Function to make API request and handle errors
make_api_request() {
    local method="$1"
    local url="$2" 
    local payload="$3"
    
    curl -s -X "${method}" "${url}" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: ${API_KEY}" \
        -d "${payload}"
}

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
echo "STEP 1: AUTHORIZE PAYMENT AND TOKENIZE CARD"
echo "=========================================="

# Get authorization parameters
while true; do
    echo "Enter authorization parameters:"
    CARDHOLDER_NAME=$(get_input "Cardholder Name" "John Smith")
    AUTH_AMOUNT=$(get_input "Authorization Amount (minor units, e.g. 10000 = 100.00 EUR)" "10000")
    CARD_NUMBER=$(get_input "Card Number" "4111111111111111")
    CVC=$(get_input "CVC" "737")
    EXPIRY_MONTH=$(get_input "Expiry Month (MM)" "03")
    EXPIRY_YEAR=$(get_input "Expiry Year (YYYY)" "2030")
    
    # Build authorization payload
    AUTH_PAYLOAD=$(cat <<EOF
{
  "amount": {
    "currency": "EUR",
    "value": ${AUTH_AMOUNT}
  },
  "reference": "${REFERENCE}",
  "paymentMethod": {
    "type": "scheme",
    "number": "${CARD_NUMBER}",
    "expiryMonth": "${EXPIRY_MONTH}",
    "expiryYear": "${EXPIRY_YEAR}",
    "cvc": "${CVC}",
    "holderName": "${CARDHOLDER_NAME}"
  },
  "merchantAccount": "${MERCHANT_ACCOUNT}",
  "captureDelayHours": 0,
  "storePaymentMethod": true,
  "shopperReference": "${SHOPPER_REFERENCE}",
  "shopperInteraction": "Ecommerce",
  "recurringProcessingModel": "CardOnFile"
}
EOF
)

    show_request_and_confirm "authorization request" "POST" "${BASE_URL}/v71/payments" "${AUTH_PAYLOAD}"
    
    AUTH_RESPONSE=$(make_api_request "POST" "${BASE_URL}/v71/payments" "${AUTH_PAYLOAD}")
    
    echo "📋 ADYEN API RESPONSE:"
    echo "====================="
    echo "${AUTH_RESPONSE}" | jq '.'
    echo ""
    
    # Check if authorization was successful
    RESULT_CODE=$(echo ${AUTH_RESPONSE} | jq -r '.resultCode')
    if [ "${RESULT_CODE}" = "Authorised" ]; then
        echo "✅ Step 1 Complete: Authorization successful"
        break
    else
        echo "❌ Authorization failed with result: ${RESULT_CODE}"
        ERROR_MESSAGE=$(echo ${AUTH_RESPONSE} | jq -r '.message // "Unknown error"')
        REFUSAL_REASON=$(echo ${AUTH_RESPONSE} | jq -r '.refusalReason // ""')
        echo "Error: ${ERROR_MESSAGE}"
        if [ -n "${REFUSAL_REASON}" ] && [ "${REFUSAL_REASON}" != "null" ]; then
            echo "Refusal Reason: ${REFUSAL_REASON}"
        fi
        echo ""
        read -p "Would you like to retry with different parameters? (y/n): " retry_choice
        if [ "$retry_choice" != "y" ] && [ "$retry_choice" != "Y" ]; then
            echo "Exiting due to authorization failure."
            exit 1
        fi
        echo "Please enter different parameters:"
    fi
done

# Extract values from authorization response
PSP_REFERENCE=$(echo ${AUTH_RESPONSE} | jq -r '.pspReference')
RECURRING_DETAIL_REFERENCE=$(echo ${AUTH_RESPONSE} | jq -r '.additionalData."recurring.recurringDetailReference" // .pspReference')

echo "Extracted Data:"
echo "  PSP Reference: ${PSP_REFERENCE}"
echo "  Recurring Detail Reference: ${RECURRING_DETAIL_REFERENCE}"
echo ""

# Step 2: Capture Payment
echo "STEP 2: CAPTURE PAYMENT"
echo "======================"

while true; do
    CAPTURE_AMOUNT=$(get_input "Capture Amount (minor units, e.g. 5000 = 50.00 EUR)" "5000")
    
    # Build capture payload
    CAPTURE_PAYLOAD=$(cat <<EOF
{
  "amount": {
    "currency": "EUR",
    "value": ${CAPTURE_AMOUNT}
  },
  "reference": "${REFERENCE}_capture",
  "merchantAccount": "${MERCHANT_ACCOUNT}"
}
EOF
)

    show_request_and_confirm "capture request" "POST" "${BASE_URL}/v71/payments/${PSP_REFERENCE}/captures" "${CAPTURE_PAYLOAD}"
    
    CAPTURE_RESPONSE=$(make_api_request "POST" "${BASE_URL}/v71/payments/${PSP_REFERENCE}/captures" "${CAPTURE_PAYLOAD}")
    
    echo "📋 ADYEN API RESPONSE:"
    echo "====================="
    echo "${CAPTURE_RESPONSE}" | jq '.'
    echo ""
    
    # Check if capture was successful
    CAPTURE_STATUS=$(echo ${CAPTURE_RESPONSE} | jq -r '.status')
    if [ "${CAPTURE_STATUS}" = "received" ]; then
        echo "✅ Step 2 Complete: Capture successful"
        CAPTURE_REFERENCE=$(echo ${CAPTURE_RESPONSE} | jq -r '.pspReference')
        echo "  Capture Reference: ${CAPTURE_REFERENCE}"
        break
    else
        echo "❌ Capture failed with status: ${CAPTURE_STATUS}"
        CAPTURE_ERROR=$(echo ${CAPTURE_RESPONSE} | jq -r '.message // "Unknown error"')
        ERROR_CODE=$(echo ${CAPTURE_RESPONSE} | jq -r '.errorCode // ""')
        echo "Error: ${CAPTURE_ERROR}"
        if [ -n "${ERROR_CODE}" ] && [ "${ERROR_CODE}" != "null" ]; then
            echo "Error Code: ${ERROR_CODE}"
        fi
        echo ""
        read -p "Would you like to retry with a different amount? (y/n): " retry_choice
        if [ "$retry_choice" != "y" ] && [ "$retry_choice" != "Y" ]; then
            echo "Skipping capture step."
            break
        fi
        echo "Please enter a different capture amount:"
    fi
done
echo ""

# Step 3: Refund Payment
echo "STEP 3: REFUND PAYMENT"
echo "====================="

while true; do
    REFUND_AMOUNT=$(get_input "Refund Amount (minor units, e.g. 5000 = 50.00 EUR)" "5000")
    
    # Build refund payload
    REFUND_PAYLOAD=$(cat <<EOF
{
  "amount": {
    "currency": "EUR",
    "value": ${REFUND_AMOUNT}
  },
  "reference": "${REFERENCE}_refund",
  "merchantAccount": "${MERCHANT_ACCOUNT}"
}
EOF
)

    show_request_and_confirm "refund request" "POST" "${BASE_URL}/v71/payments/${PSP_REFERENCE}/refunds" "${REFUND_PAYLOAD}"
    
    REFUND_RESPONSE=$(make_api_request "POST" "${BASE_URL}/v71/payments/${PSP_REFERENCE}/refunds" "${REFUND_PAYLOAD}")
    
    echo "📋 ADYEN API RESPONSE:"
    echo "====================="
    echo "${REFUND_RESPONSE}" | jq '.'
    echo ""
    
    # Check if refund was successful
    REFUND_STATUS=$(echo ${REFUND_RESPONSE} | jq -r '.status')
    if [ "${REFUND_STATUS}" = "received" ]; then
        echo "✅ Step 3 Complete: Refund successful"
        REFUND_REFERENCE=$(echo ${REFUND_RESPONSE} | jq -r '.pspReference')
        echo "  Refund Reference: ${REFUND_REFERENCE}"
        break
    else
        echo "❌ Refund failed with status: ${REFUND_STATUS}"
        REFUND_ERROR=$(echo ${REFUND_RESPONSE} | jq -r '.message // "Unknown error"')
        ERROR_CODE=$(echo ${REFUND_RESPONSE} | jq -r '.errorCode // ""')
        echo "Error: ${REFUND_ERROR}"
        if [ -n "${ERROR_CODE}" ] && [ "${ERROR_CODE}" != "null" ]; then
            echo "Error Code: ${ERROR_CODE}"
        fi
        echo ""
        read -p "Would you like to retry with a different amount? (y/n): " retry_choice
        if [ "$retry_choice" != "y" ] && [ "$retry_choice" != "Y" ]; then
            echo "Skipping refund step."
            break
        fi
        echo "Please enter a different refund amount:"
    fi
done
echo ""

# Step 4: Recurring Payment
echo "STEP 4: RECURRING PAYMENT USING STORED TOKEN"
echo "============================================="

while true; do
    RECURRING_AMOUNT=$(get_input "Recurring Payment Amount (minor units, e.g. 5000 = 50.00 EUR)" "5000")
    
    # Build recurring payment payload
    RECURRING_PAYLOAD=$(cat <<EOF
{
  "amount": {
    "currency": "EUR",
    "value": ${RECURRING_AMOUNT}
  },
  "reference": "${REFERENCE}",
  "paymentMethod": {
    "type": "scheme",
    "recurringDetailReference": "${RECURRING_DETAIL_REFERENCE}"
  },
  "merchantAccount": "${MERCHANT_ACCOUNT}",
  "shopperReference": "${SHOPPER_REFERENCE}",
  "shopperInteraction": "ContAuth",
  "recurringProcessingModel": "Subscription"
}
EOF
)

    show_request_and_confirm "recurring payment request" "POST" "${BASE_URL}/v71/payments" "${RECURRING_PAYLOAD}"
    
    RECURRING_RESPONSE=$(make_api_request "POST" "${BASE_URL}/v71/payments" "${RECURRING_PAYLOAD}")
    
    echo "📋 ADYEN API RESPONSE:"
    echo "====================="
    sleep 3
    echo "${RECURRING_RESPONSE}" | jq '.'
    echo ""
    
    # Check if recurring payment was successful
    RECURRING_RESULT=$(echo ${RECURRING_RESPONSE} | jq -r '.resultCode')
    if [ "${RECURRING_RESULT}" = "Authorised" ]; then
        RECURRING_PSP_REFERENCE=$(echo ${RECURRING_RESPONSE} | jq -r '.pspReference')
        echo "✅ Step 4 Complete: Recurring payment successful"
        echo "  Recurring Payment Reference: ${RECURRING_PSP_REFERENCE}"
        echo ""
        echo "🎉 All payment flow steps completed successfully!"
        break
    else
        echo "❌ Recurring payment failed with result: ${RECURRING_RESULT}"
        RECURRING_ERROR=$(echo ${RECURRING_RESPONSE} | jq -r '.message // "Unknown error"')
        REFUSAL_REASON=$(echo ${RECURRING_RESPONSE} | jq -r '.refusalReason // ""')
        echo "Error: ${RECURRING_ERROR}"
        if [ -n "${REFUSAL_REASON}" ] && [ "${REFUSAL_REASON}" != "null" ]; then
            echo "Refusal Reason: ${REFUSAL_REASON}"
        fi
        echo ""
        read -p "Would you like to retry with a different amount? (y/n): " retry_choice
        if [ "$retry_choice" != "y" ] && [ "$retry_choice" != "Y" ]; then
            echo "Skipping recurring payment step."
            break
        fi
        echo "Please enter a different recurring payment amount:"
    fi
done

echo ""
echo "=========================================="
echo "SUMMARY"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "Merchant Account: ${MERCHANT_ACCOUNT}"
echo "Original Reference: ${REFERENCE}"
echo "Authorization PSP Reference: ${PSP_REFERENCE}"
echo "Recurring Detail Reference: ${RECURRING_DETAIL_REFERENCE}"
echo "Capture Reference: ${CAPTURE_REFERENCE:-N/A}"
echo "Refund Reference: ${REFUND_REFERENCE:-N/A}"
echo "Recurring Payment Reference: ${RECURRING_PSP_REFERENCE:-N/A}"
echo ""
echo "Payment flow complete!"
