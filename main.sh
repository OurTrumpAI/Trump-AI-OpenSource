set -e  # Exit on any error
# penutai

# Load the tweet prompt template
export TWEET_PROMPT_TEMPLATE=$(curl -s $TWEET_PROMPT_TEMPLATE_URL)

# Set the passwords for ProtonMail and Twitter
export PROTONMAIL_PASSWORD=$(python3 scripts/protonmail.py)
export TWITTER_PASSWORD=$(python3 scripts/twitter.py)

# Encode Twitter account data as hex and set it as report data
PAYLOAD="{\"report_data\": \"$(echo -n $TWITTER_ACCOUNT | od -A n -t x1 | tr -d ' \n')\"}"
curl -X POST --unix-socket /var/run/tappd.sock -d "$PAYLOAD" http://localhost/prpc/Tappd.TdxQuote?json | jq .

# Start the OAuth client to receive the callback
pushd client
RUST_LOG=info cargo run --release --bin helper &
SERVER=$!
popd

# Perform the Twitter login and set authorization tokens
python3 scripts/tee.py
. cookies.env
export X_AUTH_TOKENS
wait $SERVER

# Start the time-release server in the background
bash timerelease.sh &

# Update environment variables with new access tokens
. client/updated.env
export X_ACCESS_TOKEN X_ACCESS_TOKEN_SECRET

# Run helper and agent processes
pushd client
RUST_LOG=info cargo run --release --bin helper &
popd

pushd agent
python3 run_pipeline.py
popd
