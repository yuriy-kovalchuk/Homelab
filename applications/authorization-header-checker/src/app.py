from flask import Flask, request, jsonify
import os
import yaml
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load group configuration from ConfigMap or environment
def load_group_config():
    config_path = os.getenv('CONFIG_PATH', '/config/config.yaml')
    try:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        logger.warning(f"Config file not found at {config_path}, using empty config")
        return {'apps': {}}

GROUP_CONFIG = load_group_config()
GROUP_HEADER_NAME = GROUP_CONFIG.get('groups_header_name', "X-Auth-Request-Groups")
GROUP_USER_NAME = GROUP_CONFIG.get('user_header_name', "X-Auth-Request-Groups")


def parse_groups_header(header_value):
    """Parse the X-Auth-Request-Groups header"""
    if not header_value:
        return []
    # Groups might be comma-separated or space-separated
    # Adjust based on your oauth2-proxy configuration
    groups = [g.strip() for g in header_value.split(',')]
    return groups

def check_authorization(app_name, user_groups):
    """Check if user has required groups for the app"""
    app_config = GROUP_CONFIG.get('apps', {}).get(app_name)

    if not app_config:
        logger.warning(f"No configuration found for app: {app_name}")
        # Default behavior: deny if no config
        return False

    allowed_groups = app_config.get('allowed_groups', [])

    if not allowed_groups:
        # If no groups specified, allow all authenticated users
        return True

    # Check if user has at least one allowed group
    return any(group in allowed_groups for group in user_groups)

@app.route('/auth/<app_name>')
def authorize(app_name):
    """
    Authorization endpoint called by nginx ingress
    Returns 200 if authorized, 403 if not
    """
    # Get user groups from header set by oauth2-proxy
    groups_header = request.headers.get(GROUP_HEADER_NAME, '')
    email = request.headers.get(GROUP_USER_NAME, '')

    user_groups = parse_groups_header(groups_header)

    logger.info(f"Authorization check for app={app_name}, email={email}, groups={user_groups}")

    if check_authorization(app_name, user_groups):
        logger.info(f"Access granted for {email} to {app_name}")
        return '', 200
    else:
        logger.warning(f"Access denied for {email} to {app_name}")
        return jsonify({
            'error': 'Forbidden',
            'message': f'User does not have required groups for {app_name}'
        }), 403

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'}), 200


if __name__ == '__main__':
    # Run on port 8080
    logger.info(f"The following header will be used to check the user groups: {GROUP_HEADER_NAME}")
    logger.info(f"The following header will be used to check the user name: {GROUP_USER_NAME}")
    app.run(host='0.0.0.0', port=8080)