"""Extract certificate identity; callers must also run apksigner verify."""
import re


def certificate_sha256(output: str) -> str:
    """Accept legacy and scheme-labelled output, requiring one identity."""
    identities = {
        digest.lower() for digest in re.findall(
            r'(?m)^\s*(?:Signer #\d+|V[1-4](?:\.\d+)? Signer):? certificate SHA-256 digest:\s*([a-fA-F0-9]{64})(?![a-fA-F0-9])',
            output,
        )
    }
    counts = re.findall(r'Number of signers:\s*(\d+)', output)
    if len(identities) != 1 or any(int(count) != 1 for count in counts):
        raise ValueError('Expected one certificate identity in apksigner output')
    return identities.pop()
