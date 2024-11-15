from efipay import EfiPay
from pydantic import BaseModel
# from app.core.config import settings

# CREDENTIALS = {
#     'client_id': settings.EFIPAY_CLIENT_ID,
#     'client_secret': settings.EFIPAY_CLIENT_SECRET,
#     'sandbox': settings.ENVIRONMENT == "production",
#     'certificate': settings.EFIPAY_CERTIFICATE_PATH
# }

CREDENTIALS = {
    'client_id': "settings.EFIPAY_CLIENT_I",
    'client_secret': "settings.EFIPAY_CLIENT_SECRET",
    'sandbox': True,
    'certificate': "settings.EFIPAY_CERTIFICATE_PATH"
}

efi = EfiPay(CREDENTIALS)

def create_immediate_charge(expiration: int, cpf: str, name: str, value: int, key: str, description: str):
    body = {
        'calendario': {
            'expiracao': expiration
        },
        'devedor': {
            'cpf': cpf,
            'nome': name
        },
        'valor': {
            'original': float(value) / 100
        },
        'chave': key,
        'solicitacaoPagador': description
    }
    return efi.pix_create_immediate_charge(body=body)

teste = create_immediate_charge(3600, '12345678909', 'Fulano de Tal', 100, '12345678909', 'Teste de pagamento')
print(teste)