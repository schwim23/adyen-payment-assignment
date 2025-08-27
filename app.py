from flask import Flask, render_template, request, jsonify
import requests
import json
import time
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)

# Adyen Configuration from environment variables
CONFIG = {
    'api_key': os.getenv('ADYEN_API_KEY'),
    'merchant_account': os.getenv('ADYEN_MERCHANT_ACCOUNT'),
    'base_url': os.getenv('ADYEN_PAYMENTS_ENDPOINT'),
    'ws_user': os.getenv('ADYEN_WS_USER'),
    'ws_password': os.getenv('ADYEN_WS_PASSWORD'),
    'environment': os.getenv('ADYEN_ENVIRONMENT', 'test')
}

# Validate required configuration
required_config = ['api_key', 'merchant_account', 'base_url']
missing_config = [key for key in required_config if not CONFIG.get(key)]

if missing_config:
    print(f"❌ Missing required environment variables: {', '.join(missing_config)}")
    print("Please check your .env file and ensure all required variables are set.")
    exit(1)

print(f"✅ Adyen configuration loaded:")
print(f"   Environment: {CONFIG['environment']}")
print(f"   Merchant Account: {CONFIG['merchant_account']}")
print(f"   Payments Endpoint: {CONFIG['base_url']}")
print(f"   API Key: {CONFIG['api_key'][:10]}...{CONFIG['api_key'][-10:] if len(CONFIG['api_key']) > 20 else '***'}")
print()

def make_adyen_request(endpoint, payload):
    """Make a request to Adyen API"""
    url = f"{CONFIG['base_url']}{endpoint}"
    headers = {
        'Content-Type': 'application/json',
        'X-API-Key': CONFIG['api_key']
    }
    
    # Log the exact HTTP request details
    print(f"\n{'='*60}")
    print(f"ADYEN API REQUEST")
    print(f"{'='*60}")
    print(f"URL: {url}")
    print(f"Method: POST")
    print(f"Headers:")
    for key, value in headers.items():
        if key == 'X-API-Key':
            # Mask the API key for security but show first/last few chars
            masked_key = value[:10] + "..." + value[-10:] if len(value) > 20 else "***MASKED***"
            print(f"  {key}: {masked_key}")
        else:
            print(f"  {key}: {value}")
    print(f"Request Body:")
    print(json.dumps(payload, indent=2))
    print(f"{'='*60}")
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        
        # Log the response
        print(f"ADYEN API RESPONSE")
        print(f"{'='*60}")
        print(f"Status Code: {response.status_code}")
        print(f"Response Headers:")
        for key, value in response.headers.items():
            print(f"  {key}: {value}")
        
        data = response.json()
        print(f"Response Body:")
        print(json.dumps(data, indent=2))
        print(f"{'='*60}\n")
        
        if not response.ok:
            return {'success': False, 'error': f"HTTP {response.status_code}: {data.get('message', 'Request failed')}"}
        
        return {'success': True, 'data': data}
    except Exception as e:
        print(f"ERROR: {str(e)}")
        print(f"{'='*60}\n")
        return {'success': False, 'error': str(e)}

@app.route('/')
def index():
    """Serve the main page"""
    return render_template('index.html')

@app.route('/api/authorize', methods=['POST'])
def authorize_payment():
    """Authorize payment and tokenize card"""
    data = request.get_json()
    
    full_name = data.get('fullName', '').strip()
    if not full_name:
        return jsonify({'success': False, 'error': 'Full name is required'}), 400
    
    # Generate reference
    timestamp = int(time.time() * 1000)
    reference = f"{full_name.replace(' ', '_')}_{timestamp}"
    
    payload = {
        'amount': {
            'currency': 'EUR',
            'value': 10000  # 100.00 EUR in minor units
        },
        'reference': reference,
        'paymentMethod': {
            'type': 'scheme',
            'number': '4111111111111111',
            'expiryMonth': '03',
            'expiryYear': '2030',
            'cvc': '737',
            'holderName': full_name
        },
        'merchantAccount': CONFIG['merchant_account'],
        'captureDelayHours': 0,  # Manual capture
        'storePaymentMethod': True,
        'shopperReference': f"shopper_{timestamp}",
        'shopperInteraction': 'Ecommerce',
        'recurringProcessingModel': 'CardOnFile'
    }
    
    result = make_adyen_request('/v71/payments', payload)
    
    # Add the reference and shopperReference to the response for frontend use
    if result['success']:
        result['data']['reference'] = reference
        result['data']['shopperReference'] = payload['shopperReference']
    
    return jsonify(result)

@app.route('/api/capture', methods=['POST'])
def capture_payment():
    """Capture authorized payment"""
    data = request.get_json()
    
    psp_reference = data.get('pspReference')
    reference = data.get('reference')
    
    if not psp_reference or not reference:
        return jsonify({'success': False, 'error': 'PSP reference and reference are required'}), 400
    
    payload = {
        'amount': {
            'currency': 'EUR',
            'value': 5000  # 50.00 EUR in minor units
        },
        'reference': f"{reference}_capture",
        'merchantAccount': CONFIG['merchant_account']
    }
    
    result = make_adyen_request(f'/v71/payments/{psp_reference}/captures', payload)
    return jsonify(result)

@app.route('/api/refund', methods=['POST'])
def refund_payment():
    """Refund captured payment"""
    data = request.get_json()
    
    psp_reference = data.get('pspReference')
    reference = data.get('reference')
    
    if not psp_reference or not reference:
        return jsonify({'success': False, 'error': 'PSP reference and reference are required'}), 400
    
    payload = {
        'amount': {
            'currency': 'EUR',
            'value': 5000  # 50.00 EUR in minor units
        },
        'reference': f"{reference}_refund",
        'merchantAccount': CONFIG['merchant_account']
    }
    
    result = make_adyen_request(f'/v71/payments/{psp_reference}/refunds', payload)
    return jsonify(result)

@app.route('/api/recurring', methods=['POST'])
def recurring_payment():
    """Make recurring payment using stored token with same reference"""
    data = request.get_json()
    
    recurring_detail_reference = data.get('recurringDetailReference')
    shopper_reference = data.get('shopperReference')
    reference = data.get('reference')
    
    if not all([recurring_detail_reference, shopper_reference, reference]):
        return jsonify({'success': False, 'error': 'Recurring detail reference, shopper reference, and reference are required'}), 400
    
    # Use the stored payment method with the SAME reference as per Adyen instructions
    payload = {
        'amount': {
            'currency': 'EUR',
            'value': 5000  # 50.00 EUR in minor units
        },
        'reference': reference,  # Use the SAME reference from step 1
        'paymentMethod': {
            'type': 'scheme',
            'recurringDetailReference': recurring_detail_reference
        },
        'merchantAccount': CONFIG['merchant_account'],
        'shopperReference': shopper_reference,
        'shopperInteraction': 'ContAuth',
        'recurringProcessingModel': 'Subscription'
    }
    
    result = make_adyen_request('/v71/payments', payload)
    return jsonify(result)

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=8000)