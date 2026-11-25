import base64

TOKEN_FILE = '/var/run/secrets/tokens/bridge-token'
DEFAULT_TOKEN_DIRECTORY = '/var/run/secrets/kubernetes.io/serviceaccount'


def relay_pod():
    """The one live relay Pod after its rollout."""
    pods = json.loads(kubectl('-n', NAMESPACE, 'get', 'pods', '-l', 'app=relay', '-o', 'json'))['items']
    pods = [pod for pod in pods if not pod['metadata'].get('deletionTimestamp')]
    assert len(pods) == 1, 'Exactly one relay Pod must remain after the rollout'
    assert pods[0]['spec'].get('serviceAccountName') == 'relay', 'The relay Pod must keep the ServiceAccount relay'
    return pods[0]


def in_pod(pod, script):
    return kubectl('-n', NAMESPACE, 'exec', pod['metadata']['name'], '--', 'sh', '-c', script)


def token_claims(token):
    """The payload of a JSON Web Token (JWT): the middle part, base64url encoded."""
    parts = token.strip().split('.')
    assert len(parts) == 3, 'The file at ' + TOKEN_FILE + ' must hold a JWT'
    payload = parts[1] + '=' * (-len(parts[1]) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


if wants('projected-token-mounted'):
    pod = relay_pod()
    token = in_pod(pod, 'cat ' + TOKEN_FILE + ' 2>/dev/null || true')
    assert token.strip(), 'Mount a projected ServiceAccount token at ' + TOKEN_FILE
    claims = token_claims(token)
    audience = claims.get('aud')
    audience = audience if isinstance(audience, list) else [audience]
    assert audience == ['bridge-api'], 'The token audience must be exactly bridge-api'
    assert claims['exp'] - claims['iat'] == 600, 'The token must live 600 seconds'
    assert claims.get('kubernetes.io', {}).get('serviceaccount', {}).get('name') == 'relay', 'The token must belong to relay'
if wants('default-token-absent'):
    pod = relay_pod()
    listing = in_pod(pod, 'ls ' + DEFAULT_TOKEN_DIRECTORY + ' 2>/dev/null || echo absent')
    assert listing == 'absent', 'The relay Pod must not mount the default ServiceAccount token'
