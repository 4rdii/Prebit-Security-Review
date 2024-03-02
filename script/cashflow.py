import requests
import pandas as pd
from datetime import datetime

# Function to fetch ERC20 token transactions
def get_erc20_token_transactions(contract_address):
    # Replace 'YourApiKeyToken' with your actual BscScan API key
    url = f"https://api.bscscan.com/api?module=account&action=tokentx&address={contract_address}&startblock=0&endblock=99999999&sort=asc&apikey=YourApiKeyToken"
    response = requests.get(url)
    data = response.json()
    return data['result']

# Function to process transactions and update DataFrame
def update_df_with_erc20_transactions(df, transactions, contract_address):
    min_timestamp = float('inf')
    max_timestamp = float('-inf')
    for tx in transactions:
        # Ensure 'tx' is a dictionary before accessing its keys
        if isinstance(tx, dict):
            token_symbol = tx.get('tokenSymbol', 'Unknown')
            value = float(tx.get('value', 0)) / (10**18) # Convert from smallest unit to token unit
            timestamp = int(tx.get('timeStamp', 0)) # Extract the timestamp
            from_address = tx.get('from')
            to_address = tx.get('to')
            
            # Update min and max timestamps
            min_timestamp = min(min_timestamp, timestamp)
            max_timestamp = max(max_timestamp, timestamp)
            
            # Ensure addresses are in the same format for comparison
            from_address = from_address.lower()
            to_address = to_address.lower()
            contract_address = contract_address.lower()
            
            if token_symbol in df.index:
                if from_address == contract_address:
                    df.loc[token_symbol, 'From'] += value
                if to_address == contract_address:
                    df.loc[token_symbol, 'To'] += value
            else:
                df.loc[token_symbol] = {'From': 0, 'To': 0}
                if from_address == contract_address:
                    df.loc[token_symbol, 'From'] += value
                if to_address == contract_address:
                    df.loc[token_symbol, 'To'] += value
        else:
            print(f"Unexpected transaction data: {tx}")
    return df, min_timestamp, max_timestamp

# Initialize an empty DataFrame to store token transaction sums
df = pd.DataFrame(columns=['From', 'To'], dtype=float)

# Replace '0xYourContractAddressHere' with the actual contract address
contract_address = "0xb44a992c0886bc53267F727D8508890641Ac50d6"
transactions = get_erc20_token_transactions(contract_address)

# Update the DataFrame with the transaction sums for each ERC20 token
df, min_timestamp, max_timestamp = update_df_with_erc20_transactions(df, transactions, contract_address)

# Convert timestamps to datetime objects
min_datetime = datetime.utcfromtimestamp(min_timestamp).strftime('%Y-%m-%d %H:%M:%S')
max_datetime = datetime.utcfromtimestamp(max_timestamp).strftime('%Y-%m-%d %H:%M:%S')

# Print the updated DataFrame and the time period
print(df)
print(f"Time Period: From {min_datetime} to {max_datetime}")
