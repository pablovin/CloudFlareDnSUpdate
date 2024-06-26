#!/bin/bash

CONFIG_FILE="$HOME/.cloudflare_config"

# Function to load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        # After loading configuration, directly check and update the DNS record
        update_if_necessary
    else
        echo "No configuration file found, initializing setup."
        setup_config
    fi
}

# Function to set up initial configuration and DNS record
setup_config() {
    read -p "Enter your Cloudflare API Key: " API_KEY
    read -p "Enter your Cloudflare Email Address: " EMAIL
    read -p "Enter your Cloudflare Zone ID: " ZONE_ID
    read -p "Enter the DNS Record Name you want to check or create (e.g., example.com): " RECORD_NAME

    # Save the initial configuration to a file
    echo "API_KEY='$API_KEY'" > "$CONFIG_FILE"
    echo "EMAIL='$EMAIL'" >> "$CONFIG_FILE"
    echo "ZONE_ID='$ZONE_ID'" >> "$CONFIG_FILE"
    echo "RECORD_NAME='$RECORD_NAME'" >> "$CONFIG_FILE"

    # Check if the DNS record exists or needs to be created
    check_and_create_record
}

# Function to check if the DNS record exists and create if it does not
check_and_create_record() {
    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
	--header "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')
    echo "RECORD ID: $RECORD_ID"
    
    if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
        echo "Record does not exist, please first create a record..."
    else
        echo "Record already exists with ID: $RECORD_ID"
        echo "RECORD_ID='$RECORD_ID'" >> "$CONFIG_FILE"
        update_if_necessary
    fi
}


# Function to update the DNS record if the public IP has changed
update_if_necessary() {
    RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
        --header "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')
    CURRENT_IP=$(echo "$RESPONSE" | jq -r '.result[0].content')

#    CURRENT_IP=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
 #       -H "X-Auth-Email: $EMAIL" \
  #      -H "X-Auth-Key: $API_KEY" \
   #     -H "Content-Type: application/json" | jq -r '.result.content')

    PUBLIC_IP=$(curl -s -4 icanhazip.com)

    if [[ "$PUBLIC_IP" != "$CURRENT_IP" ]]; then
        echo "Updating record $RECORD_ID to new IP: $PUBLIC_IP"

        #curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        #     -H "X-Auth-Email: $EMAIL" \
        #     -H "X-Auth-Key: $API_KEY" \
        #     -H "Content-Type: application/json" \
        #     --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$PUBLIC_IP\",\"ttl\":3600,\"proxied\":false}" | jq -r '.success'


#curl -s --request PATCH --url "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
#--header 'Content-Type: application/json' \
#--header "Authorization: Bearer $API_KEY" \
#--data '{ "content": "1.1.1.1", "name": "$RECORD_NAME", "ttl": 0}'

curl -s --request PATCH --url "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
--header 'Content-Type: application/json' \
--header "Authorization: Bearer $API_KEY" \
--data "{ \"content\": \"$PUBLIC_IP\", \"name\": \"$RECORD_NAME\", \"ttl\": 0}"

    else
        echo "No update needed. Current IP matches Public IP."
    fi
}

# Start the script by loading the configuration or setting up if it's the first run
load_config
