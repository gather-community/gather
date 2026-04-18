# Local development overrides for mailman-web.
# Mounted into the container via docker-compose.yml.

# Don't require email verification — the admin user is created automatically
# and no mail server is set up for local dev.
ACCOUNT_EMAIL_VERIFICATION = "none"
