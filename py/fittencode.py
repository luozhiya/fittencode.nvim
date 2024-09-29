import requests

# The URL to which you are sending the POST request
url = 'https://fc.fittenlab.cn//codeapi/chat'

# The JSON payload - data sent in the POST request
json_data = {
    'username': 'your_username',
    'password': 'your_password'
}

# Custom headers, including an Authorization token and Content-Type
headers = {
    'Authorization': 'Bearer your_api_token',
    'Content-Type': 'application/json',
    'Accept': 'application/json'
}

# Sending the POST request
try:
    response = requests.post(url, json=json_data, headers=headers)

    # Check the HTTP Status code: 200 means success
    if response.status_code == 200:
        # Parse the response JSON content
        response_data = response.json()

        # Print and inspect the response data
        print(f"Success! Received response data:\n{response_data}")
    else:
        # Handle non-success responses
        print(f"Request failed with status code: {response.status_code}")
        print(f"Response text:\n{response.text}")

except requests.RequestException as e:
    # Handle exceptions such as network problems, invalid response formats, etc.
    print(f"An error occurred: {e}")
