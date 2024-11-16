from efipay import EfiPay
from app.core.config import settings

CREDENTIALS = {
    'client_id': settings.EFIPAY_CLIENT_ID,
    'client_secret': settings.EFIPAY_CLIENT_SECRET,
    # 'sandbox': settings.ENVIRONMENT == "production",
    'sandbox': False,
    'certificate': settings.EFIPAY_CERTIFICATE_PATH
}

efi = EfiPay(CREDENTIALS)

def create_immediate_charge(expiration: int, cpf: str, name: str, value: int, key: str, description: str):
    cal_value: float = float(value) / 100.0
    body = {
        'calendario': {
            'expiracao': expiration
        },
        'devedor': {
            'cpf': cpf,
            'nome': name
        },
        'valor': {
            'original': str(f"{cal_value:.2f}")
        },
        'chave': key,
        'solicitacaoPagador': description
    }
    return efi.pix_create_immediate_charge(body=body)

def detail_charge(txid: str):
    params = {
        'txid': txid
    }
    return efi.pix_detail_charge(params=params)
