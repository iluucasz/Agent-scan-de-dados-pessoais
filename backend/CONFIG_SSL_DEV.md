# SSL em desenvolvimento

Para desenvolvimento local, você pode desabilitar SSL temporariamente. Em produção, mantenha SSL com CA.

## Produção
- DATABASE_URL com `sslmode=require` (ou concatenado pelo cliente)
- CA_CERT com o certificado da autoridade (com `\n` escapado)

## Alternativa rápida para teste local
Se aparecer o erro:

```
{"message": "The server does not support SSL connections"}
```

adicione no seu `.env` local:

```
DB_SSL_DISABLE=true
```

E use uma `DATABASE_URL` para um Postgres sem SSL. Para subir para produção, remova `DB_SSL_DISABLE` e defina `CA_CERT` corretamente.
